#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/docker_helpers.sh

# =========================================================================
# Docker Helper Functions
# =========================================================================

# Set strict mode early
set -euo pipefail

# --- Dependencies ---
SCRIPT_DIR_DOCKER="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

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
    log_debug() { if [[ "${JETC_DEBUG}" == "true" ]]; then echo "[DEBUG] $1" >&2; fi; } # Basic debug
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
    # <<< --- ADDED DEBUGGING --- >>>
    log_debug "--- Entering build_folder_image ---"
    log_debug "  Received \$1 (folder_path):         '$1'"
    log_debug "  Received \$2 (use_cache):           '$2'"
    log_debug "  Received \$3 (docker_username):     '$3'"
    log_debug "  Received \$4 (use_squash):          '$4'"
    log_debug "  Received \$5 (skip_intermediate):   '$5'"
    log_debug "  Received \$6 (base_image_tag):      '$6'"
    log_debug "  Received \$7 (docker_repo_prefix):  '$7'"
    log_debug "  Received \$8 (docker_registry):     '${8:-}'" # Show default if empty
    log_debug "  Received \$9 (use_builder):         '${9:-y}'" # Show default if empty
    log_debug "  Global PLATFORM:                  '${PLATFORM:-}'"
    log_debug "-------------------------------------"
    # <<< --- END DEBUGGING --- >>>

    local folder_path="$1"
    local use_cache="$2"
    local docker_username="$3"
    local use_squash="$4"
    local skip_intermediate="$5"
    local base_image_tag="$6"
    local docker_repo_prefix="$7"
    local docker_registry="${8:-}" # Default to empty if $8 is unset/null
    local use_builder="${9:-y}"   # Default to 'y' if $9 is unset/null

    # --- Validate required arguments ---
    # Check after assigning to local variables
    if [ -z "$folder_path" ]; then log_error "build_folder_image: Missing required argument \$1 (folder_path)."; return 1; fi
    if [ -z "$use_cache" ]; then log_error "build_folder_image: Missing required argument \$2 (use_cache)."; return 1; fi
    if [ -z "$docker_username" ]; then log_error "build_folder_image: Missing required argument \$3 (docker_username)."; return 1; fi
    if [ -z "$use_squash" ]; then log_error "build_folder_image: Missing required argument \$4 (use_squash)."; return 1; fi
    if [ -z "$skip_intermediate" ]; then log_error "build_folder_image: Missing required argument \$5 (skip_intermediate)."; return 1; fi
    if [ -z "$base_image_tag" ]; then log_error "build_folder_image: Missing required argument \$6 (base_image_tag)."; return 1; fi
    if [ -z "$docker_repo_prefix" ]; then log_error "build_folder_image: Missing required argument \$7 (docker_repo_prefix)."; return 1; fi
    # $8 (registry) and $9 (use_builder) have defaults, no need to check if empty

    local folder_basename
    folder_basename=$(basename "$folder_path") # Line 67 approx

    # --- Construct Tag ---
    local registry_prefix=""
    [[ -n "$docker_registry" ]] && registry_prefix="${docker_registry}/"
    # Export the tag so build_stages.sh can retrieve it
    export fixed_tag="${registry_prefix}${docker_username}/${docker_repo_prefix}:${folder_basename}"
    fixed_tag=$(echo "$fixed_tag" | tr '[:upper:]' '[:lower:]') # Ensure lowercase

    log_info "--------------------------------------------------"
    log_info "Building image from folder: $folder_path"
    log_info "Image Name: $folder_basename"
    log_info "Platform: ${PLATFORM:-linux/arm64}" # Uses PLATFORM from env_setup.sh
    log_info "Tag: $fixed_tag"
    log_info "Base Image (FROM via ARG): \"$base_image_tag\""
    log_info "Skip Intermediate Push/Pull: $skip_intermediate"
    log_info "Use Buildx Builder: $use_builder"
    log_info "Use Cache: $use_cache"
    log_info "Use Squash: $use_squash"
    log_info "--------------------------------------------------"

    # --- Build Command ---
    local build_cmd_opts=()
    build_cmd_opts+=("--platform" "${PLATFORM:-linux/arm64}")
    build_cmd_opts+=("-t" "$fixed_tag")
    build_cmd_opts+=("--build-arg" "BASE_IMAGE=$base_image_tag")
    [[ "$use_cache" == "n" ]] && { log_info "Using --no-cache"; build_cmd_opts+=("--no-cache"); }
    if [[ "$use_squash" == "y" ]]; then
        if [[ "$use_builder" != "y" ]]; then log_info "Using --squash"; build_cmd_opts+=("--squash");
        else log_warning "Squash ignored when using buildx."; fi
    fi
    if [[ "$use_builder" == "y" ]]; then
        if [[ "$skip_intermediate" == "y" ]]; then log_info "Using --load (buildx)"; build_cmd_opts+=("--load");
        else log_info "Using --push (buildx)"; build_cmd_opts+=("--push"); fi
    else
         [[ "$skip_intermediate" == "y" ]] && log_info "Building locally (default docker build)" || log_info "Building for push (default docker build - push happens later)"
    fi
    # Add the context path last
    build_cmd_opts+=("$folder_path")

    # --- Execute ---
    local build_status=1 # Default to failure
    log_info "Running Build Command:"
    if [[ "$use_builder" == "y" ]]; then
        echo "CMD: docker buildx build ${build_cmd_opts[*]}" # Log the exact command
        # Use $@ to handle spaces in arguments correctly
        if docker buildx build "${build_cmd_opts[@]}"; then build_status=0; fi
    else
        echo "CMD: docker build ${build_cmd_opts[*]}" # Log the exact command
        # Use $@ to handle spaces in arguments correctly
        if docker build "${build_cmd_opts[@]}"; then
             build_status=0
             # Push manually if not skipping and using default builder
             if [[ "$skip_intermediate" != "y" ]]; then
                 log_info "Pushing image (default docker build): $fixed_tag"
                 if ! docker push "$fixed_tag"; then
                     log_error "Push failed for $fixed_tag (default docker build)."
                     build_status=1 # Mark as failed if push fails
                 fi
             fi
        fi
    fi

    # --- Post Build ---
    if [[ $build_status -ne 0 ]]; then
        log_error "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        log_error "Error: Failed to build image for $folder_basename ($folder_path)."
        log_error "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        export fixed_tag="" # Clear exported tag on failure
        return 1
    fi

    # Verification depends on whether we pushed or loaded
    if [[ "$skip_intermediate" == "y" ]]; then
        log_info "Verifying locally built image exists: $fixed_tag"
        if ! verify_image_exists "$fixed_tag"; then
            log_error "Local verification failed for $fixed_tag."
            export fixed_tag="" # Clear exported tag on failure
            return 1
        fi
        log_success "Local verification successful."
    else # Pushed (either via buildx --push or manual push)
        log_info "Pulling back pushed image to verify: $fixed_tag"
        if ! pull_image "$fixed_tag"; then
            log_error "Pull-back verification failed for $fixed_tag."
            # Don't clear tag here, it might exist remotely, but log the error
            return 1 # Treat failure to pull back as error
        fi
        log_success "Pull-back verification successful."
    fi

    log_success "Build process completed successfully for: $fixed_tag"
    # fixed_tag is already exported
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

    # Use get_system_datetime from logging.sh for consistency
    # Check if it exists first
    if declare -f get_system_datetime > /dev/null; then
        timestamp=$(get_system_datetime)
    else
        log_warning "get_system_datetime function not found, using basic date."
        timestamp=$(date -u +'%Y%m%d-%H%M%S') # Basic fallback
    fi

    local registry_prefix=""
    [[ -n "$registry" ]] && registry_prefix="${registry}/"
    local tag="${registry_prefix}${username}/${repo_prefix}:${timestamp}"
    echo "$tag" | tr '[:upper:]' '[:lower:]' # Ensure lowercase
}


# --- Main Execution (for testing) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # If testing directly, source logging.sh first if available
    if [ -f "$SCRIPT_DIR_DOCKER/logging.sh" ]; then source "$SCRIPT_DIR_DOCKER/logging.sh"; init_logging; fi
    log_info "Running docker_helpers.sh directly for testing..."
    # Add test cases if needed
    log_info "Docker helpers test finished."
    exit 0
fi

# --- Footer ---
# Description: Docker helper functions. Relies on logging.sh and env_setup.sh sourced by caller. Added debugging inside build_folder_image.
# COMMIT-TRACKING: UUID-20250424-220000-STAGESDEBUG1
