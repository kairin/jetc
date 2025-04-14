#!/bin/bash

# =========================================================================
# IMPORTANT: This build system requires Docker with buildx extension.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

# =========================================================================
# Image Building Functions for Docker Build Process
# =========================================================================

# =========================================================================
# Function: Fix layer limit issues by flattening an image
# Arguments: $1 = image tag to flatten
# Returns: 0 on success, 1 on failure
# =========================================================================
fix_layer_limit() {
  local tag="$1"
  
  echo -e "\nAttempting to fix layer limit issue for image: $tag" >&2
  
  # Extract the image name part after the colon for use as the next stage name
  local image_name="${tag##*:}"

  # Monitor the flattening process using pv if available
  if command -v pv >/dev/null 2>&1; then
    # Use pv to show a progress bar
    echo "Starting image flattening process with progress bar..." >&2
    ./scripts/auto_flatten_images.sh "$tag" "$image_name" 2>&1 | pv -pt -i 0.5 > /dev/null
    flatten_status=${PIPESTATUS[0]}
  else
    # Fallback to our custom progress indicator
    echo "Starting image flattening process..." >&2
    # Create a background process to show progress while flattening happens
    (
      i=0
      max=100
      while [ $i -lt $max ] && ! [ -f /tmp/flattening_complete ]; do
        show_progress $i $max "Flattening image"
        i=$((i + 1))
        if [ $i -eq $max ]; then i=0; fi
        sleep 1
      done
      # Ensure we show 100% at the end
      show_progress 100 100 "Flattening image"
      echo # Add newline after progress bar
    ) &
    progress_pid=$!
    
    # Run the actual flattening
    ./scripts/auto_flatten_images.sh "$tag" "$image_name" >/dev/null
    flatten_status=$?
    
    # Signal completion to the progress display
    touch /tmp/flattening_complete
    sleep 1.5  # Give the progress bar time to complete
    rm -f /tmp/flattening_complete
    
    # Clean up the progress display
    kill $progress_pid 2>/dev/null || true
    wait $progress_pid 2>/dev/null || true
    echo # Add newline after progress bar
  fi
  
  if [ $flatten_status -eq 0 ]; then
    echo "✅ Successfully flattened image $tag" >&2
    # Pull the flattened image to verify it worked
    echo "Pulling flattened image: $tag" >&2
    if docker pull "$tag" >&2; then
      echo "Successfully pulled flattened image!" >&2
      return 0
    else
      echo "Failed to pull flattened image after flattening." >&2
      return 1
    fi
  else
    echo "❌ Failed to flatten image $tag" >&2
    return 1
  fi
}

# =========================================================================
# Function: Create preventatively flattened version of an image for next step
# Arguments: $1 = source image tag, $2 = target image name for next step
# Returns: 0 on success, 1 on failure
# =========================================================================
flatten_for_next_step() {
  local source_tag="$1"
  local next_step_name="$2"
  
  echo -e "\nCreating flattened version for next build step..." >&2
  
  # Monitor the flattening process using pv if available
  if command -v pv >/dev/null 2>&1; then
    # Use pv to show a progress bar
    echo "Starting preventative flattening with progress bar..." >&2
    local flattened_tag=$(./scripts/auto_flatten_images.sh "$source_tag" "$next_step_name" 2>&1 | pv -pt -i 0.5)
    flatten_status=${PIPESTATUS[0]}
  else
    # Fallback to our custom progress indicator
    echo "Starting preventative flattening..." >&2
    # Create a background process to show progress while flattening happens
    (
      i=0
      max=100
      while [ $i -lt $max ] && ! [ -f /tmp/flattening_complete ]; do
        show_progress $i $max "Preventative flattening"
        i=$((i + 1))
        if [ $i -eq $max ]; then i=0; fi
        sleep 1
      done
      # Ensure we show 100% at the end
      show_progress 100 100 "Preventative flattening"
      echo # Add newline after progress bar
    ) &
    progress_pid=$!
    
    # Run the actual flattening
    local flattened_tag=$(./scripts/auto_flatten_images.sh "$source_tag" "$next_step_name" 2>/dev/null)
    flatten_status=$?
    
    # Signal completion to the progress display
    touch /tmp/flattening_complete
    sleep 1.5  # Give the progress bar time to complete
    rm -f /tmp/flattening_complete
    
    # Clean up the progress display
    kill $progress_pid 2>/dev/null || true
    wait $progress_pid 2>/dev/null || true
    echo # Add newline after progress bar
  fi
  
  if [ $flatten_status -eq 0 ] && [ -n "$flattened_tag" ]; then
    echo "✅ Successfully created flattened version: $flattened_tag for next step" >&2
    return 0
  else
    echo "⚠️ Warning: Failed to create flattened version for next step." >&2
    return 1
  fi
}

# =========================================================================
# Function: Build, push, and pull a Docker image from a folder
# Arguments: $1 = folder path, $2 = base image tag (optional)
# Returns: The fixed tag name on success, non-zero exit status on failure
# =========================================================================
build_folder_image() {
  local folder=$1
  local base_tag_arg=$2  # The tag to pass as BASE_IMAGE build-arg
  local image_name=$(basename "$folder" | tr '[:upper:]' '[:lower:]')  # Lowercase image name

  # Generate the image tag
  local fixed_tag=$(echo "${DOCKER_USERNAME}/001:${image_name}" | tr '[:upper:]' '[:lower:]')
  echo "Generating fixed tag: $fixed_tag" >&2

  # Record this tag as attempted even before we try to build it
  ATTEMPTED_TAGS+=("$fixed_tag")

  # Validate Dockerfile exists in the folder
  if [ ! -f "$folder/Dockerfile" ]; then
    echo "Warning: Dockerfile not found in $folder. Skipping." >&2
    return 1  # Skip this folder
  fi

  # Setup build arguments
  local build_args=()
  if [ -n "$base_tag_arg" ]; then
      build_args+=(--build-arg "BASE_IMAGE=$base_tag_arg")
      echo "Using base image build arg: $base_tag_arg" >&2
  else
      echo "No base image build arg provided (likely the first image)." >&2
  fi

  # Print build information
  echo "--------------------------------------------------" >&2
  echo "Building and pushing image from folder: $folder" >&2
  echo "Image Name: $image_name" >&2
  echo "Platform: $PLATFORM" >&2
  echo "Tag: $fixed_tag" >&2
  echo "--------------------------------------------------" >&2

  # Build and push the image
  local cmd_args=("--platform" "$PLATFORM" "-t" "$fixed_tag" "${build_args[@]}" --push "$folder")
  if [ "$use_cache" != "y" ]; then
      cmd_args=("--no-cache" "${cmd_args[@]}")
  fi

  # Execute the build command
  docker buildx build "${cmd_args[@]}"
  local build_status=$?
  
  # If the build fails with GPU error, try again without GPU
  if [ $build_status -ne 0 ]; then
    if docker buildx inspect | grep -q 'gpu'; then
      echo "First build attempt failed. Trying again without GPU capabilities..." >&2
      # Create a new builder without GPU
      docker buildx rm jetson-builder || true
      docker buildx create --name jetson-builder --use
      # Try build again
      docker buildx build "${cmd_args[@]}"
      build_status=$?
    fi
  fi
  
  # Check if build and push succeeded
  if [ $build_status -ne 0 ]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
    echo "Error: Failed to build and push image for $image_name ($folder)." >&2
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
    BUILD_FAILED=1
    return 1
  fi

  # Pull the image immediately after successful push to verify it's accessible
  echo "Pulling built image: $fixed_tag" >&2
  local pull_output
  pull_output=$(docker pull "$fixed_tag" 2>&1)
  local pull_status=$?
  
  # Check for layer limit errors in the pull output
  if [ $pull_status -ne 0 ]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
    echo "Error: Failed to pull the built image $fixed_tag after push." >&2
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
    
    # Check for specific layer depth error
    if [[ "$pull_output" == *"max depth exceeded"* ]]; then
      echo "DETECTED: Layer limit error ('max depth exceeded')" >&2
      echo "This is a Docker limitation on maximum layer depth." >&2
      
      if [ "$ENABLE_FLATTENING" = true ]; then
        echo "Attempting to fix layer limit issue..." >&2
        
        if fix_layer_limit "$fixed_tag"; then
          echo "Layer limit issue successfully addressed." >&2
        else
          echo "Failed to address layer limit issue." >&2
          BUILD_FAILED=1
          return 1
        fi
      else
        echo "Image flattening is disabled. Enable it to automatically fix this issue." >&2
        echo "Full error output:" >&2
        echo "$pull_output" >&2
        BUILD_FAILED=1
        return 1
      fi
    else
      # Other pull errors
      echo "Full error output:" >&2
      echo "$pull_output" >&2
      BUILD_FAILED=1
      return 1
    fi
  fi

  # Verify image exists locally after pull
  echo "Verifying image $fixed_tag exists locally after pull..." >&2
  if ! verify_image_exists "$fixed_tag"; then
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
      echo "Error: Image $fixed_tag NOT found locally immediately after successful 'docker pull'." >&2
      echo "This indicates a potential issue with the Docker daemon or registry synchronization." >&2
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
      BUILD_FAILED=1
      return 1
  fi

  echo "Image $fixed_tag verified locally." >&2

  # If flattening is enabled and this image will be used as a base for another image,
  # create a flattened version to prevent layer limit issues in the next step
  if [ "$ENABLE_FLATTENING" = true ]; then
    # Get the index of the current folder in the numbered_dirs array
    local current_index=-1
    local next_index=-1
    for i in "${!numbered_dirs[@]}"; do
      if [[ "${numbered_dirs[$i]}" == "$folder" ]]; then
        current_index=$i
        next_index=$((i+1))
        break
      fi
    done

    # If there's a next folder, flatten this image proactively for the next step
    if [ $current_index -ne -1 ] && [ $next_index -lt ${#numbered_dirs[@]} ]; then
      local next_folder="${numbered_dirs[$next_index]}"
      local next_name=$(basename "$next_folder" | tr '[:upper:]' '[:lower:]')
      
      echo "Proactively flattening image for next build step: $next_name" >&2
      flatten_for_next_step "$fixed_tag" "$next_name"
      # Note: we don't fail the build if preventative flattening fails
    fi
  fi

  # Record successful build
  BUILT_TAGS+=("$fixed_tag")

  # Return the tag name (will be captured by the caller)
  echo "$fixed_tag"
  return 0
}