#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/docker_helpers.sh

# =========================================================================
# Docker Helper Functions
# =========================================================================

# --- Dependencies ---
SCRIPT_DIR_DOCKER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source ONLY env_setup.sh - It provides necessary env vars and fallbacks if logging wasn't sourced yet.
# DO NOT source logging.sh here.
if [ -f "$SCRIPT_DIR_DOCKER/env_setup.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_DOCKER/env_setup.sh"
else
    # Minimal fallbacks if even env_setup is missing (should not happen in normal flow)
    echo "CRITICAL ERROR: env_setup.sh not found in docker_helpers.sh" >&2
    # Define minimal functions to prevent immediate script failure, although logging is broken.
    log_info() { echo "INFO: $1"; }
    log_warning() { echo "WARNING: $1" >&2; }
    log_error() { echo "ERROR: $1" >&2; }
    log_success() { echo "SUCCESS: $1"; }
    log_debug() { :; }
    get_system_datetime() { date +%s; } # Basic fallback
    PLATFORM="linux/arm64" # Basic fallback
fi

# =========================================================================
# Function: Pull a Docker image
# =========================================================================
pull_image() {
    local image_tag="$1"
    if [ -z "$image_tag" ]; then log_error "pull_image: No image tag provided."; return 1; fi
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
# =========================================================================
verify_image_exists() {
    local image_tag="$1"
    if [ -z "$image_tag" ]; then log_error "verify_image_exists: No image tag provided."; return 1; fi
    log_debug "Verifying local existence of image: $image_tag"
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
# =========================================================================
build_folder_image() {
    local folder_path="$1"
    local use_cache="$2"
    local docker_username="$3"
    local use_squash="$4"
    local skip_intermediate="$5"
    local base_image_tag="$6"
    local docker_repo_prefix="$7"
    local docker_registry="${8:-}"
    local use_builder="${9:-y}"

    local folder_basename
    folder_basename=$(basename "$folder_path")

    # --- Construct Tag ---
    local registry_prefix=""
    [[ -n "$docker_registry" ]] && registry_prefix="${docker_registry}/"
    export fixed_tag="${registry_prefix}${docker_username}/${docker_repo_prefix}:${folder_basename}"
    fixed_tag=$(echo "$fixed_tag" | tr '[:upper:]' '[:lower:]')

    log_info "--------------------------------------------------"
    log_info "Building image from folder: $folder_path"
    log_info "Image Name: $folder_basename"
    log_info "Platform: ${PLATFORM:-linux/arm64}" # Uses PLATFORM from env_setup.sh
    log_info "Tag: $fixed_tag"
    log_info "Base Image (FROM via ARG): \"$base_image_tag\"" # Line 87 approx - relies on global log_info
    log_info "Skip Intermediate Push/Pull: $skip_intermediate"
    log_info "--------------------------------------------------"

    # --- Build Command ---
    local build_cmd_opts=()
    build_cmd_opts+=("--platform" "${PLATFORM:-linux/arm64}")
    build_cmd_opts+=("-t" "$fixed_tag")
    build_cmd_opts+=("--build-arg" "BASE_IMAGE=$base_image_tag")
    [[ "$use_cache" == "n" ]] && { log_info "Using --no-cache"; build_cmd_opts+=("--no-cache"); }
    if [[ "$use_squash" == "y" ]]; then
        if [[ "$use_builder" != "y" ]]; then log_info "Using --squash"; build_cmd_opts+=("--squash");
        else log_warning "Squash ignored with buildx."; fi
    fi
    if [[ "$use_builder" == "y" ]]; then
        if [[ "$skip_intermediate" == "y" ]]; then log_info "Using --load"; build_cmd_opts+=("--load");
        else log_info "Using --push"; build_cmd_opts+=("--push"); fi
    else
         [[ "$skip_intermediate" == "y" ]] && log_info "Building locally (default docker build)" || log_info "Building for push (default docker build - push happens later)"
    fi
    build_cmd_opts+=("$folder_path")

    # --- Execute ---
    local build_status=1; log_info "Running Build Command:"
    if [[ "$use_builder" == "y" ]]; then
        echo "docker buildx build ${build_cmd_opts[*]}"
        docker buildx build "${build_cmd_opts[@]}" && build_status=0
    else
        echo "docker build ${build_cmd_opts[*]}"
        if docker build "${build_cmd_opts[@]}"; then
             build_status=0
             if [[ "$skip_intermediate" != "y" ]]; then
                 log_info "Pushing image (default docker build): $fixed_tag"
                 docker push "$fixed_tag" || { log_error "Push failed."; build_status=1; }
             fi
        fi
    fi

    # --- Post Build ---
    if [[ $build_status -ne 0 ]]; then
        log_error "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        log_error "Error: Failed to build image for $folder_basename ($folder_path)."
        log_error "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        return 1
    fi
    if [[ "$skip_intermediate" != "y" ]]; then
        log_info "Pulling built image to verify: $fixed_tag"
        pull_image "$fixed_tag" || { log_error "Pull-back verification failed."; return 1; }
        log_success "Pull-back verification successful."
    else
        log_info "Verifying locally built image exists: $fixed_tag"
        verify_image_exists "$fixed_tag" || { log_error "Local verification failed."; return 1; }
        log_success "Local verification successful."
    fi
    log_success "Build process completed successfully for: $fixed_tag"
    return 0
}

# =========================================================================
# Function: Generate a timestamped tag
# =========================================================================
generate_timestamped_tag() {
    local username="$1"
    local repo_prefix="$2"
    local registry="${3:-}"
    local timestamp
    timestamp=$(get_system_datetime) # Use function from env_setup.sh or logging.sh

    local registry_prefix=""
    [[ -n "$registry" ]] && registry_prefix="${registry}/"
    local tag="${registry_prefix}${username}/${repo_prefix}:${timestamp}"
    echo "$tag" | tr '[:upper:]' '[:lower:]'
}


# --- Main Execution (for testing) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # If testing directly, source logging.sh first
    if [ -f "$SCRIPT_DIR_DOCKER/logging.sh" ]; then source "$SCRIPT_DIR_DOCKER/logging.sh"; init_logging; else echo "ERROR: Cannot find logging.sh for test."; exit 1; fi
    log_info "Running docker_helpers.sh directly for testing..."
    # Add test cases if needed
    log_info "Docker helpers test finished."
    exit 0
fi

# --- Footer ---
# Description: Docker helper functions. Relies on logging.sh and env_setup.sh sourced by caller.
# COMMIT-TRACKING: UUID-20250424-205555-LOGGINGREFACTOR
