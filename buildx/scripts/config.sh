#!/bin/bash

# =========================================================================
# Configuration and Global Variables for Docker Build Process
# =========================================================================

# Arrays and tracking variables
BUILT_TAGS=()        # Tracks successfully built, pushed, pulled and verified images
ATTEMPTED_TAGS=()    # Tracks all tags the script attempts to build
LATEST_SUCCESSFUL_NUMBERED_TAG=""  # Most recent successfully built numbered image
FINAL_FOLDER_TAG=""  # The tag of the last successfully built folder image
TIMESTAMPED_LATEST_TAG=""  # Final timestamped tag name
BUILD_FAILED=0       # Flag to track if any build failed
ENABLE_FLATTENING=true  # Enable image flattening to prevent layer depth issues
PLATFORM="linux/arm64"

# Function to load environment variables and validate prerequisites
load_env_and_validate() {
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

  # Verify network connectivity
  echo "Checking network connectivity..." >&2
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
    echo "Installing required packages: pv and dialog..." >&2
    sudo apt-get update && sudo apt-get install -y pv dialog
  fi

  # Check if auto_flatten_images.sh exists
  if [ ! -f "scripts/auto_flatten_images.sh" ]; then
    echo "Error: scripts/auto_flatten_images.sh script not found. This script is required for layer flattening." >&2
    exit 1
  fi

  # Ensure auto_flatten_images.sh is executable
  chmod +x scripts/auto_flatten_images.sh
}

# Initialize the build environment including buildx setup
init_build_environment() {
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
}
