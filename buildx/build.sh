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

# Validate platform is ARM64 (for Jetson)
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
    echo "This script is only intended to build for aarch64 devices." >&2
    exit 1
fi
PLATFORM="linux/arm64"

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

# Set default base image for the first build
DEFAULT_BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"

# =========================================================================
# Docker buildx setup
# =========================================================================

# Check and initialize buildx builder with NVIDIA container runtime
if ! docker buildx inspect jetson-builder &>/dev/null; then
  echo "Creating buildx builder: jetson-builder with NVIDIA container runtime" >&2
  docker buildx create --name jetson-builder --driver-opt env.DOCKER_DEFAULT_RUNTIME=nvidia --driver-opt env.NVIDIA_VISIBLE_DEVICES=all --use
else
  # Ensure we're using the right builder
  docker buildx use jetson-builder
  echo "Using existing buildx builder: jetson-builder" >&2
fi

# Ask user about build cache usage
read -p "Do you want to build with cache? (y/n): " use_cache
while [[ "$use_cache" != "y" && "$use_cache" != "n" ]]; do
  echo "Invalid input. Please enter 'y' for yes or 'n' for no." >&2
  read -p "Do you want to build with cache? (y/n): " use_cache
done

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
  
  # Use the default base image for the first build if no base tag is provided
  if [ -z "$base_tag_arg" ]; then
      base_tag_arg="$DEFAULT_BASE_IMAGE"
      echo "Using default base image: $DEFAULT_BASE_IMAGE" >&2
  fi
  
  # Add the base image argument
  build_args+=(--build-arg "BASE_IMAGE=$base_tag_arg")
  echo "Using base image build arg: $base_tag_arg" >&2

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
  docker pull "$fixed_tag" >&2  # Redirect stdout to stderr to avoid contaminating the return value
  if [ $? -ne 0 ]; then
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
      echo "Error: Failed to pull the built image $fixed_tag after push." >&2
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
      BUILD_FAILED=1
      return 1
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
        docker pull "$tag" >&2  # Redirect stdout to stderr
        if [ $? -ne 0 ]; then
            echo "Error: Failed to pull image $tag during pre-tagging verification." >&2
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
                docker pull "$TIMESTAMPED_LATEST_TAG" >&2  # Redirect stdout
                if [ $? -eq 0 ]; then
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
                    BUILD_FAILED=1
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
echo "Build, Push, Pull, and Tagging process complete!" >&2
echo "Total images successfully built/pushed/pulled/verified: ${#BUILT_TAGS[@]}" >&2
if [ "$BUILD_FAILED" -ne 0 ]; then
    echo "Warning: One or more steps failed. See logs above." >&2
fi
echo "--------------------------------------------------" >&2

# =========================================================================
# Post-Build Steps - Options for final image
# =========================================================================
echo "(Image pulling and verification now happens during build process)" >&2

# Run the very last successfully built & timestamped image (optional)
if [ -n "$TIMESTAMPED_LATEST_TAG" ] && [ "$BUILD_FAILED" -eq 0 ]; then
    # Check if the timestamped tag is in the BUILT_TAGS array (validation)
    tag_exists=0
    for t in "${BUILT_TAGS[@]}"; do 
        [[ "$t" == "$TIMESTAMPED_LATEST_TAG" ]] && { tag_exists=1; break; }
    done

    if [[ "$tag_exists" -eq 1 ]]; then
        echo "--------------------------------------------------" >&2
        echo "Final Image: $TIMESTAMPED_LATEST_TAG" >&2
        echo "--------------------------------------------------" >&2
        
        if verify_image_exists "$TIMESTAMPED_LATEST_TAG"; then
            # Offer options for what to do with the image
            echo "What would you like to do with the final image?" >&2
            echo "1) Start an interactive shell" >&2
            echo "2) Run quick verification (common tools and packages)" >&2
            echo "3) Run full verification (all system packages, may be verbose)" >&2
            echo "4) List installed apps in the container" >&2
            echo "5) Skip (do nothing)" >&2
            read -p "Enter your choice (1-5): " user_choice
            
            case $user_choice in
                1)
                    echo "Starting interactive shell..." >&2
                    docker run -it --rm "$TIMESTAMPED_LATEST_TAG" bash
                    ;;
                2)
                    verify_container_apps "$TIMESTAMPED_LATEST_TAG" "quick"
                    ;;
                3)
                    verify_container_apps "$TIMESTAMPED_LATEST_TAG" "all"
                    ;;
                4)
                    list_installed_apps "$TIMESTAMPED_LATEST_TAG"
                    ;;
                5)
                    echo "Skipping container run." >&2
                    ;;
                *)
                    echo "Invalid choice. Skipping container run." >&2
                    ;;
            esac
        else
            echo "Error: Final image $TIMESTAMPED_LATEST_TAG not found locally, cannot proceed." >&2
            BUILD_FAILED=1
        fi
    else
        echo "Skipping options because the final tag was not successfully processed." >&2
    fi
else
    echo "No final image tag recorded or build failed, skipping further operations." >&2
fi

# =========================================================================
# Final Image Verification - Check Successfully Processed Images
# =========================================================================
echo "--------------------------------------------------" >&2
# Verify against BUILT_TAGS to see if successfully processed images are present
echo "--- Verifying all SUCCESSFULLY PROCESSED images exist locally ---" >&2
VERIFICATION_FAILED=0
# Use BUILT_TAGS here
if [ ${#BUILT_TAGS[@]} -gt 0 ]; then
    echo "Checking ${#BUILT_TAGS[@]} image(s) recorded as successful:" >&2
    # Use BUILT_TAGS here
    for tag in "${BUILT_TAGS[@]}"; do
        echo -n "Verifying $tag... " >&2
        if docker image inspect "$tag" &>/dev/null; then
            echo "OK" >&2
        else
            echo "MISSING!" >&2
            # This error is more significant now, as this image *should* exist
            echo "Error: Image '$tag', which successfully completed build/push/pull/verify earlier, was not found locally at final check." >&2
            VERIFICATION_FAILED=1
        fi
    done

    if [ "$VERIFICATION_FAILED" -eq 1 ]; then
        echo "Error: One or more successfully processed images were missing locally during final check." >&2
        # Ensure BUILD_FAILED reflects this verification failure
        if [ "$BUILD_FAILED" -eq 0 ]; then
           BUILD_FAILED=1
           echo "(Marking build as failed due to final verification failure)" >&2
        fi
    else
        echo "All successfully processed images verified successfully locally during final check." >&2
    fi
else
    # Message remains relevant if BUILT_TAGS is empty
    echo "No images were recorded as successfully built/pushed/pulled/verified, skipping final verification." >&2
fi

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