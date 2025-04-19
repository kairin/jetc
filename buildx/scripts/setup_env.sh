# COMMIT-TRACKING: UUID-20240730-160000-HRD1
# Description: Remove DEFAULT_BASE_IMAGE and LATEST_SUCCESSFUL_NUMBERED_TAG variables.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── setup_env.sh       <- THIS FILE
# └── ...                        <- Other project files

#!/bin/bash

# =========================================================================
# Function: Load environment variables from .env file
# Returns: 0 if successful, 1 if not
# Sets: DOCKER_USERNAME and other environment variables from .env
# =========================================================================
load_env_variables() {
  # Check multiple locations for the .env file
  ENV_FILE=""
  if [ -f .env ]; then
    ENV_FILE=".env"
    echo "Found .env file in current directory"
  elif [ -f "../.vscode/.env" ]; then
    ENV_FILE="../.vscode/.env"
    echo "Found .env file in ../.vscode directory"
  fi

  if [ -n "$ENV_FILE" ]; then
    set -a  # Automatically export all variables
    . "$ENV_FILE" # Use '.' instead of 'source' for POSIX compatibility
    set +a  # Stop automatically exporting
  else
    echo ".env file not found in current directory or ../.vscode directory!" >&2
    return 1
  fi

  # Verify required environment variables
  if [ -z "$DOCKER_USERNAME" ]; then
    echo "Error: DOCKER_USERNAME is not set. Please define it in the .env file." >&2
    return 1
  fi
  
  return 0
}

# =========================================================================
# Function: Setup build environment
# Returns: 0 if successful, 1 if not
# Sets: CURRENT_DATE_TIME, PLATFORM, ARCH, LOG_DIR
# =========================================================================
setup_build_environment() {
  # Get current date/time for timestamped tags
  CURRENT_DATE_TIME=$(date +"%Y%m%d-%H%M%S")

  # Validate platform is ARM64 (for Jetson)
  ARCH=$(uname -m)
  if [ "$ARCH" != "aarch64" ]; then
      echo "This script is only intended to build for aarch64 devices." >&2
      return 1
  fi
  PLATFORM="linux/arm64"
  
  # Setup build directory for logs
  LOG_DIR="logs"
  mkdir -p "$LOG_DIR"
  
  # Initialize build tracking arrays
  declare -a BUILT_TAGS=() 
  declare -a ATTEMPTED_TAGS=()
  FINAL_FOLDER_TAG=""
  TIMESTAMPED_LATEST_TAG=""
  BUILD_FAILED=0
  
  # Export all variables so they're available to the main script
  export CURRENT_DATE_TIME
  export PLATFORM
  export ARCH
  export LOG_DIR
  export BUILT_TAGS
  export ATTEMPTED_TAGS
  export FINAL_FOLDER_TAG
  export TIMESTAMPED_LATEST_TAG
  export BUILD_FAILED
  
  return 0
}

# =========================================================================
# Function: Get user preferences for build
# Returns: 0 if successful, 1 if not
# Sets: use_cache, use_squash, skip_intermediate_push_pull
# =========================================================================
get_user_preferences() {
  # Ask user about build cache usage
  read -p "Do you want to build with cache? (y/n): " use_cache
  while [[ "$use_cache" != "y" && "$use_cache" != "n" ]]; do
    echo "Invalid input. Please enter 'y' for yes or 'n' for no." >&2
    read -p "Do you want to build with cache? (y/n): " use_cache
  done

  # Ask user about squashing (experimental)
  read -p "Do you want to attempt squashing image layers (experimental)? (y/n): " use_squash
  while [[ "$use_squash" != "y" && "$use_squash" != "n" ]]; do
    echo "Invalid input. Please enter 'y' for yes or 'n' for no." >&2
    read -p "Do you want to attempt squashing image layers (experimental)? (y/n): " use_squash
  done
  if [ "$use_squash" == "y" ]; then
      echo "Warning: Buildx --squash is experimental and may affect caching or build success." >&2
  fi

  # Ask user about skipping intermediate push/pull
  read -p "Skip intermediate push/pull for each stage (requires --load)? (y/n): " skip_intermediate_push_pull
  while [[ "$skip_intermediate_push_pull" != "y" && "$skip_intermediate_push_pull" != "n" ]]; do
    echo "Invalid input. Please enter 'y' for yes or 'n' for no." >&2
    read -p "Skip intermediate push/pull for each stage? (y/n): " skip_intermediate_push_pull
  done
  if [ "$skip_intermediate_push_pull" == "y" ]; then
      echo "Note: Skipping push/pull. Will use '--load' to make images available locally." >&2
  fi

  export use_cache
  export use_squash
  export skip_intermediate_push_pull # Export the new preference
  return 0
}
