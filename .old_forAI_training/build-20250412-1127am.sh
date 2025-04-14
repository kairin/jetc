#!/bin/bash

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

# Array to store the tags of built images
BUILT_TAGS=()
# Variable to store the tag of the last built image
LAST_BUILT_TAG=""

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
build_image() {
  local folder=$1
  # Base image argument removed as it's not used and builds are independent now
  local image_name=$(basename "$folder" | tr '[:upper:]' '[:lower:]') # Ensure image_name is lowercase
  local tag=$(echo "${DOCKER_USERNAME}/001:${image_name}-${CURRENT_DATE_TIME}-1" | tr '[:upper:]' '[:lower:]') # Ensure tag is lowercase

  # Check if Dockerfile exists
  if [ ! -f "$folder/Dockerfile" ]; then
    echo "Warning: Dockerfile not found in $folder. Skipping." >&2
    return 1 # Indicate failure/skip
  fi

  # Print informational messages to stderr
  echo "--------------------------------------------------" >&2
  echo "Building image: $image_name for platform: $PLATFORM" >&2
  echo "Building folder: $folder" >&2
  echo "Dockerfile path: $folder/Dockerfile" >&2
  echo "Tag: $tag" >&2
  echo "--------------------------------------------------" >&2


  # Build the image
  if [ "$use_cache" = "y" ]; then
    docker buildx build --platform $PLATFORM -t $tag --push "$folder"
  else
    docker buildx build --no-cache --platform $PLATFORM -t $tag --push "$folder"
  fi

  # Check if the build succeeded
  if [ $? -ne 0 ]; then
    echo "Error: Failed to build image for $image_name ($folder). Exiting..." >&2
    exit 1
  fi

  # Add the tag to our array
  BUILT_TAGS+=("$tag")

  # Output the tag to stdout
  echo "$tag"
  return 0 # Indicate success
}

# --- Build Process ---
echo "Starting build process..." >&2

# Define the build directory
BUILD_DIR="build"

# 1. Build build-essential first if it exists
BUILD_ESSENTIAL_DIR="$BUILD_DIR/build-essential"
if [ -d "$BUILD_ESSENTIAL_DIR" ]; then
  echo "Building essential base image first..." >&2
  tag=$(build_image "$BUILD_ESSENTIAL_DIR")
  if [ $? -eq 0 ]; then
    LAST_BUILT_TAG="$tag"
    echo "Built essential base image: $LAST_BUILT_TAG" >&2
  else
    echo "Failed to build essential base image. Check logs." >&2
    # Decide if you want to exit here or continue
    # exit 1
  fi
else
 echo "Warning: $BUILD_ESSENTIAL_DIR not found, skipping explicit build." >&2
fi


# 2. Build all other images in the build directory
echo "Building remaining images in $BUILD_DIR/ ..." >&2
for dir in "$BUILD_DIR"/*; do
  # Check if it's a directory and not the one we already built
  if [ -d "$dir" ] && [ "$dir" != "$BUILD_ESSENTIAL_DIR" ]; then
    tag=$(build_image "$dir")
     if [ $? -eq 0 ]; then
        # Update LAST_BUILT_TAG only if build_image succeeded
        LAST_BUILT_TAG="$tag"
        echo "Successfully built image from $dir with tag: $LAST_BUILT_TAG" >&2
     fi
     # If build_image failed, it already printed an error and exited or returned 1
     # If it returned 1 (e.g., no Dockerfile), we just continue the loop.
  fi
done

echo "--------------------------------------------------" >&2
echo "Build process complete!" >&2
echo "Total images built: ${#BUILT_TAGS[@]}" >&2
echo "--------------------------------------------------" >&2


# --- Post-Build Steps ---

# Pull all the images that were just built and pushed
if [ ${#BUILT_TAGS[@]} -gt 0 ]; then
  echo "Pulling all built images..." >&2
  for tag in "${BUILT_TAGS[@]}"; do
    echo "Pulling image: $tag" >&2
    docker pull "$tag"
    if [ $? -ne 0 ]; then
      echo "Error: Failed to pull the image $tag. Exiting..." >&2
      exit 1
    fi
  done
  echo "All built images pulled successfully." >&2
else
  echo "No images were successfully built, skipping pull step." >&2
fi

# Run the last successfully built image (optional, based on original script logic)
if [ -n "$LAST_BUILT_TAG" ]; then # Check if LAST_BUILT_TAG is not empty
    echo "--------------------------------------------------" >&2
    echo "Attempting to run the final image built: $LAST_BUILT_TAG" >&2
    echo "--------------------------------------------------" >&2
    docker run -it --rm "$LAST_BUILT_TAG" bash
    if [ $? -ne 0 ]; then
      echo "Error: Failed to run the image $LAST_BUILT_TAG. Exiting..." >&2
      exit 1
    fi
else
    echo "No final image tag found to run (either no images built or last build failed before tagging)." >&2
fi


# Announce completion
echo "--------------------------------------------------" >&2
echo "Build, push, pull, and run processes completed successfully!" >&2
echo "--------------------------------------------------" >&2
