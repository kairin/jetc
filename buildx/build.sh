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

# Source utility scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/config.sh"
source "$SCRIPT_DIR/scripts/utils.sh"
source "$SCRIPT_DIR/scripts/image_builder.sh"
source "$SCRIPT_DIR/scripts/verification.sh"

# Load environment variables and validate prerequisites
load_env_and_validate

# Initialize build environment
init_build_environment

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
verify_all_images

# =========================================================================
# Create Final Timestamped Tag
# =========================================================================
create_final_tag

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