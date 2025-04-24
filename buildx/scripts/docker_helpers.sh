#!/bin/bash

# Set strict mode for this critical script
set -euo pipefail

# Source utilities (needed for logging)
SCRIPT_DIR_DOCKER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR_DOCKER/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# Source logging functions if available
# shellcheck disable=SC1091
source "$SCRIPT_DIR_DOCKER/env_setup.sh" 2>/dev/null || true

# =========================================================================
# Function: Setup Docker buildx builder for Jetson
setup_buildx_builder() {
  local builder_name="jetson-builder"
  log_debug "Checking buildx builder: $builder_name"
  if ! docker buildx inspect "$builder_name" &>/dev/null; then
    log_info "Creating buildx builder: $builder_name with NVIDIA container runtime" # Use log_info
    # Attempt to create the builder with necessary options for NVIDIA runtime
    log_debug "Attempting optimized buildx create..."
    if ! docker buildx create --name "$builder_name" --driver-opt env.DOCKER_DEFAULT_RUNTIME=nvidia --driver-opt env.NVIDIA_VISIBLE_DEVICES=all --use; then
      log_warning "Failed to create optimized buildx builder '$builder_name'." # Use log_warning
      log_info "Attempting creation without NVIDIA options as fallback..." # Use log_info
      if ! docker buildx create --name "$builder_name" --use; then
           log_error "Failed to create buildx builder '$builder_name' even with fallback." # Use log_error
           return 1
       else
           log_warning "Builder '$builder_name' created without NVIDIA runtime options. GPU acceleration during build might not work." # Use log_warning
       fi
    fi
    log_success "Successfully created and using builder '$builder_name'." # Use log_success
  else
    # Ensure we're using the right builder if it already exists
    log_debug "Builder '$builder_name' exists. Ensuring it is used."
    if ! docker buildx use "$builder_name"; then
      log_error "Failed to switch to existing buildx builder '$builder_name'." # Use log_error
      return 1
    fi
    log_info "Using existing buildx builder: $builder_name" # Use log_info
  fi
  return 0
}

# =========================================================================
# Function: Verify image exists locally
# Arguments: $1 = image tag to verify
# Returns: 0 if image exists, 1 if not
# =========================================================================
verify_image_exists() {
  local tag_to_check="$1"
  log_debug "Verifying local existence of image: $tag_to_check"
  if [[ -z "$tag_to_check" ]]; then
      log_warning "verify_image_exists called with empty tag." # Use log_warning
      return 1
  fi
  if docker image inspect "$tag_to_check" >/dev/null 2>&1; then
    log_debug "Image found locally: $tag_to_check"
    return 0  # Image exists
  else
    log_debug "Image not found locally: $tag_to_check"
    return 1  # Image does not exist
  fi
}

# =========================================================================
# Function: Pull a Docker image
# Arguments: $1 = image tag to pull
# Returns: 0 if successful, 1 if failed
# =========================================================================
pull_image() {
  local tag_to_pull="$1"
  if [[ -z "$tag_to_pull" ]]; then
      log_error "pull_image called with empty tag." # Use log_error
      return 1
  fi
  log_info "Pulling image $tag_to_pull..." # Use log_info
  if docker pull "$tag_to_pull"; then
    log_success "Successfully pulled $tag_to_pull" # Use log_success
    return 0
  else
    log_error "Failed to pull $tag_to_pull" # Use log_error
    return 1
  fi
}

# =========================================================================
# Function: Check if image exists locally, pull if not (with fallback)
# Arguments: $1 = image tag
# Returns: 0 if image exists locally (after potential pull), 1 on failure
# =========================================================================
check_or_pull_image() {
    local image_tag="$1"
    if [[ -z "$image_tag" ]]; then
        log_error "check_or_pull_image called with empty tag." # Use log_error
        return 1
    fi

    log_debug "Checking for image locally: $image_tag"
    if verify_image_exists "$image_tag"; then
        log_debug "Image $image_tag found locally."
        return 0
    fi

    log_info "Image $image_tag not found locally. Attempting pull..." # Use log_info
    if pull_image "$image_tag"; then
        log_debug "Successfully pulled $image_tag."
        return 0
    fi

    # If pull failed, try fallback (e.g., adding -py3 suffix)
    # NOTE: This fallback is specific and might need adjustment
    local fallback_tag="${image_tag}-py3"
    log_warning "Pull failed for $image_tag. Attempting fallback pull: $fallback_tag..." # Use log_warning
    if pull_image "$fallback_tag"; then
        log_debug "Successfully pulled fallback $fallback_tag."
        # Tag the pulled image with the original name for consistency
        log_info "Tagging $fallback_tag as $image_tag" # Use log_info
        if docker tag "$fallback_tag" "$image_tag"; then
            log_success "Successfully tagged $fallback_tag as $image_tag." # Use log_success
            return 0
        else
            log_error "Failed to tag $fallback_tag as $image_tag." # Use log_error
            return 1
        fi
    else
        log_error "Failed to pull image $image_tag or fallback $fallback_tag." # Use log_error
        return 1
    fi
}

# =========================================================================
# Function: Construct the 'docker run' command string with options
# Arguments:
#   $1: image_name
#   $2: x11_enabled ('true'/'false')
#   $3: gpu_enabled ('true'/'false')
#   $4: ws_enabled ('true'/'false')
#   $5: run_as_root ('true'/'false')
#   $6: non_root_user (optional, defaults to 'kkk' if run_as_root is false)
# Returns: Prints the fully constructed command string to stdout
# =========================================================================
construct_docker_run_command() {
    local image_name="$1"
    local x11_enabled="${2:-false}"
    local gpu_enabled="${3:-true}" # Default GPU to true
    local ws_enabled="${4:-true}"  # Default WS to true
    local run_as_root="${5:-false}" # Default to non-root
    local non_root_user="${6:-kkk}" # Default non-root user
    log_debug "Constructing docker run command for image: $image_name"
    log_debug "Run options: X11=$x11_enabled, GPU=$gpu_enabled, WS=$ws_enabled, Root=$run_as_root, User=$non_root_user"

    local run_cmd="docker run -it --rm" # Basic interactive flags
    local user_arg=""
    local final_opts=""

    # GPU Option
    if [[ "$gpu_enabled" == "true" ]]; then
        final_opts+=" --gpus all"
        log_debug "Adding run option: --gpus all"
    fi

    # Workspace Mount Option
    if [[ "$ws_enabled" == "true" ]]; then
        # Ensure these paths are correct for your system
        final_opts+=" -v /media/kkk:/workspace"
        final_opts+=" -v /run/jtop.sock:/run/jtop.sock"
        log_debug "Adding run options: -v /media/kkk:/workspace -v /run/jtop.sock:/run/jtop.sock"
    fi

    # X11 Forwarding Option
    if [[ "$x11_enabled" == "true" ]]; then
        final_opts+=" -v /tmp/.X11-unix:/tmp/.X11-unix"
        final_opts+=" -e DISPLAY=$DISPLAY"
        log_debug "Adding run options: -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=$DISPLAY"
        # Optionally add --ipc=host if needed
        # final_opts+=" --ipc=host"
    fi

    # User Option
    if [[ "$run_as_root" == "true" ]]; then
        user_arg="--user root"
        log_debug "Adding run option: --user root"
    else
        user_arg="--user $non_root_user"
        log_debug "Adding run option: --user $non_root_user"
    fi

    # Assemble the command string
    # Order: docker run [user] [other opts] image [command]
    local full_command="$run_cmd $user_arg $final_opts $image_name /bin/bash"
    log_debug "Constructed command: $full_command"
    echo "$full_command" # Output command to stdout for capture
}

# =========================================================================
# Function: Run a container using specified options
# Arguments:
#   $1: image_name
#   $2: x11_enabled ('true'/'false')
#   $3: gpu_enabled ('true'/'false')
#   $4: ws_enabled ('true'/'false')
#   $5: run_as_root ('true'/'false')
# Returns: Exit status of the 'docker run' command
# =========================================================================
run_container() {
    local image_name="$1"
    local x11_enabled="${2:-false}"
    local gpu_enabled="${3:-true}"
    local ws_enabled="${4:-true}"
    local run_as_root="${5:-false}"

    log_info "Attempting to run container: $image_name" # Use log_info
    log_debug "Options: X11=$x11_enabled, GPU=$gpu_enabled, WS=$ws_enabled, Root=$run_as_root"

    # 1. Ensure image exists locally (pull if necessary)
    if ! check_or_pull_image "$image_name"; then
        log_error "Image '$image_name' could not be found or pulled." # Use log_error
        # Consider using show_message here if UI interaction is desired on failure
        return 1
    fi
    log_debug "Image '$image_name' is available locally."

    # 2. Construct the command
    local docker_command
    # Capture stdout from construct_docker_run_command
    docker_command=$(construct_docker_run_command "$image_name" "$x11_enabled" "$gpu_enabled" "$ws_enabled" "$run_as_root")
    log_debug "Constructed command for eval: $docker_command"

    # 3. Execute the command
    # Note: Confirmation should ideally happen in the orchestrator *before* calling this function.
    log_info "Executing command:" # Use log_info
    echo "$docker_command" >&2 # Echo command to stderr for user visibility
    log_info "--- Starting Container ---" # Use log_info
    # Use eval carefully, ensure variables are controlled/sanitized upstream
    eval "$docker_command"
    local exit_status=$?
    log_info "--- Container Exited (Code: $exit_status) ---" # Use log_info

    return $exit_status
}

# =========================================================================
# Function: Generate image tag from folder name, username, prefix, registry
# Arguments: $1 = folder path, $2 = docker_username, $3 = repo_prefix, $4 = registry (optional)
# Returns: Echoes generated image tag string (lowercase) to stdout
# Exports: tag (variable containing the generated tag)
# =========================================================================
generate_image_tag() {
  local folder=$1
  local username=$2
  local prefix=$3
  local registry=${4:-} # Optional registry
  log_debug "Generating image tag for folder: $folder, User: $username, Prefix: $prefix, Registry: $registry"

  local image_name=$(basename "$folder")
  local tag_repo="${username}/${prefix}"
  local tag_prefix=""
  [[ -n "$registry" ]] && tag_prefix="${registry}/"

  # Export the tag as a variable accessible after function call
  export tag=$(echo "${tag_prefix}${tag_repo}:${image_name}" | tr '[:upper:]' '[:lower:]')
  log_debug "Generated tag: $tag"
  echo "$tag" # Output tag to stdout for capture
}

# =========================================================================
# Function: Generate timestamped tag for final image
# Arguments: $1 = docker_username, $2 = repo_prefix, $3 = registry (optional), $4 = timestamp (optional)
# Returns: Echoes generated timestamped tag string (lowercase) to stdout
# Exports: timestamped_tag (variable containing the generated tag)
# =========================================================================
generate_timestamped_tag() {
  local username=$1
  local prefix=$2
  local registry=${3:-} # Optional registry
  local timestamp=${4:-$(date +"%Y%m%d-%H%M%S")} # Use current time if not provided
  log_debug "Generating timestamped tag for User: $username, Prefix: $prefix, Registry: $registry, Timestamp: $timestamp"

  local tag_repo="${username}/${prefix}"
  local tag_prefix=""
  [[ -n "$registry" ]] && tag_prefix="${registry}/"

  # Export the tag as a variable accessible after function call
  export timestamped_tag=$(echo "${tag_prefix}${tag_repo}:latest-${timestamp}-1" | tr '[:upper:]' '[:lower:]')
  log_debug "Generated timestamped tag: $timestamped_tag"
  echo "$timestamped_tag" # Output tag to stdout for capture
}

# =========================================================================
# Function: Parse Dockerfile to extract base image from FROM instruction
# Arguments: $1 = dockerfile path
# Returns: Base image name to stdout or empty if not found/parsable
# =========================================================================
extract_base_image() {
  local dockerfile=$1
  log_debug "Extracting base image from Dockerfile: $dockerfile"
  if [[ -f "$dockerfile" ]]; then
    # Extracts the image name after FROM, ignoring platform and alias
    # Handles formats like: FROM [--platform=...] image[:tag] [AS alias]
    local base_image=$(grep -iE '^\s*FROM' "$dockerfile" | head -n 1 | sed -E 's/^\s*FROM\s+(--platform=[^\s]+\s+)?([^\s]+)(\s+AS\s+[^\s]+)?.*$/\2/')
    log_debug "Extracted base image: $base_image"
    echo "$base_image" # Output to stdout
  else
    log_debug "Dockerfile not found: $dockerfile"
    echo "" # Output empty string to stdout
  fi
}

# =========================================================================
# Function: Determine if a Dockerfile uses ARG BASE_IMAGE in its FROM instruction
# Arguments: $1 = dockerfile path
# Returns: 0 if uses ARG BASE_IMAGE, 1 if not or file not found
# =========================================================================
uses_base_image_arg() {
  local dockerfile=$1
  log_debug "Checking if Dockerfile uses ARG BASE_IMAGE: $dockerfile"
  if [[ -f "$dockerfile" ]]; then
    # Check for both ARG BASE_IMAGE declaration and its use in FROM
    if grep -q -iE '^\s*ARG\s+BASE_IMAGE' "$dockerfile" && grep -q -iE '^\s*FROM\s+(.*\$(\{)?BASE_IMAGE(\})?.*)' "$dockerfile"; then
      log_debug "Dockerfile uses ARG BASE_IMAGE."
      return 0 # Uses ARG BASE_IMAGE
    fi
  fi
  log_debug "Dockerfile does not use ARG BASE_IMAGE or file not found."
  return 1 # Does not use ARG BASE_IMAGE or file not found
}

# =========================================================================
# Function: Generate Docker build arguments string for base image
# Arguments: $1 = base image tag
# Returns: Build argument string (e.g., "--build-arg BASE_IMAGE=tag") to stdout or empty
# =========================================================================
generate_base_image_args() {
    local base_image=$1
    log_debug "Generating base image build args for: $base_image"
    if [[ -n "$base_image" ]]; then
        local args="--build-arg BASE_IMAGE=$base_image"
        log_debug "Generated args: $args"
        echo "$args" # Output to stdout
    else
        log_debug "No base image provided, returning empty args."
        echo "" # Output empty string to stdout
    fi
}

# =========================================================================
# Function: Generate Docker build cache arguments string
# Arguments: $1 = use_cache ('y'/'n')
# Returns: "--no-cache" to stdout or empty string
# =========================================================================
generate_cache_args() {
  local use_cache=$1
  log_debug "Generating cache args for use_cache=$use_cache"
# In generate_cache_args function...
  if [[ "$use_cache" == "n" ]]; then
    log_debug "Generated args: --no-cache"
    echo "--no-cache" # Output to stdout
  else
    log_debug "Generated args: (empty)"
    echo "" # Output empty string to stdout
  fi # <--- CORRECTED LINE (was })
}


# =========================================================================
# Function: Generate Docker build push/load arguments string
# Arguments: $1 = skip_push_pull ('y'/'n')
# Returns: "--load" or "--push" to stdout
# =========================================================================
generate_push_load_args() {
  local skip_push_pull=$1
  log_debug "Generating push/load args for skip_push_pull=$skip_push_pull"
  if [[ "$skip_push_pull" == "y" ]]; then
    log_debug "Generated args: --load"
    echo "--load" # Build locally, output to stdout
  else
    log_debug "Generated args: --push"
    echo "--push" # Build and push, output to stdout
  fi
}

# =========================================================================
# Function: Ensure buildx builder is running
# =========================================================================
ensure_buildx_builder_running() {
  local builder_name="jetson-builder"
  log_debug "Ensuring buildx builder '$builder_name' is running."
  if ! docker buildx inspect "$builder_name" &>/dev/null; then
    log_info "Creating buildx builder: $builder_name" # Use log_info
    if ! docker buildx create --name "$builder_name" --driver docker-container --use; then
        log_error "Failed to create buildx builder '$builder_name'." # Use log_error
        return 1
    fi
  else
    log_debug "Using existing builder '$builder_name'."
    if ! docker buildx use "$builder_name"; then
        log_error "Failed to switch to builder '$builder_name'." # Use log_error
        return 1
    fi
  fi
  log_info "Buildx builder '$builder_name' is ready." # Use log_info
  return 0
}

# =========================================================================
# Build a Docker image from a specific folder using buildx
# =========================================================================
# Parameters:
# $1: folder_path - The directory containing the Dockerfile and build context.
# $2: use_cache - 'y' or 'n' to enable/disable Docker build cache.
# $3: platform - Target platform (e.g., linux/arm64).
# $4: use_squash - 'y' or 'n' to enable/disable image squashing.
# $5: skip_intermediate_push_pull - 'y' or 'n' to skip push/pull after build.
# $6: base_image_tag - The base image tag to use (passed as --build-arg BASE_IMAGE).
# $7: docker_username - Docker Hub username.
# $8: repo_prefix - Docker repository prefix.
# $9: registry - Docker registry URL (optional).
# Exports:
# fixed_tag (global): The generated tag for the built image (e.g., [registry/]user/prefix:folder_name).
# Returns: 0 on success, 1 on failure.
# =========================================================================
build_folder_image() {
    local folder_path=$1
    local use_cache=$2
    local platform_arg=$3 # Or whichever argument number platform is
    local use_squash=$4
    local skip_intermediate_push_pull=$5
    local base_image_tag=$6 # Base image tag passed from build.sh
    local docker_username=$7
    local repo_prefix=$8
    local registry=${9:-}

    log_debug "Entering build_folder_image for folder: $folder_path"
    log_debug "Build options: Cache=$use_cache, Platform=$platform, Squash=$use_squash, SkipPush=$skip_intermediate_push_pull"
    log_debug "BaseImage=$base_image_tag, User=$docker_username, Prefix=$repo_prefix, Registry=$registry"

    # Unset the exported variable to ensure we detect failures
    unset fixed_tag 2>/dev/null || true

    local image_name
    image_name=$(basename "$folder_path")

    # --- Construct the tag dynamically ---
    # Capture stdout from generate_image_tag
    if ! export tag=$(generate_image_tag "$folder_path" "$docker_username" "$repo_prefix" "$registry"); then
        log_error "Failed to generate image tag for $folder_path" # Use log_error
        return 1
    fi

    # 'tag' variable is now exported by generate_image_tag
    export fixed_tag="$tag" # Keep fixed_tag export for compatibility if needed elsewhere
    log_debug "Using tag: $fixed_tag"

    log_info "--------------------------------------------------" # Use log_info
    log_info "Building image from folder: $folder_path" # Use log_info
    log_info "Image Name: $image_name" # Use log_info
    log_info "Platform: $platform" # Use log_info
    log_info "Tag: $fixed_tag" # Use log_info
    log_info "Base Image (FROM via ARG): $base_image_tag" # Use log_info
    log_info "Skip Intermediate Push/Pull: $skip_intermediate_push_pull" # Use log_info
    log_info "--------------------------------------------------" # Use log_info

    local build_cmd="docker buildx build --platform "${PLATFORM:-linux/arm64}" -t $fixed_tag" # Use global PLATFORM

    # --- Add BASE_IMAGE build-arg ---
    # Capture stdout from generate_base_image_args
    build_cmd+=" $(generate_base_image_args "$base_image_tag")"

    # --- Add build args from .buildargs file ---
    local build_args_file="$folder_path/.buildargs"
    if [[ -f "$build_args_file" ]]; then
        log_info "Found .buildargs file: $build_args_file" # Use log_info
        while IFS='=' read -r key value || [[ -n "$key" ]]; do
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [[ -n "$key" && ! "$key" =~ ^# ]]; then
                if [[ -n "$value" ]]; then
                    log_debug "  Adding build arg: --build-arg $key=\"$value\""
                    build_cmd+=" --build-arg $key=\"$value\""
                else
                    log_warning "  Skipping build arg '$key': No value provided." # Use log_warning
                fi
            fi
        done < "$build_args_file"
    fi
    # --- End build args handling ---

    # Add cache option
    # Capture stdout from generate_cache_args
    local cache_arg=$(generate_cache_args "$use_cache")
    build_cmd+=" $cache_arg"
    [[ "$use_cache" == "n" ]] && log_info "Using --no-cache" >&2 # Use log_info

    # Add squash option
    if [[ "$use_squash" == "y" ]]; then
        build_cmd+=" --squash"
        log_info "Using --squash" >&2 # Use log_info
    fi

    # Add push/load option
    # Capture stdout from generate_push_load_args
    local push_load_arg=$(generate_push_load_args "$skip_intermediate_push_pull")
    build_cmd+=" $push_load_arg"
    log_info "Using $push_load_arg" >&2 # Use log_info

    # Add the build context path at the end
    build_cmd+=" $folder_path"

    log_info "Running Build Command:" >&2 # Use log_info
    echo "$build_cmd" >&2 # Echo command to stderr for visibility
    log_debug "Executing: $build_cmd"
    if eval "$build_cmd"; then
        log_success "Successfully built image: $fixed_tag" >&2 # Use log_success

        # If push was performed, pull it back to ensure local availability and consistency
        if [[ "$push_load_arg" == "--push" ]]; then
            log_info "Pulling image $fixed_tag to ensure it's available locally..." >&2 # Use log_info
            if ! pull_image "$fixed_tag"; then
                log_error "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" # Use log_error
                log_error "Error: Failed to pull image $fixed_tag after build." # Use log_error
                log_error "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" # Use log_error
                return 1 # Failure
            fi

            # Verify image exists locally after pull
            if ! verify_image_exists "$fixed_tag"; then
                log_error "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" # Use log_error
                log_error "Error: Image $fixed_tag NOT found locally after 'docker pull' succeeded." # Use log_error
                log_error "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" # Use log_error
                return 1 # Failure
            fi

            log_success "Image $fixed_tag verified locally after pull." >&2 # Use log_success
            return 0 # Success
        else # --load was used
            # Verify the image exists locally (due to --load)
            log_info "Verifying image $fixed_tag exists locally (--load used)..." >&2 # Use log_info
             if ! verify_image_exists "$fixed_tag"; then
                 log_error "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" # Use log_error
                 log_error "Error: Image $fixed_tag NOT found locally after build with --load." # Use log_error
                 log_error "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" # Use log_error
                 return 1 # Failure
             fi
             log_success "Image $fixed_tag verified locally." >&2 # Use log_success
             return 0 # Success
        fi
    else
        log_error "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" # Use log_error
        log_error "Error: Failed to build image for $image_name ($folder_path)." # Use log_error
        log_error "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" # Use log_error
        return 1 # Failure
    fi
}

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── docker_helpers.sh  <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Docker build, tag, run, pull, and verification helpers. Added run_container logic. Added logging.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20240806-103000-MODULAR
