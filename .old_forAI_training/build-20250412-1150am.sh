#!/bin/bash

# =========================================================================
# IMPORTANT: This build system requires Docker with buildx extension.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

# Load environment variables from the .env file
if [ -f .env ]; then
  set -a
  source .env
  set +a
else
  echo ".env file not found!" >&2
  exit 1
fi

# Ensure DOCKER_USERNAME is set
if [ -z "$DOCKER_USERNAME" ]; then
  echo "Error: DOCKER_USERNAME is not set. Please define it in the .env file." >&2
  exit 1
fi

# Get the current date and time formatted as YYYYMMDD-HHMMSS
CURRENT_DATE_TIME=$(date +"%Y%m%d-%H%M%S")

# Determine the current platform
ARCH=$(uname -m)

if [ "$ARCH" != "aarch64" ]; then
    echo "This script is only intended to build for aarch64 devices." >&2
    exit 1
fi

PLATFORM="linux/arm64"

# Array to store the tags of successfully built images
BUILT_TAGS=()
# Variable to store the tag of the most recently successfully built image (for chaining)
LATEST_SUCCESSFUL_TAG=""
# Variable to store the tag of the very last successfully built image (for run command)
FINAL_BUILT_TAG=""
# Flag to track if any build failed
BUILD_FAILED=0

# Check if the builder already exists
if ! docker buildx inspect jetson-builder &>/dev/null; then
  # Create the builder instance if it doesn't exist
  echo "Creating buildx builder: jetson-builder" >&2
  docker buildx create --name jetson-builder
fi

# Use the builder instance
docker buildx use jetson-builder

# Ask if the user wants to build with or without cache
read -p "Do you want to build with cache? (y/n): " use_cache
while [[ "$use_cache" != "y" && "$use_cache" != "n" ]]; do
  echo "Invalid input. Please enter 'y' for yes or 'n' for no." >&2
  read -p "Do you want to build with cache? (y/n): " use_cache
done

# Function to build a Docker image
# Arguments: $1 = folder path, $2 = base image tag (optional, for --build-arg)
build_image() {
  local folder=$1
  local base_tag_arg=$2 # The tag to pass as BASE_IMAGE build-arg
  local image_name=$(basename "$folder" | tr '[:upper:]' '[:lower:]') # Ensure image_name is lowercase
  # Use a consistent tag format based only on the folder name and timestamp
  local tag=$(echo "${DOCKER_USERNAME}/001:${image_name}-${CURRENT_DATE_TIME}-1" | tr '[:upper:]' '[:lower:]')

  # Check if Dockerfile exists
  if [ ! -f "$folder/Dockerfile" ]; then
    echo "Warning: Dockerfile not found in $folder. Skipping." >&2
    return 1 # Indicate skip/failure
  fi

  # Construct build arguments
  local build_args=()
  if [ -n "$base_tag_arg" ]; then
      build_args+=(--build-arg "BASE_IMAGE=$base_tag_arg")
      echo "Using base image build arg: $base_tag_arg" >&2
  else
      echo "No base image build arg provided (likely the first image)." >&2
  fi

  # Print informational messages to stderr
  echo "--------------------------------------------------" >&2
  echo "Building image from folder: $folder" >&2
  echo "Image Name (derived): $image_name" >&2
  echo "Platform: $PLATFORM" >&2
  echo "Tag: $tag" >&2
  echo "--------------------------------------------------" >&2

  # Build the image
  local cmd_args=("--platform" "$PLATFORM" "-t" "$tag" "${build_args[@]}" --push "$folder")
  if [ "$use_cache" != "y" ]; then
      cmd_args=("--no-cache" "${cmd_args[@]}")
  fi

  docker buildx build "${cmd_args[@]}"

  # Check if the build succeeded
  if [ $? -ne 0 ]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
    echo "Error: Failed to build image for $image_name ($folder)." >&2
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
    BUILD_FAILED=1 # Set the global failure flag
    return 1 # Indicate failure
  fi

  # Add the tag to our array ONLY if successful
  BUILT_TAGS+=("$tag")

  # Output the tag to stdout (useful for chaining or getting the last tag)
  echo "$tag"
  return 0 # Indicate success
}

# --- Build Process ---
echo "Starting build process..." >&2
BUILD_DIR="build"

# Find and sort directories
# Use find + sort for reliable listing and ordering
# Use process substitution <(...) to feed the loops
mapfile -t numbered_dirs < <(find "$BUILD_DIR" -maxdepth 1 -mindepth 1 -type d -name '[0-9]*-*' | sort)
mapfile -t other_dirs < <(find "$BUILD_DIR" -maxdepth 1 -mindepth 1 -type d ! -name '[0-9]*-*' | sort)

# 1. Build Numbered Directories in Order
echo "--- Building Numbered Directories ---" >&2
if [ ${#numbered_dirs[@]} -eq 0 ]; then
    echo "No numbered directories found in $BUILD_DIR." >&2
else
    for dir in "${numbered_dirs[@]}"; do
      echo "Processing numbered directory: $dir" >&2
      # Pass the LATEST_SUCCESSFUL_TAG as the base for the *next* build
      tag=$(build_image "$dir" "$LATEST_SUCCESSFUL_TAG")
      if [ $? -eq 0 ]; then
          LATEST_SUCCESSFUL_TAG="$tag" # Update for the next iteration
          FINAL_BUILT_TAG="$tag"      # Update the overall last successful tag
          echo "Successfully built numbered image: $LATEST_SUCCESSFUL_TAG" >&2
      else
          echo "Build failed for $dir. Subsequent dependent builds might fail." >&2
          # Continue processing other directories
      fi
    done
fi

# LATEST_SUCCESSFUL_TAG now holds the tag of the last successfully built numbered image (or is empty)

# 2. Build Other Directories
echo "--- Building Other Directories ---" >&2
if [ ${#other_dirs[@]} -eq 0 ]; then
    echo "No non-numbered directories found in $BUILD_DIR." >&2
else
    # Use the tag from the LAST successfully built numbered image as the base for ALL others
    BASE_FOR_OTHERS="$LATEST_SUCCESSFUL_TAG"
    echo "Using base image for others: $BASE_FOR_OTHERS" >&2

    for dir in "${other_dirs[@]}"; do
      echo "Processing other directory: $dir" >&2
      tag=$(build_image "$dir" "$BASE_FOR_OTHERS")
      if [ $? -eq 0 ]; then
          # Don't update LATEST_SUCCESSFUL_TAG here unless you want these to chain off each other
          FINAL_BUILT_TAG="$tag" # Update the overall last successful tag
          echo "Successfully built other image: $tag" >&2
      else
          echo "Build failed for $dir." >&2
           # Continue processing other directories
      fi
    done
fi

echo "--------------------------------------------------" >&2
echo "Build process complete!" >&2
echo "Total images successfully built: ${#BUILT_TAGS[@]}" >&2
if [ "$BUILD_FAILED" -ne 0 ]; then
    echo "Warning: One or more builds failed. See logs above." >&2
fi
echo "--------------------------------------------------" >&2


# --- Post-Build Steps ---

# Pull all the images that were successfully built and pushed
if [ ${#BUILT_TAGS[@]} -gt 0 ]; then
  echo "Pulling all successfully built images..." >&2
  PULL_FAILED=0
  for tag in "${BUILT_TAGS[@]}"; do
    echo "Pulling image: $tag" >&2
    docker pull "$tag"
    if [ $? -ne 0 ]; then
      echo "Error: Failed to pull the image $tag." >&2
      PULL_FAILED=1
    fi
  done
  if [ "$PULL_FAILED" -eq 0 ]; then
      echo "All successfully built images pulled." >&2
  else
      echo "Warning: Failed to pull one or more built images." >&2
  fi
else
  echo "No images were successfully built, skipping pull step." >&2
fi

# Run the very last successfully built image (optional)
if [ -n "$FINAL_BUILT_TAG" ]; then
    echo "--------------------------------------------------" >&2
    echo "Attempting to run the final image successfully built: $FINAL_BUILT_TAG" >&2
    echo "--------------------------------------------------" >&2
    docker run -it --rm "$FINAL_BUILT_TAG" bash
    # Check run status if needed
    if [ $? -ne 0 ]; then
      echo "Error: Failed to run the image $FINAL_BUILT_TAG." >&2
      # Decide if this should cause the script to exit with failure
      # exit 1
    fi
else
    echo "No final image tag recorded as successfully built, skipping run step." >&2
fi


# Announce completion and final status
echo "--------------------------------------------------" >&2
if [ "$BUILD_FAILED" -ne 0 ]; then
    echo "Script finished with one or more build errors." >&2
    echo "--------------------------------------------------" >&2
    exit 1 # Exit with failure code if any build failed
else
    echo "Build, push, pull, and (optionally) run processes completed successfully!" >&2
    echo "--------------------------------------------------" >&2
    exit 0 # Exit with success code
fi
