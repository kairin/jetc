#!/bin/bash

# COMMIT-TRACKING: UUID-20240802-174500-IMGH
# Description: Consolidated script for Docker image naming and tagging
# Author: GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── UUID-images.sh     <- THIS FILE
# └── ...                        <- Other project files

# =========================================================================
# Function: Generate image tag from folder name
# Arguments: $1 = folder path, $2 = docker_username
# Returns: Generated image tag string
# =========================================================================
generate_image_tag() {
  local folder=$1
  local docker_username=$2
  
  local image_name=$(basename "$folder" | tr '[:upper:]' '[:lower:]')
  echo "${docker_username}/001:${image_name}"
}

# =========================================================================
# Function: Generate timestamped tag for final image
# Arguments: $1 = docker_username, $2 = timestamp (optional, defaults to current)
# Returns: Generated timestamped tag string
# =========================================================================
generate_timestamped_tag() {
  local docker_username=$1
  local timestamp=${2:-$(date +"%Y%m%d-%H%M%S")}
  
  echo "${docker_username}/001:latest-${timestamp}-1" | tr '[:upper:]' '[:lower:]'
}

# =========================================================================
# Function: Parse Dockerfile to extract base image
# Arguments: $1 = dockerfile path
# Returns: Base image name or empty if not found
# =========================================================================
extract_base_image() {
  local dockerfile=$1
  
  if [[ -f "$dockerfile" ]]; then
    local base_image=$(grep -E '^FROM' "$dockerfile" | head -1 | sed -E 's/FROM\s+(\-\-platform=[^\s]+\s+)?([^\s]+).*/\2/')
    echo "$base_image"
  else
    echo ""
  fi
}

# =========================================================================
# Function: Determine if a Dockerfile uses ARG BASE_IMAGE
# Arguments: $1 = dockerfile path
# Returns: 0 if uses ARG BASE_IMAGE, 1 if not
# =========================================================================
uses_base_image_arg() {
  local dockerfile=$1
  
  if [[ -f "$dockerfile" ]]; then
    if grep -q 'ARG BASE_IMAGE' "$dockerfile" && grep -q 'FROM.*\${BASE_IMAGE}' "$dockerfile"; then
      return 0
    fi
  fi
  return 1
}

# =========================================================================
# Function: Generate Docker build arguments for base image
# Arguments: $1 = base image tag
# Returns: Build argument string
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
# Function: Generate Docker build cache arguments
# Arguments: $1 = use_cache (y/n)
# Returns: Cache argument string
# =========================================================================
generate_cache_args() {
  local use_cache=$1
  
  if [[ "$use_cache" != "y" ]]; then
    echo "--no-cache"
  else
    echo ""
  fi
}

# =========================================================================
# Function: Generate Docker build push/load arguments
# Arguments: $1 = skip_push_pull (y/n)
# Returns: Push/load argument string
# =========================================================================
generate_push_load_args() {
  local skip_push_pull=$1
  
  if [[ "$skip_push_pull" == "y" ]]; then
    echo "--load"
  else
    echo "--push"
  fi
}

# =========================================================================
# Function: Verify if an image exists locally
# Arguments: $1 = image tag
# Returns: 0 if exists, 1 if not
# =========================================================================
image_exists_locally() {
  local tag=$1
  
  if docker image inspect "$tag" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# =========================================================================
# Function: Pull an image if it doesn't exist locally
# Arguments: $1 = image tag
# Returns: 0 if successful (already exists or pulled), 1 if failed
# =========================================================================
ensure_image_available() {
  local tag=$1
  
  if image_exists_locally "$tag"; then
    echo "Image $tag already exists locally."
    return 0
  else
    echo "Pulling image $tag..."
    if docker pull "$tag"; then
      echo "Successfully pulled $tag"
      return 0
    else
      echo "Failed to pull $tag"
      return 1
    fi
  fi
}

# Usage examples:
# tag=$(generate_image_tag "/path/to/folder" "myusername")
# echo "Generated tag: $tag"
#
# timestamped=$(generate_timestamped_tag "myusername")
# echo "Timestamped tag: $timestamped"
