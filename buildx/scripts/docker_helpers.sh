#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/docker_helpers.sh

# =========================================================================
# Docker Helper Functions
# =========================================================================

# Set strict mode early
set -euo pipefail

# --- Dependencies ---
SCRIPT_DIR_DOCKER="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# --- FIX: REMOVED REDUNDANT SOURCE ---
# Source ONLY env_setup.sh
# if [ -f "$SCRIPT_DIR_DOCKER/env_setup.sh" ]; then
#     # shellcheck disable=SC1091
#     source "$SCRIPT_DIR_DOCKER/env_setup.sh"
# else
#     echo "CRITICAL ERROR: env_setup.sh not found in docker_helpers.sh" >&2
#     # Define minimal functions
#     log_info() { echo "INFO: $1"; }
#     log_warning() { echo "WARNING: $1" >&2; }
#     log_error() { echo "ERROR: $1" >&2; }
#     log_success() { echo "SUCCESS: $1"; }
#     log_debug() { if [[ "${JETC_DEBUG}" == "true" ]]; then echo "[DEBUG] $1" >&2; fi; }
#     get_system_datetime() { date +%s; }
#     PLATFORM="linux/arm64"
# fi
# --- END FIX ---

# --- Check if required functions exist (assuming they are sourced by caller) ---
if ! declare -f log_info > /dev/null; then
    echo "CRITICAL ERROR (docker_helpers.sh): log_info function not found. Ensure env_setup.sh/logging.sh are sourced by the caller." >&2
    # Define minimal fallbacks to allow script parsing but indicate error
    log_info() { echo "INFO (fallback): $1"; }
    log_warning() { echo "WARNING (fallback): $1" >&2; }
    log_error() { echo "ERROR (fallback): $1" >&2; }
    log_success() { echo "SUCCESS (fallback): $1"; }
    log_debug() { :; } # No-op debug fallback
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
# Function: Generate an image tag based on components
# Arguments: $1=username, $2=repo_prefix, $3=folder_name, $4=registry(optional)
# Returns: Generated tag string to stdout
# =========================================================================
generate_image_tag() {
    local username="$1"
    local repo_prefix="$2"
    local folder_name="$3"
    local registry="${4:-}"
    local registry_prefix=""
    [[ -n "$registry" ]] && registry_prefix="${registry}/"
    # Sanitize folder name for tag (e.g., replace slashes if it's a sub-stage)
    local sanitized_folder_name="${folder_name//\//-}"
    local tag="${registry_prefix}${username}/${repo_prefix}:${sanitized_folder_name}"
    # Docker tags should be lowercase
    echo "$tag" | tr '[:upper:]' '[:lower:]'
}

# =========================================================================
# Function: Attempt interactive Docker login
# Arguments: $1=registry (optional), $2=username (optional)
# Returns: 0 on success or if login not needed/skipped, 1 on failure
# =========================================================================
docker_login_interactive() {
    local registry="${1:-}" # Default to Docker Hub if empty
    local username="${2:-}"
    local login_target="${registry:-Docker Hub}" # For logging

    log_info "Checking Docker login status for ${login_target}..."

    # Check if already logged in (basic check, might not be foolproof for specific registries)
    # This relies on docker info potentially showing logged-in registries, or config.json
    # A more robust check might involve trying a credential helper or checking config.json directly
    if docker info | grep -q "Username: ${username:-}" && [[ -z "$registry" || "$(docker info | grep "Registry: ${registry}")" ]]; then
         log_info " -> Already logged in as ${username:-<default user>} to ${login_target}."
         return 0
    fi

    log_warning "Not logged in or status unknown for ${login_target}."
    # Ask user if they want to log in (use confirm_action if available)
    if command -v confirm_action &> /dev/null; then
        if ! confirm_action "Attempt Docker login to ${login_target} now?" true; then
            log_warning "Skipping Docker login as requested by user."
            return 1 # Indicate login was skipped/failed
        fi
    else
        # Fallback text prompt
        read -p "Attempt Docker login to ${login_target} now? [Y/n]: " confirm_login
        if [[ "${confirm_login:-y}" != [Yy] ]]; then
             log_warning "Skipping Docker login as requested by user."
             return 1 # Indicate login was skipped/failed
        fi
    fi

    # Attempt login
    local login_cmd=("docker" "login")
    [[ -n "$registry" ]] && login_cmd+=("$registry")
    [[ -n "$username" ]] && login_cmd+=("--username" "$username")

    log_info "Running: ${login_cmd[*]}"
    if "${login_cmd[@]}"; then
        log_success " -> Docker login successful for ${login_target}."
        return 0
    else
        log_error " -> Docker login failed for ${login_target}."
        return 1
    fi
}


# =========================================================================
# Function: Build a Docker image from a specified folder
# Arguments:
#   $1: folder_path - Path to the build context folder containing Dockerfile
#   $2: use_cache - 'y' or 'n' (passed as --no-cache if 'n')
#   $3: docker_username - Docker username for tagging
#   $4: use_squash - 'y' or 'n' (passed as --squash if 'y')
#   $5: skip_intermediate - 'y' or 'n' (determines --load or --push for buildx, ignored for docker build)
#   $6: base_image_tag - Tag of the base image to use (passed as --build-arg BASE_IMAGE)
#   $7: docker_repo_prefix - Prefix for the image repository name
#   $8: docker_registry - Docker registry (optional, prepended if provided)
#   $9: use_builder - 'y' or 'n' (determines whether to use 'docker buildx build' or 'docker build')
# Exports: fixed_tag - The final tag of the successfully built image
# Returns: 0 on success, 1 on failure
# =========================================================================
build_folder_image() {
    local folder_path="$1"
    local use_cache="$2"
    local docker_username="$3"
    local use_squash="$4"
    local skip_intermediate="$5"
    local base_image_tag="$6"
    local docker_repo_prefix="$7"
    local docker_registry="$8"
    local use_builder="$9"

    local folder_name
    folder_name=$(basename "$folder_path")
    export fixed_tag="" # Clear or initialize exported variable

    log_info "Attempting to build image for stage: $folder_name"
    log_debug "Build context: $folder_path"
    log_debug "Base image ARG: $base_image_tag"
    log_debug "User options: use_cache=$use_cache, use_squash=$use_squash, skip_intermediate=$skip_intermediate, use_builder=$use_builder"

    # Validate inputs
    if [[ ! -d "$folder_path" ]]; then log_error "Build context '$folder_path' not found."; return 1; fi
    if [[ ! -f "$folder_path/Dockerfile" ]]; then log_error "Dockerfile not found in '$folder_path'."; return 1; fi
    if [[ -z "$docker_username" ]]; then log_error "Docker username is required."; return 1; fi
    if [[ -z "$docker_repo_prefix" ]]; then log_error "Docker repo prefix is required."; return 1; fi
    if [[ -z "$base_image_tag" ]]; then log_error "Base image tag is required."; return 1; fi

    # Generate the target image tag
    local target_tag
    target_tag=$(generate_image_tag "$docker_username" "$docker_repo_prefix" "$folder_name" "$docker_registry")
    log_info "Target image tag: $target_tag"

    # --- Construct Build Command ---
    local build_cmd_base=""
    local build_cmd_args=()

    # Platform (always needed for buildx, good practice for docker build)
    # PLATFORM should be globally available from env_setup.sh
    build_cmd_args+=( "--platform=${PLATFORM:-linux/arm64}" )

    # Cache option
    if [[ "$use_cache" == "n" ]]; then
        build_cmd_args+=( "--no-cache" )
    fi

    # Squash option (only applicable to 'docker build' or 'docker buildx build' without --push?)
    # Note: Buildx might handle squash differently or ignore it with certain drivers/outputs.
    # Let's add it conditionally based on builder usage for now.
    if [[ "$use_builder" != "y" && "$use_squash" == "y" ]]; then
        build_cmd_args+=( "--squash" )
        log_warning "Using --squash with 'docker build'. This is experimental."
    elif [[ "$use_builder" == "y" && "$use_squash" == "y" ]]; then
         # Buildx squash might depend on the driver and output type.
         # It might be implicitly handled or require specific setup.
         # For now, let's add it but log a warning.
         build_cmd_args+=( "--squash" )
         log_warning "Using --squash with 'docker buildx build'. Behavior depends on builder setup."
    fi


    # Build arguments (Base image + any from .buildargs)
    build_cmd_args+=( "--build-arg" "BASE_IMAGE=${base_image_tag}" )
    local buildargs_file="$folder_path/.buildargs"
    if [[ -f "$buildargs_file" ]]; then
        log_debug "Loading build arguments from $buildargs_file"
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Remove leading/trailing whitespace and skip comments/empty lines
            line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [[ -z "$line" || "$line" =~ ^# ]]; then continue; fi
            # Ensure it's a valid VAR=value pair before adding
            if [[ "$line" =~ ^[a-zA-Z_][a-zA-Z0-9_]*= ]]; then
                log_debug "  Adding build arg: $line"
                build_cmd_args+=( "--build-arg" "$line" )
            else
                log_warning "Ignoring invalid line in $buildargs_file: $line"
            fi
        done < "$buildargs_file"
    fi

    # Tag
    build_cmd_args+=( "-t" "$target_tag" )

    # Build context path
    build_cmd_args+=( "$folder_path" )

    # --- Choose Build Command (build vs buildx) ---
    if [[ "$use_builder" == "y" ]]; then
        # Use buildx
        build_cmd_base="docker buildx build"
        # Add --load or --push based on skip_intermediate
        if [[ "$skip_intermediate" == "y" ]]; then
            build_cmd_args+=( "--load" ) # Load image into local docker images
            log_info "Using 'docker buildx build --load'..."
        else
            build_cmd_args+=( "--push" ) # Push image to registry
            log_info "Using 'docker buildx build --push'..."
            # Attempt login before pushing
            if ! docker_login_interactive "$docker_registry" "$docker_username"; then
                log_error "Docker login failed. Cannot push image."
                return 1
            fi
        fi
        # Add builder instance name if BUILDER_NAME is set
        if [[ -n "${BUILDER_NAME:-}" ]]; then
             build_cmd_args+=( "--builder" "$BUILDER_NAME" )
        fi

    else
        # Use standard docker build
        build_cmd_base="docker build"
        log_info "Using standard 'docker build'..."
        # --load/--push are not applicable here
        if [[ "$skip_intermediate" != "y" ]]; then
             log_warning "'skip_intermediate=n' selected but not using buildx. Image will only be built locally."
        fi
    fi


    # --- Execute Build ---
    log_info "Executing build command:"
    # Use printf for safer command logging, especially with spaces/quotes
    printf "  %s" "$build_cmd_base"
    printf " '%s'" "${build_cmd_args[@]}"
    printf "\n"

    # Run the command
    if "$build_cmd_base" "${build_cmd_args[@]}"; then
        log_success "Successfully built image: $target_tag"
        export fixed_tag="$target_tag" # Export the successful tag
        return 0
    else
        log_error "Failed to build image for stage: $folder_name"
        return 1
    fi
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
    # Need to source dependencies if run directly
    if [ -f "$SCRIPT_DIR_DOCKER/env_setup.sh" ]; then source "$SCRIPT_DIR_DOCKER/env_setup.sh"; else echo "ERROR: Cannot find env_setup.sh for test."; exit 1; fi
    if [ -f "$SCRIPT_DIR_DOCKER/logging.sh" ]; then source "$SCRIPT_DIR_DOCKER/logging.sh"; init_logging; else echo "ERROR: Cannot find logging.sh for test."; exit 1; fi
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
# COMMIT-TRACKING: UUID-20250426-110000-DOCKERHELPERFIX # New UUID for this fix
