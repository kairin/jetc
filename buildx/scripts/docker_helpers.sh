#!/bin/bash
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── docker_helpers.sh  <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Helper functions for Docker build, tag, push, pull, and verification operations.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250421-020700-REFA

# =========================================================================
# Function: Setup Docker buildx builder for Jetson
# Returns: 0 if successful, 1 if not
# =========================================================================
setup_buildx_builder() {
  local builder_name="jetson-builder"
  if ! docker buildx inspect "$builder_name" &>/dev/null; then
    echo "Creating buildx builder: $builder_name with NVIDIA container runtime" >&2
    # Attempt to create the builder with necessary options for NVIDIA runtime
    docker buildx create --name "$builder_name" --driver-opt env.DOCKER_DEFAULT_RUNTIME=nvidia --driver-opt env.NVIDIA_VISIBLE_DEVICES=all --use
    if [ $? -ne 0 ]; then
      echo "Failed to create buildx builder '$builder_name'." >&2
      echo "Attempting creation without NVIDIA options as fallback..." >&2
      docker buildx create --name "$builder_name" --use
       if [ $? -ne 0 ]; then
           echo "Failed to create buildx builder '$builder_name' even with fallback." >&2
           return 1
       else
           echo "Warning: Builder '$builder_name' created without NVIDIA runtime options. GPU acceleration during build might not work." >&2
       fi
    fi
    echo "Successfully created and using builder '$builder_name'." >&2
  else
    # Ensure we're using the right builder if it already exists
    if ! docker buildx use "$builder_name"; then
      echo "Failed to switch to existing buildx builder '$builder_name'." >&2
      return 1
    fi
    echo "Using existing buildx builder: $builder_name" >&2
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
  if [[ -z "$tag_to_check" ]]; then
      echo "Warning: verify_image_exists called with empty tag." >&2
      return 1
  fi
  if docker image inspect "$tag_to_check" >/dev/null 2>&1; then
    # echo "Image $tag_to_check found locally." >&2 # Optional: uncomment for verbose logging
    return 0  # Image exists
  else
    # echo "Image $tag_to_check not found locally." >&2 # Optional: uncomment for verbose logging
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
      echo "Error: pull_image called with empty tag." >&2
      return 1
  fi
  echo "Pulling image $tag_to_pull..." >&2
  if docker pull "$tag_to_pull"; then
    echo "Successfully pulled $tag_to_pull" >&2
    return 0
  else
    echo "Error: Failed to pull $tag_to_pull" >&2
    return 1
  fi
}

# =========================================================================
# Function: Generate image tag from folder name, username, prefix, registry
# Arguments: $1 = folder path, $2 = docker_username, $3 = repo_prefix, $4 = registry (optional)
# Returns: Generated image tag string (lowercase)
# Exports:   tag (variable containing the generated tag)
# =========================================================================
generate_image_tag() {
  local folder=$1
  local username=$2
  local prefix=$3
  local registry=${4:-} # Optional registry

  local image_name=$(basename "$folder")
  local tag_repo="${username}/${prefix}"
  local tag_prefix=""
  [[ -n "$registry" ]] && tag_prefix="${registry}/"

  # Export the tag as a variable accessible after function call
  export tag=$(echo "${tag_prefix}${tag_repo}:${image_name}" | tr '[:upper:]' '[:lower:]')
  echo "$tag" # Also echo for direct use
}

# =========================================================================
# Function: Generate timestamped tag for final image
# Arguments: $1 = docker_username, $2 = repo_prefix, $3 = registry (optional), $4 = timestamp (optional)
# Returns: Generated timestamped tag string (lowercase)
# Exports:   timestamped_tag (variable containing the generated tag)
# =========================================================================
generate_timestamped_tag() {
  local username=$1
  local prefix=$2
  local registry=${3:-} # Optional registry
  local timestamp=${4:-$(date +"%Y%m%d-%H%M%S")} # Use current time if not provided

  local tag_repo="${username}/${prefix}"
  local tag_prefix=""
  [[ -n "$registry" ]] && tag_prefix="${registry}/"

  # Export the tag as a variable accessible after function call
  export timestamped_tag=$(echo "${tag_prefix}${tag_repo}:latest-${timestamp}-1" | tr '[:upper:]' '[:lower:]')
  echo "$timestamped_tag" # Also echo for direct use
}

# =========================================================================
# Function: Parse Dockerfile to extract base image from FROM instruction
# Arguments: $1 = dockerfile path
# Returns: Base image name or empty if not found/parsable
# =========================================================================
extract_base_image() {
  local dockerfile=$1
  if [[ -f "$dockerfile" ]]; then
    # Extracts the image name after FROM, ignoring platform and alias
    # Handles formats like: FROM [--platform=...] image[:tag] [AS alias]
    local base_image=$(grep -iE '^\s*FROM' "$dockerfile" | head -n 1 | sed -E 's/^\s*FROM\s+(--platform=[^\s]+\s+)?([^\s]+)(\s+AS\s+[^\s]+)?.*$/\2/')
    echo "$base_image"
  else
    echo ""
  fi
}

# =========================================================================
# Function: Determine if a Dockerfile uses ARG BASE_IMAGE in its FROM instruction
# Arguments: $1 = dockerfile path
# Returns: 0 if uses ARG BASE_IMAGE, 1 if not or file not found
# =========================================================================
uses_base_image_arg() {
  local dockerfile=$1
  if [[ -f "$dockerfile" ]]; then
    # Check for both ARG BASE_IMAGE declaration and its use in FROM
    if grep -q -iE '^\s*ARG\s+BASE_IMAGE' "$dockerfile" && grep -q -iE '^\s*FROM\s+(.*\$(\{)?BASE_IMAGE(\})?.*)' "$dockerfile"; then
      return 0 # Uses ARG BASE_IMAGE
    fi
  fi
  return 1 # Does not use ARG BASE_IMAGE or file not found
}

# =========================================================================
# Function: Generate Docker build arguments string for base image
# Arguments: $1 = base image tag
# Returns: Build argument string (e.g., "--build-arg BASE_IMAGE=tag") or empty
# =========================================================================
generate_base_image_args() {
  local base_image=$1
  if [[ -n "$base_image" ]]; then
    echo "--build-arg BASE_IMAGE=$base_image"
  else
    echo ""
  fi
}

# =========================================================================
# Function: Generate Docker build cache arguments string
# Arguments: $1 = use_cache ('y'/'n')
# Returns: "--no-cache" or empty string
# =========================================================================
generate_cache_args() {
  local use_cache=$1
  if [[ "$use_cache" == "n" ]]; then
    echo "--no-cache"
  else
    echo ""
  fi
}

# =========================================================================
# Function: Generate Docker build push/load arguments string
# Arguments: $1 = skip_push_pull ('y'/'n')
# Returns: "--load" or "--push"
# =========================================================================
generate_push_load_args() {
  local skip_push_pull=$1
  if [[ "$skip_push_pull" == "y" ]]; then
    echo "--load" # Build locally
  else
    echo "--push" # Build and push
  fi
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
    local platform=$3
    local use_squash=$4
    local skip_intermediate_push_pull=$5
    local base_image_tag=$6 # Base image tag passed from build.sh
    local docker_username=$7
    local repo_prefix=$8
    local registry=${9:-}

    local image_name
    image_name=$(basename "$folder_path")

    # --- Construct the tag dynamically ---
    generate_image_tag "$folder_path" "$docker_username" "$repo_prefix" "$registry"
    # 'tag' variable is now exported by generate_image_tag
    export fixed_tag="$tag" # Keep fixed_tag export for compatibility if needed elsewhere

    echo "--------------------------------------------------"
    echo "Building image from folder: $folder_path"
    echo "Image Name: $image_name"
    echo "Platform: $platform"
    echo "Tag: $fixed_tag"
    echo "Base Image (FROM via ARG): $base_image_tag"
    echo "Skip Intermediate Push/Pull: $skip_intermediate_push_pull"
    echo "--------------------------------------------------"

    local build_cmd="docker buildx build --platform $platform -t $fixed_tag"

    # --- Add BASE_IMAGE build-arg ---
    build_cmd+=" $(generate_base_image_args "$base_image_tag")"

    # --- Add build args from .buildargs file ---
    local build_args_file="$folder_path/.buildargs"
    if [[ -f "$build_args_file" ]]; then
        echo "Found .buildargs file: $build_args_file"
        while IFS='=' read -r key value || [[ -n "$key" ]]; do
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [[ -n "$key" && ! "$key" =~ ^# ]]; then
                if [[ -n "$value" ]]; then
                    echo "  Adding build arg: --build-arg $key=\"$value\""
                    build_cmd+=" --build-arg $key=\"$value\""
                else
                    echo "  Skipping build arg '$key': No value provided." >&2
                fi
            fi
        done < "$build_args_file"
    fi
    # --- End build args handling ---

    # Add cache option
    build_cmd+=" $(generate_cache_args "$use_cache")"
    [[ "$use_cache" == "n" ]] && echo "Using --no-cache" >&2

    # Add squash option
    if [[ "$use_squash" == "y" ]]; then
        build_cmd+=" --squash"
        echo "Using --squash" >&2
    fi

    # Add push/load option
    local push_load_arg=$(generate_push_load_args "$skip_intermediate_push_pull")
    build_cmd+=" $push_load_arg"
    echo "Using $push_load_arg" >&2

    # Add the build context path at the end
    build_cmd+=" $folder_path"

    echo "Running Build Command:" >&2
    echo "$build_cmd" >&2
    if eval "$build_cmd"; then
        echo "Successfully built image: $fixed_tag" >&2

        # If push was performed, pull it back to ensure local availability and consistency
        if [[ "$push_load_arg" == "--push" ]]; then
            echo "Pulling image $fixed_tag to ensure it's available locally..." >&2
            if pull_image "$fixed_tag"; then
                echo "Successfully pulled image $fixed_tag." >&2
                # Verify image exists locally after pull
                if verify_image_exists "$fixed_tag"; then
                    echo "Image $fixed_tag verified locally after pull." >&2
                    return 0 # Success
                else
                    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
                    echo "Error: Image $fixed_tag NOT found locally after 'docker pull' succeeded." >&2
                    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
                    return 1 # Failure
                fi
            else
                # pull_image already prints error
                return 1 # Failure
            fi
        else # --load was used
            # Verify the image exists locally (due to --load)
            echo "Verifying image $fixed_tag exists locally (--load used)..." >&2
             if verify_image_exists "$fixed_tag"; then
                 echo "Image $fixed_tag verified locally." >&2
                 return 0 # Success
             else
                 echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
                 echo "Error: Image $fixed_tag NOT found locally after build with --load." >&2
                 echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
                 return 1 # Failure
             fi
        fi
    else
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
        echo "Error: Failed to build image for $image_name ($folder_path)." >&2
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
        return 1 # Failure
    fi
}
