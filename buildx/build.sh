#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

# =========================================================================
# Docker Image Building and Verification Script
# 
# This script automates the process of building, pushing, pulling, and
# verifying Docker images from a series of directories. It handles:
# 1. Building images in numeric order from the build/ directory
# 2. Pushing images to Docker registry
# 3. Pulling images to verify they're accessible
# 4. Creating a final timestamped tag for the last successful build
# 5. Verifying all images are available locally
# 6. Using auto_flatten_images.sh to prevent layer depth issues
# =========================================================================

# Load environment variables from .env file
if [ -f .env ]; then
  set -a  # Automatically export all variables
  source .env
  set +a  # Stop automatically exporting
else
  echo ".env file not found!" >&2
  exit 1
fi

# Verify required environment variables
if [ -z "$DOCKER_USERNAME" ]; then
  echo "Error: DOCKER_USERNAME is not set. Please define it in the .env file." >&2
  exit 1
fi

# Get current date/time for timestamped tags
CURRENT_DATE_TIME=$(date +"%Y%m%d-%H%M%S")

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
  echo "Error: Cannot connect to Docker daemon. Is Docker running?" >&2
  exit 1
fi

# Validate platform is ARM64 (for Jetson)
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
  echo "This script is only intended to build for aarch64 devices." >&2
  exit 1
fi

# Check Docker login status
if ! docker login -u "$DOCKER_USERNAME" >/dev/null 2>&1; then
  echo "Warning: You may not be logged into Docker. Images may fail to push if credentials are required." >&2
  read -p "Continue anyway? (y/n): " continue_without_login
  if [[ "$continue_without_login" != "y" ]]; then
    echo "Aborting. Please run 'docker login' and try again." >&2
    exit 1
  fi
fi

PLATFORM="linux/arm64"

# Verify network connectivity
echo "Checking network connectivity..."
if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1 && ! ping -c 1 -W 5 1.1.1.1 >/dev/null 2>&1; then
  echo "Warning: Network connectivity issues detected. Build process may fail when accessing remote resources." >&2
  read -p "Continue despite network issues? (y/n): " continue_with_network_issues
  if [[ "$continue_with_network_issues" != "y" ]]; then
    echo "Aborting build process." >&2
    exit 1
  fi
fi

# Check if 'pv' and 'dialog' are installed, and install them if not
if ! command -v pv &> /dev/null || ! command -v dialog &> /dev/null; then
  echo "Installing required packages: pv and dialog..."
  sudo apt-get update && sudo apt-get install -y pv dialog
fi

# =========================================================================
# Global Variables
# =========================================================================

# Arrays and tracking variables
BUILT_TAGS=()        # Tracks successfully built, pushed, pulled and verified images
ATTEMPTED_TAGS=()    # Tracks all tags the script attempts to build
LATEST_SUCCESSFUL_NUMBERED_TAG=""  # Most recent successfully built numbered image
FINAL_FOLDER_TAG=""  # The tag of the last successfully built folder image
TIMESTAMPED_LATEST_TAG=""  # Final timestamped tag name
BUILD_FAILED=0       # Flag to track if any build failed
ENABLE_FLATTENING=true  # Enable image flattening to prevent layer depth issues

# Check if auto_flatten_images.sh exists
if [ ! -f "scripts/auto_flatten_images.sh" ]; then
  echo "Error: scripts/auto_flatten_images.sh script not found. This script is required for layer flattening." >&2
  exit 1
fi

# Ensure auto_flatten_images.sh is executable
chmod +x scripts/auto_flatten_images.sh

# =========================================================================
# Docker buildx setup
# =========================================================================

# Check and initialize buildx builder
if ! docker buildx inspect jetson-builder &>/dev/null; then
  echo "Creating buildx builder: jetson-builder" >&2
  docker buildx create --name jetson-builder \
    --driver docker-container \
    --driver-opt network=host --driver-opt "image=moby/buildkit:latest" \
    --buildkitd-flags '--allow-insecure-entitlement network.host' \
    --use
fi
docker buildx use jetson-builder

# Ask user about build cache usage
read -p "Do you want to build with cache? (y/n): " use_cache
while [[ "$use_cache" != "y" && "$use_cache" != "n" ]]; do
  echo "Invalid input. Please enter 'y' for yes or 'n' for no." >&2
  read -p "Do you want to build with cache? (y/n): " use_cache
done

# Ask user about layer flattening
read -p "Do you want to enable image flattening between steps to prevent layer limit issues? (y/n): " use_flattening
while [[ "$use_flattening" != "y" && "$use_flattening" != "n" ]]; do
  echo "Invalid input. Please enter 'y' for yes or 'n' for no." >&2
  read -p "Do you want to enable image flattening between steps? (y/n): " use_flattening
done

if [[ "$use_flattening" == "n" ]]; then
  ENABLE_FLATTENING=false
  echo "Image flattening is disabled." >&2
else
  echo "Image flattening is enabled - this will help prevent 'max depth exceeded' errors." >&2
fi

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

# Add this function to your build.sh file, before the fix_layer_limit function

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
  docker cp scripts/list_installed_apps.sh "$container_id:/tmp/verify_apps.sh"
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
        -v "$(pwd)/scripts/list_installed_apps.sh:/tmp/list_installed_apps.sh" \
        --entrypoint /bin/bash \
        "$image_tag" \
        -c "chmod +x /tmp/list_installed_apps.sh && /tmp/list_installed_apps.sh"
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

# =========================================================================
# Determine Build Order
# =========================================================================
echo "Determining build order..." >&2
BUILD_DIR="build"
mapfile -t numbered_dirs < <(find "$BUILD_DIR" -maxdepth 1 -mindepth 1 -type d -name '[0-9]*-*' | sort)
mapfile -t other_dirs < <(find "$BUILD_DIR" -maxdepth 1 -mindepth 1 -type d ! -name '[0-9]*-*' | sort)

# =========================================================================
# Build Process - Numbered Directories First
# =========================================================================
echo "Starting build process..." >&2

# 1. Build Numbered Directories in Order (sequential dependencies)
echo "--- Building Numbered Directories ---" >&2
if [ ${#numbered_dirs[@]} -eq 0 ]; then
    echo "No numbered directories found in $BUILD_DIR." >&2
else
    for dir in "${numbered_dirs[@]}"; do
      echo "Processing numbered directory: $dir" >&2
      # Pass the LATEST_SUCCESSFUL_NUMBERED_TAG as the base for the next build
      tag=$(build_folder_image "$dir" "$LATEST_SUCCESSFUL_NUMBERED_TAG")
      if [ $? -eq 0 ]; then
          LATEST_SUCCESSFUL_NUMBERED_TAG="$tag"  # Update for the next numbered iteration
          FINAL_FOLDER_TAG="$tag"                # Update the overall last successful folder tag
          echo "Successfully built, pushed, and pulled numbered image: $tag" >&2
      else
          echo "Build, push or pull failed for $dir. Subsequent dependent builds might fail." >&2
          # BUILD_FAILED is already set within build_folder_image
      fi
    done
fi

# 2. Build Other (Non-Numbered) Directories
echo "--- Building Other Directories ---" >&2
if [ ${#other_dirs[@]} -eq 0 ]; then
    echo "No non-numbered directories found in $BUILD_DIR." >&2
elif [ "$BUILD_FAILED" -ne 0 ]; then
    echo "Skipping other directories due to previous build failures." >&2
else
    # Use the tag from the LAST successfully built numbered image as the base for ALL others
    BASE_FOR_OTHERS="$LATEST_SUCCESSFUL_NUMBERED_TAG"
    echo "Using base image for others: $BASE_FOR_OTHERS" >&2

    for dir in "${other_dirs[@]}"; do
      echo "Processing other directory: $dir" >&2
      tag=$(build_folder_image "$dir" "$BASE_FOR_OTHERS")
      if [ $? -eq 0 ]; then
          FINAL_FOLDER_TAG="$tag"  # Update the overall last successful folder tag
          echo "Successfully built, pushed, and pulled other image: $tag" >&2
      else
          echo "Build, push or pull failed for $dir." >&2
          # BUILD_FAILED is already set within build_folder_image
      fi
    done
fi

echo "--------------------------------------------------" >&2
echo "Folder build process complete!" >&2

# =========================================================================
# Pre-Tagging Verification - Pull all attempted images to ensure they exist
# =========================================================================
echo "--- Verifying and Pulling All Attempted Images ---" >&2
if [ "$BUILD_FAILED" -eq 0 ] && [ ${#ATTEMPTED_TAGS[@]} -gt 0 ]; then
    echo "Pulling ${#ATTEMPTED_TAGS[@]} image(s) before final tagging..." >&2
    
    PULL_ALL_FAILED=0
    
    for tag in "${ATTEMPTED_TAGS[@]}"; do
        echo "Pulling $tag..." >&2
        pull_output=$(docker pull "$tag" 2>&1)
        pull_status=$?
        
        if [ $pull_status -ne 0 ]; then
            echo "Error: Failed to pull image $tag during pre-tagging verification." >&2
            
            # Check for layer limit error
            if [[ "$pull_output" == *"max depth exceeded"* ]] && [ "$ENABLE_FLATTENING" = true ]; then
                echo "DETECTED: Layer limit error when pulling $tag" >&2
                
                if fix_layer_limit "$tag"; then
                    echo "Successfully fixed layer limit issue for $tag" >&2
                    continue  # Skip marking as failed
                fi
            fi
            
            PULL_ALL_FAILED=1
        fi
    done
    
    if [ "$PULL_ALL_FAILED" -eq 1 ]; then
        echo "Error: Failed to pull one or more required images before final tagging. Aborting." >&2
        BUILD_FAILED=1
    else
        echo "All attempted images successfully pulled/refreshed." >&2
    fi
else
    if [ "$BUILD_FAILED" -ne 0 ]; then
        echo "Skipping pre-tagging pull verification due to earlier build failures." >&2
    else
        echo "No images were attempted, skipping pre-tagging pull verification." >&2
    fi
fi

echo "--------------------------------------------------" >&2

# =========================================================================
# Create Final Timestamped Tag
# =========================================================================
echo "--- Creating Final Timestamped Tag ---" >&2
if [ -n "$FINAL_FOLDER_TAG" ] && [ "$BUILD_FAILED" -eq 0 ]; then
    TIMESTAMPED_LATEST_TAG=$(echo "${DOCKER_USERNAME}/001:latest-${CURRENT_DATE_TIME}-1" | tr '[:upper:]' '[:lower:]')
    echo "Attempting to tag $FINAL_FOLDER_TAG as $TIMESTAMPED_LATEST_TAG" >&2

    # Verify base image exists locally before tagging
    echo "Verifying image $FINAL_FOLDER_TAG exists locally before tagging..." >&2
    if verify_image_exists "$FINAL_FOLDER_TAG"; then
        echo "Image $FINAL_FOLDER_TAG found locally. Proceeding with tag." >&2
        
        # Tag, push, and pull the final timestamped image
        if docker tag "$FINAL_FOLDER_TAG" "$TIMESTAMPED_LATEST_TAG"; then
            echo "Pushing $TIMESTAMPED_LATEST_TAG" >&2
            if docker push "$TIMESTAMPED_LATEST_TAG"; then
                echo "Pulling final timestamped tag: $TIMESTAMPED_LATEST_TAG" >&2
                pull_output=$(docker pull "$TIMESTAMPED_LATEST_TAG" 2>&1)
                pull_status=$?
                
                if [ $pull_status -eq 0 ]; then
                    # Verify final image exists locally
                    echo "Verifying final image $TIMESTAMPED_LATEST_TAG exists locally after pull..." >&2
                    if verify_image_exists "$TIMESTAMPED_LATEST_TAG"; then
                        echo "Final image $TIMESTAMPED_LATEST_TAG verified locally." >&2
                        BUILT_TAGS+=("$TIMESTAMPED_LATEST_TAG")
                        echo "Successfully created, pushed, and pulled final timestamped tag." >&2
                    else
                        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
                        echo "Error: Final image $TIMESTAMPED_LATEST_TAG NOT found locally after 'docker pull' succeeded." >&2
                        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
                        BUILD_FAILED=1
                    fi
                else
                    echo "Error: Failed to pull final timestamped tag $TIMESTAMPED_LATEST_TAG after push." >&2
                    
                    # Check for layer limit error
                    if [[ "$pull_output" == *"max depth exceeded"* ]] && [ "$ENABLE_FLATTENING" = true ]; then
                        echo "DETECTED: Layer limit error when pulling final timestamped tag" >&2
                        
                        if fix_layer_limit "$TIMESTAMPED_LATEST_TAG"; then
                            # Verify again after fixing
                            if verify_image_exists "$TIMESTAMPED_LATEST_TAG"; then
                                echo "Successfully pulled flattened final image." >&2
                                BUILT_TAGS+=("$TIMESTAMPED_LATEST_TAG")
                                echo "Successfully created, pushed, and pulled final timestamped tag (after flattening)." >&2
                            else
                                BUILD_FAILED=1
                            fi
                        else
                            BUILD_FAILED=1
                        fi
                    else
                        BUILD_FAILED=1
                    fi
                fi
            else
                echo "Error: Failed to push final timestamped tag $TIMESTAMPED_LATEST_TAG." >&2
                BUILD_FAILED=1
            fi
        else
            echo "Error: Failed to tag $FINAL_FOLDER_TAG as $TIMESTAMPED_LATEST_TAG." >&2
            BUILD_FAILED=1
        fi
    else
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
        echo "Error: Image $FINAL_FOLDER_TAG not found locally right before tagging, despite pre-tagging pull attempt." >&2
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
        BUILD_FAILED=1
    fi
else
    if [ "$BUILD_FAILED" -ne 0 ]; then
        echo "Skipping final timestamped tag creation due to previous errors." >&2
    else
        echo "Skipping final timestamped tag creation as no base image was successfully built/pushed/pulled." >&2
    fi
fi

echo "--------------------------------------------------" >&2

# =========================================================================
# Script Completion
# =========================================================================
echo "--------------------------------------------------" >&2
if [ "$BUILD_FAILED" -ne 0 ]; then
    echo "Script finished with one or more errors." >&2
    echo "--------------------------------------------------" >&2
    exit 1  # Exit with failure code
else
    echo "Build, push, pull, tag, verification, and run processes completed successfully!" >&2
    echo "--------------------------------------------------" >&2
    exit 0  # Exit with success code
fi
EOF