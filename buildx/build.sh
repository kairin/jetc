#!/bin/bash

# =========================================================================
# IMPORTANT: This build system requires Docker with buildx extension.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================
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
#
# IMPORTANT: This build system requires Docker with buildx extension.
# All future builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

# Source utility scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/config.sh"
source "$SCRIPT_DIR/scripts/utils.sh"
source "$SCRIPT_DIR/scripts/image_builder.sh"
source "$SCRIPT_DIR/scripts/verification.sh"

# Function to check if Docker is logged in
is_docker_logged_in() {
    if docker info | grep -q 'Username:'; then
        return 0
    else
        return 1
    fi
}

# Function to login to Azure Container Registry or DockerHub
docker_registry_login() {
    # First check if already logged in
    if is_docker_logged_in; then
        echo "Already logged into Docker registry" >&2
        return 0
    fi

    # Check if we have ACR credentials
    if [ -n "$ACR_NAME" ] && [ -n "$ACR_USERNAME" ] && [ -n "$ACR_PASSWORD" ]; then
        echo "Logging in to Azure Container Registry: $ACR_NAME" >&2
        echo "$ACR_PASSWORD" | docker login "$ACR_NAME.azurecr.io" --username "$ACR_USERNAME" --password-stdin
        if [ $? -eq 0 ]; then
            echo "Successfully logged in to ACR" >&2
            return 0
        else
            echo "Failed to log in to ACR. Please check credentials." >&2
            return 1
        fi
    elif [ -n "$ACR_NAME" ] && [ -z "$ACR_USERNAME" ] && [ -z "$ACR_PASSWORD" ]; then
        # Try using Azure CLI
        if command -v az >/dev/null 2>&1; then
            echo "Logging in to ACR using Azure CLI" >&2
            az acr login --name "$ACR_NAME"
            if [ $? -eq 0 ]; then
                echo "Successfully logged in to ACR using Azure CLI" >&2
                return 0
            else
                echo "Failed to log in to ACR using Azure CLI" >&2
                return 1
            fi
        else
            echo "Azure CLI not found. Cannot login to ACR." >&2
            return 1
        fi
    elif [ -n "$DOCKER_USERNAME" ] && [ -n "$DOCKER_PASSWORD" ]; then
        # Use DockerHub credentials
        echo "Logging in to DockerHub" >&2
        echo "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USERNAME" --password-stdin
        if [ $? -eq 0 ]; then
            echo "Successfully logged in to DockerHub" >&2
            return 0
        else
            echo "Failed to log in to DockerHub. Please check credentials." >&2
            return 1
        fi
    else
        echo "No Docker registry credentials found. Proceeding without authentication." >&2
        echo "Note: You may encounter push failures if authentication is required." >&2
    fi
    
    return 0
}

# Load environment variables and validate prerequisites
load_env_and_validate

# Login to Docker registry if needed
docker_registry_login

# Function to setup Docker buildx builder
setup_buildx_builder() {
    echo "Setting up Docker buildx builder..." >&2
    
    # IMPORTANT NOTE: Docker buildx is REQUIRED for all builds.
    # Future modifications to this script must continue using buildx.
    
    # Check if buildx is installed
    if ! docker buildx version > /dev/null 2>&1; then
        echo "Error: Docker buildx is not available. Please install Docker buildx plugin." >&2
        echo "All builds MUST use Docker buildx - this is a mandatory requirement." >&2
        return 1
    fi
    
    # Check if our builder already exists and remove it if so
    if docker buildx inspect jetson-builder > /dev/null 2>&1; then
        echo "Removing existing buildx builder: jetson-builder" >&2
        docker buildx rm jetson-builder
    fi
    
    # Check for nvidia-container-runtime availability
    NVIDIA_RUNTIME_AVAILABLE=0
    if command -v nvidia-container-runtime >/dev/null 2>&1; then
        NVIDIA_RUNTIME_AVAILABLE=1
    fi
    
    # Ask user if they want to use GPU for building
    read -p "Do you want to enable GPU for building? (y/n, default: n): " USE_GPU
    USE_GPU=${USE_GPU:-n}
    
    echo "Creating new buildx builder: jetson-builder" >&2
    if [[ "$USE_GPU" =~ ^[Yy]$ ]]; then
        if [ $NVIDIA_RUNTIME_AVAILABLE -eq 1 ]; then
            echo "Attempting to create builder with GPU support..." >&2
            # Create with GPU support - use correct options
            if ! docker buildx create --name jetson-builder --driver-opt network=host --platform=linux/amd64,linux/arm64 --use; then
                echo "Failed to create builder with GPU support. Falling back to default builder." >&2
                docker buildx create --name jetson-builder --platform=linux/amd64,linux/arm64 --use
            fi
        else
            echo "Warning: nvidia-container-runtime not found. Cannot enable GPU support." >&2
            echo "Creating builder without GPU support..." >&2
            docker buildx create --name jetson-builder --driver docker --driver-opt image=moby/buildkit:buildx-stable-1 --platform=linux/amd64,linux/arm64 --use
        fi
    else
        echo "Creating builder without GPU support..." >&2
        docker buildx create --name jetson-builder --driver docker --driver-opt image=moby/buildkit:buildx-stable-1 --platform=linux/amd64,linux/arm64 --use
    fi
    
    # Check builder status with a timeout to avoid hanging
    echo "Verifying builder status..." >&2
    if ! timeout 30s docker buildx inspect --bootstrap; then
        echo "Error: Failed to bootstrap buildx builder. Creating a new basic one..." >&2
        docker buildx rm jetson-builder 2>/dev/null || true
        # Create a completely basic builder as last resort
        if ! docker buildx create --name jetson-builder --driver docker --driver-opt image=moby/buildkit:buildx-stable-1 --use; then
            echo "Error: Still unable to create a working buildx builder. Exiting." >&2
            return 1
        fi
        
        if ! timeout 30s docker buildx inspect --bootstrap; then
            echo "Error: Cannot bootstrap any buildx builder. Docker buildx may not be properly configured." >&2
            return 1
        fi
    fi
    
    echo "Buildx builder ready." >&2
    return 0
}

# Initialize build environment
echo "Initializing build environment..." >&2
setup_buildx_builder || { echo "Failed to setup buildx builder. Exiting."; exit 1; }
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