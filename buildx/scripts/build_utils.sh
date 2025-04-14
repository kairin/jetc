#!/bin/bash
# =========================================================================
# Docker Build Utilities - KS
#
# A collection of utility functions for Docker image building, verification,
# and management. These utilities handle common tasks such as:
# - Image existence verification
# - Progress visualization
# - Layer depth management (flattening)
# - Container application verification
# - Installed package listing
#
# This script is meant to be sourced by other scripts, not executed directly.
# =========================================================================

# =========================================================================
# Function: Verify image exists locally
# Arguments: $1 = image tag to verify
# Returns: 0 if image exists, 1 if not
# =========================================================================
verify_image_exists() {
  local tag=$1
  if docker image inspect "$tag" &> /dev/null; then
    return 0  # Image exists
  else
    return 1  # Image does not exist
  fi
}

# =========================================================================
# Function: Display a progress bar
# Arguments: $1 = current value, $2 = max value, $3 = operation description
# =========================================================================
show_progress() {
  local current=$1
  local max=$2
  local description=$3
  local percentage=$((current * 100 / max))
  local completed=$((percentage / 2))
  local remaining=$((50 - completed))
  
  # Create the progress bar
  local bar="["
  for ((i=0; i<completed; i++)); do
    bar+="="
  done
  
  if [ $completed -lt 50 ]; then
    bar+=">"
    for ((i=0; i<remaining-1; i++)); do
      bar+=" "
    done
  else
    bar+="="
  fi
  
  bar+="] ${percentage}%"
  
  # Print the progress bar and operation description
  printf "\r%-80s" "${description}: ${bar}"
}

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
    ./auto_flatten_images.sh "$tag" "$image_name" 2>&1 | pv -pt -i 0.5 > /dev/null
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
    ./auto_flatten_images.sh "$tag" "$image_name" >/dev/null
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
    local flattened_tag=$(./auto_flatten_images.sh "$source_tag" "$next_step_name" 2>&1 | pv -pt -i 0.5)
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
    local flattened_tag=$(./auto_flatten_images.sh "$source_tag" "$next_step_name" 2>/dev/null)
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
# Function: Run verification directly in an existing container
# Arguments: $1 = image tag to check, $2 = verification mode (optional)
# =========================================================================
verify_container_apps() {
  local tag=$1
  local verify_mode="${2:-quick}"
  
  echo "Running verification directly in $tag container (mode: $verify_mode)..." >&2
  
  # Copy the verification script into the container and run it
  # First create a temporary container
  local container_id=$(docker create "$tag" bash)
  
  # Copy the script into the container
  docker cp list_installed_apps.sh "$container_id:/tmp/verify_apps.sh"
  
  # Start the container and run the script
  docker start -a "$container_id"
  docker exec "$container_id" bash -c "chmod +x /tmp/verify_apps.sh && /tmp/verify_apps.sh $verify_mode"
  
  # Remove the container
  docker rm -f "$container_id" > /dev/null
  
  return $?
}

# =========================================================================
# Function: List installed apps in the latest image
# Arguments: $1 = image tag to check
# =========================================================================
list_installed_apps() {
  local image_tag=$1
  
  if [ -z "$image_tag" ]; then
    echo "Error: No image tag provided to list_installed_apps function" >&2
    return 1
  fi
  
  echo "--------------------------------------------------" >&2
  echo "Listing installed apps in: $image_tag" >&2
  echo "--------------------------------------------------" >&2
  
  # Mount the script into the container and run it
  docker run -it --rm \
    -v "$(pwd)/list_installed_apps.sh:/tmp/list_installed_apps.sh" \
    --entrypoint /bin/bash \
    "$image_tag" \
    -c "chmod +x /tmp/list_installed_apps.sh && /tmp/list_installed_apps.sh"
}

# =========================================================================
# Function: Check Docker requirements and setup
# Returns: 0 if all requirements met, 1 if not
# =========================================================================
check_docker_requirements() {
  # Check if Docker is running
  if ! docker info >/dev/null 2>&1; then
    echo "Error: Cannot connect to the Docker daemon. Is Docker running?" >&2
    return 1
  fi
  
  # Check Docker login status
  if ! docker info | grep -q "Username"; then
    echo "Warning: You may not be logged into Docker. Images may fail to push if credentials are required." >&2
    read -p "Continue anyway? (y/n): " continue_without_login
    if [[ "$continue_without_login" != "y" ]]; then
      echo "Aborting. Please run 'docker login' and try again." >&2
      return 1
    fi
  fi
  
  # Verify network connectivity
  echo "Checking network connectivity..."
  if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1 && ! ping -c 1 -W 5 1.1.1.1 >/dev/null 2>&1; then
    echo "Warning: Network connectivity issues detected. Build process may fail when accessing remote resources." >&2
    read -p "Continue despite network issues? (y/n): " continue_with_network_issues
    if [[ "$continue_with_network_issues" != "y" ]]; then
      echo "Aborting build process." >&2
      return 1
    fi
  fi
  
  return 0
}

# =========================================================================
# Function: Verify required packages are installed
# Arguments: None
# Returns: 0 if all required packages installed, 1 if installation failed
# =========================================================================
verify_required_packages() {
  # Check if 'pv' and 'dialog' are installed, and install them if not
  if ! command -v pv &> /dev/null || ! command -v dialog &> /dev/null; then
    echo "Installing required packages: pv and dialog..."
    if ! sudo apt-get update && sudo apt-get install -y pv dialog; then
      echo "Failed to install required packages. Please install 'pv' and 'dialog' manually." >&2
      return 1
    fi
  fi
  
  return 0
}

# =========================================================================
# Function: Setup buildx for ARM64 building
# Arguments: $1 = builder name (default: jetson-builder)
# Returns: 0 if successful, 1 if failed
# =========================================================================
setup_buildx() {
  local builder_name="${1:-jetson-builder}"
  
  # Check if the builder already exists
  if ! docker buildx inspect "$builder_name" &>/dev/null; then
    echo "Creating buildx builder: $builder_name" >&2
    if ! docker buildx create --name "$builder_name" \
      --driver docker-container \
      --driver-opt network=host \
      --driver-opt "image=moby/buildkit:latest" \
      --buildkitd-flags '--allow-insecure-entitlement network.host' \
      --use; then
      echo "Failed to create buildx builder: $builder_name" >&2
      return 1
    fi
  fi
  
  # Make sure we're using the right builder
  docker buildx use "$builder_name"
  
  return 0
}

# =========================================================================
# Function: Build, push, and pull a Docker image from a folder
# Arguments: $1 = folder path, $2 = base image tag (optional), 
#            $3 = platform (default: linux/arm64),
#            $4 = use_cache (default: n),
#            $5 = enable_flattening (default: true)
# Returns: The fixed tag name on success, non-zero exit status on failure
# =========================================================================
build_folder_image() {
  local folder=$1
  local base_tag_arg=$2  # The tag to pass as BASE_IMAGE build-arg
  local platform="${3:-linux/arm64}"
  local use_cache="${4:-n}"
  local enable_flattening="${5:-true}"
  
  local image_name=$(basename "$folder" | tr '[:upper:]' '[:lower:]')  # Lowercase image name
  
  # Check for required variables
  if [ -z "$DOCKER_USERNAME" ]; then
    echo "Error: DOCKER_USERNAME is not set. Cannot build image." >&2
    return 1
  fi
  
  # Generate the image tag
  local fixed_tag=$(echo "${DOCKER_USERNAME}/001:${image_name}" | tr '[:upper:]' '[:lower:]')
  echo "Generating fixed tag: $fixed_tag" >&2
  
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
  echo "Platform: $platform" >&2
  echo "Tag: $fixed_tag" >&2
  echo "--------------------------------------------------" >&2
  
  # Build and push the image
  local cmd_args=("--platform" "$platform" "-t" "$fixed_tag" "${build_args[@]}" --push "$folder")
  if [ "$use_cache" != "y" ]; then
    cmd_args=("--no-cache" "${cmd_args[@]}")
  fi
  
  # Execute the build command
  docker buildx build "${cmd_args[@]}"
  local build_status=$?
  
  # Check if build and push succeeded
  if [ $build_status -ne 0 ]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
    echo "Error: Failed to build and push image for $image_name ($folder)." >&2
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
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
    
    # Check for specific layer depth error
    if [[ "$pull_output" == *"max depth exceeded"* ]]; then
      echo "DETECTED: Layer limit error ('max depth exceeded')" >&2
      echo "This is a Docker limitation on maximum layer depth." >&2
      
      if [ "$enable_flattening" = true ]; then
        echo "Attempting to fix layer limit issue..." >&2
        if fix_layer_limit "$fixed_tag"; then
          echo "Layer limit issue successfully addressed." >&2
        else
          echo "Failed to address layer limit issue." >&2
          return 1
        fi
      else
        echo "Image flattening is disabled. Enable it to automatically fix this issue." >&2
        echo "Full error output:" >&2
        echo "$pull_output" >&2
        return 1
      fi
    else
      # Other pull errors
      echo "Full error output:" >&2
      echo "$pull_output" >&2
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
    return 1
  fi
  
  echo "Image $fixed_tag verified locally." >&2
  
  # Return the tag name (will be captured by the caller)
  echo "$fixed_tag"
  return 0
}
