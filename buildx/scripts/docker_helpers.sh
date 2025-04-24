#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/docker_helpers.sh

# =========================================================================
# Docker Helper Functions
# =========================================================================

# --- Dependencies ---
SCRIPT_DIR_DOCKER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source required scripts (use fallbacks if sourcing fails)
if [ -f "$SCRIPT_DIR_DOCKER/env_setup.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_DOCKER/env_setup.sh"
else
    echo "Warning: env_setup.sh not found. Logging/colors may be basic." >&2
    log_info() { echo "INFO: $1"; }
    log_warning() { echo "WARNING: $1" >&2; }
    log_error() { echo "ERROR: $1" >&2; }
    log_success() { echo "SUCCESS: $1"; }
    log_debug() { :; }
fi

# =========================================================================
# Function: Pull a Docker image
# Arguments: $1 = Full image tag (e.g., user/repo:tag)
# Returns: 0 on success, 1 on failure
# =========================================================================
pull_image() {
    local image_tag="$1"
    if [ -z "$image_tag" ]; then
        log_error "pull_image: No image tag provided."
        return 1
    fi
    log_info "Attempting to pull image: $image_tag"
    if docker pull "$image_tag"; then
        log_success " -> Successfully pulled image: $image_tag"
        return 0
    else
        log_error " -> Failed to pull image: $image_tag"
        return 1
    fi
}

# =========================================================================
# Function: Verify if a Docker image exists locally
# Arguments: $1 = Full image tag (e.g., user/repo:tag)
# Returns: 0 if image exists locally, 1 otherwise
# Renamed from verify_image_locally for clarity
# =========================================================================
verify_image_exists() {
    local image_tag="$1"
    if [ -z "$image_tag" ]; then
        log_error "verify_image_exists: No image tag provided."
        return 1
    fi
    log_debug "Verifying local existence of image: $image_tag"
    # docker image inspect returns non-zero if image not found
    if docker image inspect "$image_tag" &> /dev/null; then
        log_debug " -> Image '$image_tag' found locally."
        return 0
    else
        log_debug " -> Image '$image_tag' not found locally."
        return 1
    fi
}


# =========================================================================
# Function: Build a Docker image from a specific folder
# Arguments:
#   $1 = folder_path
#   $2 = use_cache ('y'/'n')
#   $3 = docker_username
#   $4 = use_squash ('y'/'n')
#   $5 = skip_intermediate ('y'/'n')
#   $6 = base_image_tag
#   $7 = docker_repo_prefix
#   $8 = docker_registry (optional)
#   $9 = use_builder ('y'/'n')
# Exports:
#   fixed_tag (global variable with the constructed tag for the built image)
# Returns: 0 on success, 1 on failure
# =========================================================================
build_folder_image() {
    local folder_path="$1"
    local use_cache="$2"
    local docker_username="$3"
    local use_squash="$4" # Index shifted due to platform removal
    local skip_intermediate="$5" # Index shifted
    local base_image_tag="$6" # Index shifted
    local docker_repo_prefix="$7" # Index shifted
    local docker_registry="${8:-}" # Index shifted
    local use_builder="${9:-y}"   # Index shifted

    local folder_basename
    folder_basename=$(basename "$folder_path")

    # --- Construct the target tag ---
    local registry_prefix=""
    if [[ -n "$docker_registry" ]]; then
        registry_prefix="${docker_registry}/"
    fi
    export fixed_tag="${registry_prefix}${docker_username}/${docker_repo_prefix}:${folder_basename}"
    fixed_tag=$(echo "$fixed_tag" | tr '[:upper:]' '[:lower:]')
    # --- End Tag Construction ---

    log_info "--------------------------------------------------"
    log_info "Building image from folder: $folder_path"
    log_info "Image Name: $folder_basename"
    log_info "Platform: ${PLATFORM:-linux/arm64}"
    log_info "Tag: $fixed_tag"
    # --- FIX: Add quotes around variable expansion ---
    log_info "Base Image (FROM via ARG): \"$base_image_tag\"" # Line 87 approx
    log_info "Skip Intermediate Push/Pull: $skip_intermediate"
    log_info "--------------------------------------------------"

    # Prepare build command options
    local build_cmd_opts=()
    build_cmd_opts+=("--platform" "${PLATFORM:-linux/arm64}")
    build_cmd_opts+=("-t" "$fixed_tag")
    build_cmd_opts+=("--build-arg" "BASE_IMAGE=$base_image_tag")

    if [[ "$use_cache" == "n" ]]; then log_info "Using --no-cache"; build_cmd_opts+=("--no-cache"); fi

    if [[ "$use_squash" == "y" && "$use_builder" != "y" ]]; then log_info "Using --squash"; build_cmd_opts+=("--squash");
    elif [[ "$use_squash" == "y" && "$use_builder" == "y" ]]; then log_warning "Squash ignored with buildx."; fi

    if [[ "$use_builder" == "y" ]]; then
        if [[ "$skip_intermediate" == "y" ]]; then log_info "Using --load"; build_cmd_opts+=("--load");
        else log_info "Using --push"; build_cmd_opts+=("--push"); fi
    else
         if [[ "$skip_intermediate" == "y" ]]; then log_info "Building locally (default docker build)";
         else log_info "Building for push (default docker build - push happens later)"; fi
    fi

    build_cmd_opts+=("$folder_path")

    # --- Execute Build ---
    local build_status=1
    log_info "Running Build Command:"
    if [[ "$use_builder" == "y" ]]; then
        echo "docker buildx build ${build_cmd_opts[*]}"
        if docker buildx build "${build_cmd_opts[@]}"; then build_status=0; fi
    else
        echo "docker build ${build_cmd_opts[*]}"
        if docker build "${build_cmd_opts[@]}"; then
             build_status=0
             if [[ "$skip_intermediate" != "y" ]]; then
                 log_info "Pushing image (default docker build): $fixed_tag"
                 if ! docker push "$fixed_tag"; then log_error "Push failed."; build_status=1; fi
             fi
        fi
    fi
    # --- End Execute Build ---

    if [[ $build_status -ne 0 ]]; then
        log_error "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        log_error "Error: Failed to build image for $folder_basename ($folder_path)."
        log_error "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        return 1
    fi

    # Verification after successful build
    if [[ "$skip_intermediate" != "y" ]]; then
        log_info "Pulling built image to verify: $fixed_tag"
        if ! pull_image "$fixed_tag"; then log_error "Pull-back verification failed."; return 1;
        else log_success "Pull-back verification successful."; fi
    else
        log_info "Verifying locally built image exists: $fixed_tag"
        if ! verify_image_exists "$fixed_tag"; then log_error "Local verification failed."; return 1;
        else log_success "Local verification successful."; fi
    fi

    log_success "Build process completed successfully for: $fixed_tag"
    return 0
}

# =========================================================================
# Function: Generate a timestamped tag
# Arguments: $1 = username, $2 = repo_prefix, $3 = registry (optional)
# Returns: Echoes the generated tag
# =========================================================================
generate_timestamped_tag() {
    local username="$1"
    local repo_prefix="$2"
    local registry="${3:-}"
    local timestamp
    timestamp=$(get_system_datetime) # Use function from env_setup.sh

    local registry_prefix=""
    if [[ -n "$registry" ]]; then
        registry_prefix="${registry}/"
    fi

    local tag="${registry_prefix}${username}/${repo_prefix}:${timestamp}"
    # Convert tag to lowercase
    echo "$tag" | tr '[:upper:]' '[:lower:]'
}


# File location diagram: ... (omitted)
# Description: Docker helper functions (pull, verify, build, generate tag). Added quoting for log.
# Author: Mr K / GitHub Copilot / kairin
# COMMIT-TRACKING: UUID-20250424-203737-DOCKERHELPFIX
