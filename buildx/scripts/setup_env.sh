# COMMIT-TRACKING: UUID-20240731-145200-DLGX
# Description: Implement dialog-based interface for build options
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
  elif [ -f "$(dirname "$0")/../.env" ]; then
    ENV_FILE="$(dirname "$0")/../.env"
    echo "Found .env file in parent directory"
  fi

  if [ -n "$ENV_FILE" ]; then
    set -a  # Automatically export all variables
    . "$ENV_FILE" # Use '.' instead of 'source' for POSIX compatibility
    set +a  # Stop automatically exporting
  else
    echo -e "\033[0;31mERROR: .env file not found in any standard location!\033[0m" >&2
    echo "Create a .env file with at least: DOCKER_USERNAME=yourname" >&2
    return 1
  fi

  # Verify required environment variables
  if [ -z "$DOCKER_USERNAME" ]; then
    echo -e "\033[0;31mERROR: DOCKER_USERNAME is not set. Please define it in the .env file.\033[0m" >&2
    return 1
  fi
  
  return 0
}

# =========================================================================
# Function: Setup build environment
# Returns: 0 if successful, 1 if not
# Sets: CURRENT_DATE_TIME, PLATFORM, ARCH, LOG_DIR, DEFAULT_BASE_IMAGE
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

  # Set default base image for the first build in the sequence
  DEFAULT_BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu" # Adjust if needed
  
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
  export DEFAULT_BASE_IMAGE # Export the default base image
  
  return 0
}

# =========================================================================
# Function: Check if dialog is installed and install if needed
# Returns: 0 if successful, 1 if not
# =========================================================================
check_install_dialog() {
  if ! command -v dialog &> /dev/null; then
    echo "Dialog package not found. Installing dialog..." >&2
    if command -v apt-get &> /dev/null; then
      sudo apt-get update -y && sudo apt-get install -y dialog
    elif command -v yum &> /dev/null; then
      sudo yum install -y dialog
    else
      echo "Could not install dialog: Unsupported package manager." >&2
      return 1
    fi
  fi
  
  if ! command -v dialog &> /dev/null; then
    echo "Failed to install dialog. Falling back to basic prompts." >&2
    return 1
  fi
  
  return 0
}

# =========================================================================
# Function: Get user preferences for build using dialog
# Returns: 0 if successful, 1 if not
# Sets: use_cache, use_squash, skip_intermediate_push_pull, BASE_IMAGE_ACTION, CUSTOM_BASE_IMAGE
# =========================================================================
get_user_preferences() {
  # Try to use dialog interface
  if ! check_install_dialog; then
    # Fall back to original prompting method if dialog not available
    return get_user_preferences_basic
  fi
  
  # Create temporary file to store results
  temp_file=$(mktemp)
  
  # Define default values (convert to dialog format)
  use_cache_default="off"      # No cache by default
  use_squash_default="off"     # No squash by default
  skip_push_pull_default="on"  # Skip intermediate push/pull by default
  base_image_action="use"      # Default to using current base image
  
  # Main dialog to collect all preferences
  dialog --backtitle "Docker Build Configuration" \
         --title "Build Preferences" \
         --form "\nSet your build preferences:" 0 0 0 \
         "Use existing buildx builder:" 1 1 "yes" 1 30 8 1 \
         "Build with cache:" 2 1 "$use_cache_default" 2 30 8 1 \
         "Squash image layers:" 3 1 "$use_squash_default" 3 30 8 1 \
         "Skip intermediate push/pull:" 4 1 "$skip_push_pull_default" 4 30 8 1 \
         2>$temp_file
  
  # Process results
  if [ $? -ne 0 ]; then
    echo "Dialog canceled. Using default values." >&2
    rm -f $temp_file
    use_cache="n"
    use_squash="n"
    skip_intermediate_push_pull="y"
  else
    # Convert dialog values to y/n format
    dialog_results=$(cat $temp_file)
    use_cache=$(echo "$dialog_results" | sed -n '2p' | tr '[:upper:]' '[:lower:]')
    use_squash=$(echo "$dialog_results" | sed -n '3p' | tr '[:upper:]' '[:lower:]')
    skip_intermediate_push_pull=$(echo "$dialog_results" | sed -n '4p' | tr '[:upper:]' '[:lower:]')
    
    # Convert words to y/n format
    use_cache=$(echo $use_cache | grep -iq "yes\|on\|true" && echo "y" || echo "n")
    use_squash=$(echo $use_squash | grep -iq "yes\|on\|true" && echo "y" || echo "n")
    skip_intermediate_push_pull=$(echo $skip_intermediate_push_pull | grep -iq "yes\|on\|true" && echo "y" || echo "n")
  fi
  
  # Base image selection
  dialog --backtitle "Docker Build Configuration" \
         --title "Base Image Selection" \
         --radiolist "Select base image option:" 15 60 3 \
         "use" "Use current base image: $DEFAULT_BASE_IMAGE" on \
         "pull" "Pull current base image before building" off \
         "change" "Specify a different base image" off \
         2>$temp_file
  
  if [ $? -eq 0 ]; then
    BASE_IMAGE_ACTION=$(cat $temp_file)
    
    if [ "$BASE_IMAGE_ACTION" = "change" ]; then
      # Ask for custom base image
      dialog --backtitle "Docker Build Configuration" \
             --title "Custom Base Image" \
             --inputbox "Enter the full URL/tag of the base image:" 8 60 "$DEFAULT_BASE_IMAGE" \
             2>$temp_file
      
      if [ $? -eq 0 ]; then
        CUSTOM_BASE_IMAGE=$(cat $temp_file)
        # Validate that something was entered
        if [ -z "$CUSTOM_BASE_IMAGE" ]; then
          dialog --msgbox "No base image entered. Using default: $DEFAULT_BASE_IMAGE" 8 60
          CUSTOM_BASE_IMAGE="$DEFAULT_BASE_IMAGE"
          BASE_IMAGE_ACTION="use"
        else
          echo "Using custom base image: $CUSTOM_BASE_IMAGE" >&2
        fi
      else
        CUSTOM_BASE_IMAGE="$DEFAULT_BASE_IMAGE"
        BASE_IMAGE_ACTION="use"
      fi
    fi
    
    # If pull is selected, do the pull now
    if [ "$BASE_IMAGE_ACTION" = "pull" ]; then
      dialog --infobox "Pulling base image: $DEFAULT_BASE_IMAGE..." 3 60
      if ! docker pull "$DEFAULT_BASE_IMAGE"; then
        dialog --msgbox "Failed to pull base image: $DEFAULT_BASE_IMAGE" 8 60
      else
        dialog --msgbox "Successfully pulled base image: $DEFAULT_BASE_IMAGE" 8 60
      fi
      CUSTOM_BASE_IMAGE="$DEFAULT_BASE_IMAGE"
    elif [ "$BASE_IMAGE_ACTION" = "use" ]; then
      CUSTOM_BASE_IMAGE="$DEFAULT_BASE_IMAGE"
    fi
  else
    BASE_IMAGE_ACTION="use"
    CUSTOM_BASE_IMAGE="$DEFAULT_BASE_IMAGE"
  fi
  
  # Clean up temp file
  rm -f $temp_file
  
  # Set the current base image to either the default or the custom one
  CURRENT_BASE_IMAGE="$CUSTOM_BASE_IMAGE"
  
  # Display final configuration
  dialog --backtitle "Docker Build Configuration" \
         --title "Build Configuration Summary" \
         --msgbox "Build will proceed with these settings:
         
  • Use existing buildx builder: yes
  • Build with cache: $use_cache
  • Squash image layers: $use_squash
  • Skip intermediate push/pull: $skip_intermediate_push_pull
  • Base image: $CURRENT_BASE_IMAGE" 15 60
  
  # Export all variables for use in the main script
  export use_cache
  export use_squash
  export skip_intermediate_push_pull
  export BASE_IMAGE_ACTION
  export CUSTOM_BASE_IMAGE
  export CURRENT_BASE_IMAGE
  
  return 0
}

# =========================================================================
# Function: Fallback to basic prompts if dialog is not available
# Returns: 0 if successful, 1 if not
# Sets: use_cache, use_squash, skip_intermediate_push_pull
# =========================================================================
get_user_preferences_basic() {
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
  
  # Ask about base image
  echo "Current base image: $DEFAULT_BASE_IMAGE"
  read -p "Pull this base image before building? (y/n/change): " base_action
  
  case "$base_action" in
    y|Y|yes|YES|Yes)
      echo "Pulling base image: $DEFAULT_BASE_IMAGE"
      if ! docker pull "$DEFAULT_BASE_IMAGE"; then
        echo "Warning: Failed to pull base image. Build may fail if image doesn't exist locally." >&2
      fi
      CURRENT_BASE_IMAGE="$DEFAULT_BASE_IMAGE"
      ;;
      
    c|C|change|CHANGE|Change)
      read -p "Enter full URL/tag of the base image: " custom_image
      if [ -z "$custom_image" ]; then
        echo "No image specified, using default: $DEFAULT_BASE_IMAGE" >&2
        CURRENT_BASE_IMAGE="$DEFAULT_BASE_IMAGE"
      else
        CURRENT_BASE_IMAGE="$custom_image"
        echo "Using custom base image: $CURRENT_BASE_IMAGE" >&2
      fi
      ;;
      
    *)
      echo "Using existing base image (no pull): $DEFAULT_BASE_IMAGE" >&2
      CURRENT_BASE_IMAGE="$DEFAULT_BASE_IMAGE"
      ;;
  esac

  export use_cache
  export use_squash
  export skip_intermediate_push_pull
  export CURRENT_BASE_IMAGE
  return 0
}
