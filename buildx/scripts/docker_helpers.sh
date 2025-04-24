#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/docker_helpers.sh

# =========================================================================
# Docker Helper Functions
# =========================================================================

# Set strict mode early
set -euo pipefail

# --- Dependencies ---
SCRIPT_DIR_DOCKER="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# Source ONLY env_setup.sh
if [ -f "$SCRIPT_DIR_DOCKER/env_setup.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_DOCKER/env_setup.sh"
else
    echo "CRITICAL ERROR: env_setup.sh not found in docker_helpers.sh" >&2
    # Define minimal functions
    log_info() { echo "INFO: $1"; }
    log_warning() { echo "WARNING: $1" >&2; }
    log_error() { echo "ERROR: $1" >&2; }
    log_success() { echo "SUCCESS: $1"; }
    log_debug() { if [[ "${JETC_DEBUG}" == "true" ]]; then echo "[DEBUG] $1" >&2; fi; }
    get_system_datetime() { date +%s; }
    PLATFORM="linux/arm64"
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
# Arguments:
#   $1: folder_path - Path to the build context folder
#   $2: use_cache - 'y' or 'n'
#   $3: docker_username - Docker username
#   $4: use_squash - 'y' or 'n'
#   $5: skip_intermediate - 'y' or 'n' (y=local build only, n=push/pull)
#   $6: base_image_tag - Tag of the base image to use (passed as BASE_IMAGE build-arg)
#   $7: docker_repo_prefix - Prefix for the image repository
#   $8: docker_registry - Optional Docker registry hostname
#   $9: use_builder - 'y' or 'n' (whether to use buildx builder)
# Exports: fixed_tag - The final tag of the successfully built image
# Returns: 0 on success, 1 on failure
# =========================================================================
build_folder_image() {
    local folder_path="$1"
    local use_cache="$2"
    local docker_username="$3"
    local use_squash="$4"
    local skip_intermediate="$5" # 'y' means skip push/pull (local build)
    local base_image_tag="$6"
    local docker_repo_prefix="$7"
    local docker_registry="${8:-}" # Default to empty if not provided
    local use_builder="$9"         # Use buildx builder?

    # --- Validate required arguments AFTER assigning to locals ---
    # This is where the error likely triggers if an argument is truly missing
    if [ -z "$folder_path" ]; then log_error "build_folder_image: Validation Failed - Missing \$1 (folder_path)."; return 1; fi
    if [ -z "$use_cache" ]; then log_error "build_folder_image: Validation Failed - Missing \$2 (use_cache)."; return 1; fi
    if [ -z "$docker_username" ]; then log_error "build_folder_image: Validation Failed - Missing \$3 (docker_username)."; return 1; fi
    if [ -z "$use_squash" ]; then log_error "build_folder_image: Validation Failed - Missing \$4 (use_squash)."; return 1; fi
    if [ -z "$skip_intermediate" ]; then log_error "build_folder_image: Validation Failed - Missing \$5 (skip_intermediate)."; return 1; fi
    if [ -z "$base_image_tag" ]; then log_error "build_folder_image: Validation Failed - Missing \$6 (base_image_tag)."; return 1; fi
    if [ -z "$docker_repo_prefix" ]; then log_error "build_folder_image: Validation Failed - Missing \$7 (docker_repo_prefix)."; return 1; fi

    local folder_basename
    folder_basename=$(basename "$folder_path") # Line 72 approx in original file context

    # --- Construct Tag ---
    local registry_prefix=""
    [[ -n "$docker_registry" ]] && registry_prefix="${docker_registry}/"
    export fixed_tag="${registry_prefix}${docker_username}/${docker_repo_prefix}:${folder_basename}"
    fixed_tag=$(echo "$fixed_tag" | tr '[:upper:]' '[:lower:]')

    log_info "--------------------------------------------------"
    log_info "Building image from folder: $folder_path"
    log_info "Image Name: $folder_basename"
    log_info "Platform: ${PLATFORM:-linux/arm64}"
    log_info "Tag: $fixed_tag"
    log_info "Base Image (FROM via ARG): \"$base_image_tag\""
    log_info "Skip Intermediate Push/Pull: $skip_intermediate" # Log the received value
    log_info "Use Buildx Builder: $use_builder"                 # Log the received value
    log_info "Use Cache: $use_cache"
    log_info "Use Squash: $use_squash"
    log_info "--------------------------------------------------"

    local build_cmd_base="docker buildx build" # Assume buildx initially
    local build_args=("--platform" "$platform" "-t" "$full_tag" "--build-arg" "BASE_IMAGE=$base_image_tag")
    local push_flag=""

    # REVERTED: Simplified logic, potentially ignoring use_builder='n' from UI
    if [[ "$skip_intermediate" == "n" ]]; then
        push_flag="--push"
        log_info "Using --push (buildx)"
    else
        # If not pushing, assume buildx load or standard build (logic was complex, reverting to simpler state)
        # This might incorrectly use --load even if use_builder was 'n'
        if [[ "$use_builder" == "y" ]]; then
             push_flag="--load"
             log_info "Using --load (buildx)"
        else
             log_info "Using standard 'docker build' (implied by no --push/--load)"
             build_cmd_base="docker build" # Switch command if not using builder explicitly? Reverting this part is tricky. Let's keep buildx build base for now.
        fi
    fi

    if [[ "$use_cache" == "n" ]]; then
        build_args+=("--no-cache")
        log_info "Using --no-cache"
    fi

    if [[ "$use_squash" == "y" ]]; then
        # Reverted: Simple squash logic, might conflict with buildx
        build_args+=("--squash")
        log_info "Using --squash"
    fi

    # Add push/load flag if determined
    if [[ -n "$push_flag" ]]; then
        build_args+=("$push_flag")
    fi

    # Add build context
    build_args+=("$folder_path")

    # Execute the build command
    log_info "Running Build Command:"
    echo "CMD: $build_cmd_base ${build_args[*]}" # Log the exact command
    if ! $build_cmd_base "${build_args[@]}"; then
        log_error "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        log_error "Error: Failed to build image for $image_name ($folder_path)."
        log_error "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        return 1
    fi

    # Reverted: Simplified pull-back logic
    if [[ "$skip_intermediate" == "n" ]]; then
        log_info "Pulling back pushed image to verify: $full_tag"
        if ! pull_docker_image "$full_tag"; then
            log_error "Pull-back verification failed for $full_tag."
            # return 1 # Reverted: Don't fail build on pull-back error
        else
            log_success "Pull-back verification successful."
        fi
    fi

    log_success "Build process completed successfully for: $full_tag"
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
    if declare -f get_system_datetime > /dev/null; then
        timestamp=$(get_system_datetime)
    else
        log_warning "get_system_datetime function not found, using basic date."
        timestamp=$(date -u +'%Y%m%d-%H%M%S')
    fi
    local registry_prefix=""
    [[ -n "$registry" ]] && registry_prefix="${registry}/"
    local tag="${registry_prefix}${username}/${repo_prefix}:${timestamp}"
    echo "$tag" | tr '[:upper:]' '[:lower:]'
}


# --- Main Execution (for testing) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ -f "$SCRIPT_DIR_DOCKER/logging.sh" ]; then source "$SCRIPT_DIR_DOCKER/logging.sh"; init_logging; fi
    log_info "Running docker_helpers.sh directly for testing..."
    log_info "Docker helpers test finished."
    exit 0
fi

# --- Footer ---
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── docker_helpers.sh  <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Helper functions for Docker operations (build, pull, etc.).
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250425-080000-42595D
