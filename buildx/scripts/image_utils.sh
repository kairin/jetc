#!/bin/bash

# =========================================================================
# IMPORTANT: This build system requires Docker with buildx extension.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================
# =========================================================================
# Docker Image Utilities -KS
#
# A collection of utility functions for Docker image manipulation, analysis,
# and management. These utilities handle image-specific tasks such as:
# - Image tagging and management
# - Image inspection and analysis
# - Registry operations
# - Image cleanup and maintenance
# - Layer analysis and optimization
#
# This script is meant to be sourced by other scripts, not executed directly.
# =========================================================================

# =========================================================================
# Function: Tag an existing image with a new tag
# Arguments: $1 = source image tag, $2 = new tag
# Returns: 0 on success, 1 on failure
# =========================================================================
tag_image() {
  local source_tag="$1"
  local target_tag="$2"
  
  echo "Tagging image $source_tag as $target_tag" >&2
  
  if ! docker tag "$source_tag" "$target_tag"; then
    echo "Error: Failed to tag image $source_tag as $target_tag" >&2
    return 1
  fi
  
  echo "Successfully tagged image: $target_tag" >&2
  return 0
}

# =========================================================================
# Function: Push an image to a registry
# Arguments: $1 = image tag to push
# Returns: 0 on success, 1 on failure
# =========================================================================
push_image() {
  local tag="$1"
  
  echo "Pushing image: $tag" >&2
  
  if ! docker push "$tag"; then
    echo "Error: Failed to push image $tag" >&2
    return 1
  fi
  
  echo "Successfully pushed image: $tag" >&2
  return 0
}

# =========================================================================
# Function: Pull an image from a registry
# Arguments: $1 = image tag to pull
# Returns: 0 on success, 1 on failure, outputs pull output to stderr
# =========================================================================
pull_image() {
  local tag="$1"
  
  echo "Pulling image: $tag" >&2
  
  local pull_output
  pull_output=$(docker pull "$tag" 2>&1)
  local pull_status=$?
  
  if [ $pull_status -ne 0 ]; then
    echo "Error: Failed to pull image $tag" >&2
    echo "Pull output:" >&2
    echo "$pull_output" >&2
    return 1
  fi
  
  echo "Successfully pulled image: $tag" >&2
  return 0
}

# =========================================================================
# Function: Create a timestamped tag for an existing image
# Arguments: $1 = source image tag, $2 = base name for timestamped tag
# Returns: The timestamped tag on success, empty on failure
# =========================================================================
create_timestamped_tag() {
  local source_tag="$1"
  local base_name="${2:-latest}"
  
  # Generate timestamped tag
  local current_time=$(date +"%Y%m%d-%H%M%S")
  local timestamped_tag="${source_tag%:*}:${base_name}-${current_time}"
  
  echo "Creating timestamped tag: $timestamped_tag" >&2
  
  if ! docker tag "$source_tag" "$timestamped_tag"; then
    echo "Error: Failed to create timestamped tag for $source_tag" >&2
    return 1
  fi
  
  echo "$timestamped_tag"
  return 0
}

# =========================================================================
# Function: Get image creation date
# Arguments: $1 = image tag
# Returns: Creation date in ISO format, or empty string on failure
# =========================================================================
get_image_created_date() {
  local tag="$1"
  
  local created_date
  created_date=$(docker inspect --format='{{.Created}}' "$tag" 2>/dev/null)
  
  if [ -z "$created_date" ]; then
    echo "Error: Failed to get creation date for image $tag" >&2
    return 1
  fi
  
  echo "$created_date"
  return 0
}

# =========================================================================
# Function: Get image size
# Arguments: $1 = image tag
# Returns: Size in human-readable format, or empty string on failure
# =========================================================================
get_image_size() {
  local tag="$1"
  
  local size
  size=$(docker image inspect --format='{{.Size}}' "$tag" 2>/dev/null)
  
  if [ -z "$size" ]; then
    echo "Error: Failed to get size for image $tag" >&2
    return 1
  fi
  
  # Convert to human-readable format
  if [ $size -gt 1073741824 ]; then
    echo "$(echo "scale=2; $size/1073741824" | bc)GB"
  elif [ $size -gt 1048576 ]; then
    echo "$(echo "scale=2; $size/1048576" | bc)MB"
  elif [ $size -gt 1024 ]; then
    echo "$(echo "scale=2; $size/1024" | bc)KB"
  else
    echo "${size}B"
  fi
  
  return 0
}

# =========================================================================
# Function: Count layers in an image
# Arguments: $1 = image tag
# Returns: Number of layers, or -1 on failure
# =========================================================================
count_image_layers() {
  local tag="$1"
  
  local layer_count
  layer_count=$(docker inspect --format='{{len .RootFS.Layers}}' "$tag" 2>/dev/null)
  
  if [ -z "$layer_count" ]; then
    echo "Error: Failed to count layers for image $tag" >&2
    return 1
  fi
  
  echo "$layer_count"
  return 0
}

# =========================================================================
# Function: Check if an image exceeds safe layer count
# Arguments: $1 = image tag, $2 = max safe layers (default: 100)
# Returns: 0 if safe, 1 if exceeds limit or error
# =========================================================================
check_layer_limit() {
  local tag="$1"
  local max_safe_layers="${2:-100}"
  
  local layer_count
  layer_count=$(count_image_layers "$tag")
  local status=$?
  
  if [ $status -ne 0 ]; then
    return 1
  fi
  
  echo "Image $tag has $layer_count layers (safe limit: $max_safe_layers)" >&2
  
  if [ $layer_count -ge $max_safe_layers ]; then
    echo "Warning: Image $tag is approaching or exceeding the layer limit!" >&2
    return 1
  fi
  
  return 0
}

# =========================================================================
# Function: Find dangling images
# Returns: List of dangling image IDs
# =========================================================================
find_dangling_images() {
  local dangling_images
  dangling_images=$(docker images -f "dangling=true" -q)
  
  echo "$dangling_images"
}

# =========================================================================
# Function: Clean up dangling images
# Returns: 0 on success or no images to clean, 1 on failure
# =========================================================================
cleanup_dangling_images() {
  local dangling_images
  dangling_images=$(find_dangling_images)
  
  if [ -z "$dangling_images" ]; then
    echo "No dangling images to clean up" >&2
    return 0
  fi
  
  echo "Cleaning up $(echo "$dangling_images" | wc -w) dangling images" >&2
  
  if ! docker rmi $dangling_images; then
    echo "Error: Failed to remove some dangling images" >&2
    return 1
  fi
  
  echo "Successfully cleaned up dangling images" >&2
  return 0
}

# =========================================================================
# Function: List all images for a repository
# Arguments: $1 = repository name (e.g., username/repo)
# Returns: List of image tags
# =========================================================================
list_repository_images() {
  local repo="$1"
  
  local images
  images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^$repo" 2>/dev/null)
  
  echo "$images"
}

# =========================================================================
# Function: Verify image can be run
# Arguments: $1 = image tag to verify
# Returns: 0 if runnable, 1 if not
# =========================================================================
verify_image_runnable() {
  local tag="$1"
  
  echo "Verifying image $tag is runnable..." >&2
  
  if ! docker run --rm "$tag" echo "Image verification successful"; then
    echo "Error: Image $tag failed basic runtime verification" >&2
    return 1
  fi
  
  echo "Image $tag verified as runnable" >&2
  return 0
}

# =========================================================================
# Function: Save image to a tar file
# Arguments: $1 = image tag, $2 = output file path
# Returns: 0 on success, 1 on failure
# =========================================================================
save_image() {
  local tag="$1"
  local output_path="$2"
  
  echo "Saving image $tag to $output_path..." >&2
  
  if ! docker save -o "$output_path" "$tag"; then
    echo "Error: Failed to save image $tag to $output_path" >&2
    return 1
  fi
  
  echo "Successfully saved image to $output_path" >&2
  echo "File size: $(du -h "$output_path" | cut -f1)" >&2
  return 0
}

# =========================================================================
# Function: Load image from a tar file
# Arguments: $1 = input file path
# Returns: 0 on success, 1 on failure
# =========================================================================
load_image() {
  local input_path="$1"
  
  echo "Loading image from $input_path..." >&2
  
  if ! docker load -i "$input_path"; then
    echo "Error: Failed to load image from $input_path" >&2
    return 1
  fi
  
  echo "Successfully loaded image from $input_path" >&2
  return 0
}

# =========================================================================
# Function: Compare two images for size difference
# Arguments: $1 = first image tag, $2 = second image tag
# Returns: 0 on success (outputs comparison), 1 on failure
# =========================================================================
compare_image_sizes() {
  local image1="$1"
  local image2="$2"
  
  local size1
  size1=$(docker image inspect --format='{{.Size}}' "$image1" 2>/dev/null)
  if [ -z "$size1" ]; then
    echo "Error: Could not get size for image $image1" >&2
    return 1
  fi
  
  local size2
  size2=$(docker image inspect --format='{{.Size}}' "$image2" 2>/dev/null)
  if [ -z "$size2" ]; then
    echo "Error: Could not get size for image $image2" >&2
    return 1
  fi
  
  local diff=$(($size2 - $size1))
  local percentage=$(echo "scale=2; ($diff / $size1) * 100" | bc)
  
  echo "Image Size Comparison:" >&2
  echo "  $image1: $(get_image_size "$image1")" >&2
  echo "  $image2: $(get_image_size "$image2")" >&2
  
  if [ $diff -gt 0 ]; then
    echo "  Difference: +$(echo "scale=2; $diff/1048576" | bc)MB ($percentage% larger)" >&2
  elif [ $diff -lt 0 ]; then
    echo "  Difference: $(echo "scale=2; $diff/1048576" | bc)MB ($percentage% smaller)" >&2
  else
    echo "  Difference: No size difference" >&2
  fi
  
  return 0
}
