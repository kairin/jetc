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
#   $1 = folder_path (full path to the build context directory)
#   $2 = use_cache ('y' or 'n')
#   $3 = docker_username
#   $4 = platform (e.g., linux/arm64) - NOW USES GLOBAL ${PLATFORM}
#   $5 = use_squash ('y' or 'n')
#   $6 = skip_intermediate ('y' or 'n') - 'y' means build locally (--load), 'n' means push (--push)
#   $7 = base_image_tag (tag of the image to use in FROM, passed via --build-arg)
#   $8 = docker_repo_prefix
#   $9 = docker_registry (optional)
#   $10 = use_builder ('y' or 'n') - Whether to use buildx or default docker build
# Exports:
#   fixed_tag (global variable with the constructed tag for the built image)
# Returns: 0 on success, 1 on failure
# =========================================================================
build_folder_image() {
    local folder_path="$1"
    local use_cache="$2"
    local docker_username="$3"
    # local platform_arg="$4" # No longer using argument, use global PLATFORM
    local use_squash="$5"
    local skip_intermediate="$6"
    local base_image_tag="$7"
    local docker_repo_prefix="$8"
    local docker_registry="${9:-}" # Optional registry
    local use_builder="${10:-y}"   # Default to using builder

    local folder_basename
    folder_basename=$(basename "$folder_path")

    # --- Construct the target tag ---
    local registry_prefix=""
    if [[ -n "$docker_registry" ]]; then
        registry_prefix="${docker_registry}/"
    fi
    # Correct Tag Format: <registry_prefix><username>/<repo_prefix>:<folder_basename>
    export fixed_tag="${registry_prefix}${docker_username}/${docker_repo_prefix}:${folder_basename}"
    # Convert tag to lowercase as per Docker recommendations
    fixed_tag=$(echo "$fixed_tag" | tr '[:upper:]' '[:lower:]')
    # --- End Tag Construction ---


    log_info "--------------------------------------------------"
    log_info "Building image from folder: $folder_path"
    log_info "Image Name: $folder_basename"
    log_info "Platform: ${PLATFORM:-linux/arm64}" # Log the global PLATFORM being used
    log_info "Tag: $fixed_tag"
    log_info "Base Image (FROM via ARG): $base_image_tag"
    log_info "Skip Intermediate Push/Pull: $skip_intermediate"
    log_info "--------------------------------------------------"

    # Prepare build command options
    local build_cmd_opts=()

    # Platform (using global PLATFORM)
    build_cmd_opts+=("--platform" "${PLATFORM:-linux/arm64}")

    # Target tag
    build_cmd_opts+=("-t" "$fixed_tag")

    # Base image build argument
    build_cmd_opts+=("--build-arg" "BASE_IMAGE=$base_image_tag")

    # Cache option
    if [[ "$use_cache" == "n" ]]; then
        log_info "Using --no-cache"
        build_cmd_opts+=("--no-cache")
    fi

    # Squash option (only with default build, not buildx?)
    # Buildx might handle squash differently or not support the flag directly
    if [[ "$use_squash" == "y" && "$use_builder" != "y" ]]; then
         log_info "Using --squash (only for default docker build)"
         build_cmd_opts+=("--squash")
    elif [[ "$use_squash" == "y" && "$use_builder" == "y" ]]; then
         log_warning "Squash option ignored when using buildx builder."
    fi

    # Output/Action option (Buildx specific)
    if [[ "$use_builder" == "y" ]]; then
        if [[ "$skip_intermediate" == "y" ]]; then
            log_info "Using --load (build locally)"
            build_cmd_opts+=("--load") # Buildx: load image into local docker images
        else
            log_info "Using --push (build and push)"
            build_cmd_opts+=("--push") # Buildx: push image to registry
        fi
    else
        # Default docker build doesn't use --load or --push directly in build command
        # The push happens as a separate step if skip_intermediate is 'n'
         if [[ "$skip_intermediate" == "y" ]]; then
            log_info "Building locally (default docker build)"
         else
             log_info "Building for push (default docker build - push happens later)"
         fi
    fi


    # Build context path
    build_cmd_opts+=("$folder_path")

    # --- Execute Build ---
    local build_status=1 # Default to failure
    log_info "Running Build Command:"
    if [[ "$use_builder" == "y" ]]; then
        # Use docker buildx build
        echo "docker buildx build ${build_cmd_opts[*]}" # Log the command
        if docker buildx build "${build_cmd_opts[@]}"; then
            build_status=0
        fi
    else
        # Use default docker build
        echo "docker build ${build_cmd_opts[*]}" # Log the command
        if docker build "${build_cmd_opts[@]}"; then
             build_status=0
             # If using default build and not skipping intermediate, push the image now
             if [[ "$skip_intermediate" != "y" ]]; then
                 log_info "Pushing image (default docker build): $fixed_tag"
                 if ! docker push "$fixed_tag"; then
                     log_error "Failed to push image $fixed_tag after default build."
                     build_status=1 # Mark as failed if push fails
                 fi
             fi
        fi
    fi
    # --- End Execute Build ---

    if [[ $build_status -ne 0 ]]; then
        log_error "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        log_error "Error: Failed to build image for $folder_basename ($folder_path)."
        log_error "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        # fixed_tag is already exported, even on failure, for logging purposes
        return 1
    fi

    # If intermediate push/pull wasn't skipped, pull the image back to ensure it's the registry version
    # Only do this if the build command itself succeeded (build_status == 0)
    if [[ "$skip_intermediate" != "y" && $build_status -eq 0 ]]; then
        log_info "Pulling built image to verify: $fixed_tag"
        if ! pull_image "$fixed_tag"; then
            log_error "Failed to pull back image $fixed_tag after successful build/push. Verification failed."
            return 1 # Fail if pull-back fails
        else
             log_success "Successfully pulled back image $fixed_tag."
        fi
    elif [[ "$skip_intermediate" == "y" && $build_status -eq 0 ]]; then
        # If built locally (--load or default build), verify it exists locally
        log_info "Verifying locally built image exists: $fixed_tag"
        if ! verify_image_exists "$fixed_tag"; then
             log_error "Image $fixed_tag not found locally after successful local build. Verification failed."
             return 1 # Fail if local verification fails
        else
             log_success "Successfully verified local image $fixed_tag."
        fi
    fi

    log_success "Build process completed successfully for: $fixed_tag"
    return 0 # Return success
}


# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── docker_helpers.sh  <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Docker helper functions (pull, verify, build).
#              Corrected tag construction in build_folder_image.
#              Ensured build_folder_image uses global PLATFORM.
# Author: Mr K / GitHub Copilot / kairin
# COMMIT-TRACKING: UUID-20250424-201515-TAGFIX
