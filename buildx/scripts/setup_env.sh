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
# Sets: use_cache, use_squash, skip_intermediate_push_pull, BASE_IMAGE_ACTION, CUSTOM_BASE_IMAGE, CURRENT_BASE_IMAGE
# =========================================================================
get_user_preferences() {
  # Try to use dialog interface
  if ! check_install_dialog; then
    # Fall back to original prompting method if dialog not available
    return get_user_preferences_basic
  fi

  # Create temporary file to store results
  temp_file=$(mktemp)
  temp_file2=$(mktemp) # Second temp file for menu

  # Define default states for checklist
  local cache_default="off" # off = No = Use --no-cache
  local squash_default="off" # off = No = Don't use --squash
  local skip_push_pull_default="on" # on = Yes = Use --load

  # Use --checklist for boolean options - Clarified descriptions
  dialog --backtitle "Docker Build Configuration" \
         --title "Build Preferences (Check=Yes, Uncheck=No)" \
         --checklist "\nSelect build options (use Spacebar to toggle):" 18 85 4 \
         "cache" "Use Build Cache (Yes=Use cache, No=--no-cache)" "$cache_default" \
         "squash" "Squash Layers (Yes=--squash, No=No squash)" "$squash_default" \
         "skip_push_pull" "Skip Push/Pull (Yes=--load, No=--push)" "$skip_push_pull_default" \
         "use_builder" "Use 'jetson-builder' (Recommended: Yes)" "on" \
         2>$temp_file

  checklist_exit_status=$?
  selected_options=$(cat $temp_file)

  # Process checklist results
  if [ $checklist_exit_status -ne 0 ]; then
    echo "Dialog canceled. Using default values for build options." >&2
    use_cache="n"
    use_squash="n"
    skip_intermediate_push_pull="y"
  else
    [[ "$selected_options" == *'"cache"'* ]] && use_cache="y" || use_cache="n"
    [[ "$selected_options" == *'"squash"'* ]] && use_squash="y" || use_squash="n"
    [[ "$selected_options" == *'"skip_push_pull"'* ]] && skip_intermediate_push_pull="y" || skip_intermediate_push_pull="n"
    # 'use_builder' is assumed yes if dialog is used
  fi

  # Base image selection using --menu - Renamed options for clarity
  dialog --backtitle "Docker Build Configuration" \
         --title "Base Image Selection" \
         --menu "Select base image action:" 18 85 3 \
         "use_default" "Use Default (No Pull): $DEFAULT_BASE_IMAGE" \
         "pull_default" "Pull Default: $DEFAULT_BASE_IMAGE" \
         "specify_custom" "Specify Custom Image (Will Pull)" \
         2>$temp_file2 # Use the second temp file

  menu_exit_status=$?
  BASE_IMAGE_ACTION=$(cat $temp_file2)

  # Process menu results
  if [ $menu_exit_status -eq 0 ]; then
    case "$BASE_IMAGE_ACTION" in
      "specify_custom")
        # Ask for custom base image
        dialog --backtitle "Docker Build Configuration" \
               --title "Custom Base Image" \
               --inputbox "Enter the full URL/tag of the base image to use and pull:" 10 85 "$DEFAULT_BASE_IMAGE" \
               2>$temp_file # Reuse first temp file

        if [ $? -eq 0 ]; then
          CUSTOM_BASE_IMAGE=$(cat $temp_file)
          if [ -z "$CUSTOM_BASE_IMAGE" ]; then
            dialog --msgbox "No base image entered. Reverting to default:\n$DEFAULT_BASE_IMAGE" 8 60
            CUSTOM_BASE_IMAGE="$DEFAULT_BASE_IMAGE"
            BASE_IMAGE_ACTION="use_default" # Revert action
          else
            echo "Attempting to use custom base image: $CUSTOM_BASE_IMAGE" >&2
            # Attempt to pull the custom image immediately
            dialog --infobox "Pulling custom base image:\n$CUSTOM_BASE_IMAGE..." 5 70
            sleep 1
            if ! docker pull "$CUSTOM_BASE_IMAGE"; then
              dialog --msgbox "Failed to pull custom base image:\n$CUSTOM_BASE_IMAGE.\nPlease check the tag/URL. Reverting to default." 10 70
              CUSTOM_BASE_IMAGE="$DEFAULT_BASE_IMAGE"
              BASE_IMAGE_ACTION="use_default" # Revert on pull failure
            else
              dialog --msgbox "Successfully pulled custom base image:\n$CUSTOM_BASE_IMAGE" 8 70
              # Keep BASE_IMAGE_ACTION as specify_custom, image is set
            fi
          fi
        else
          dialog --msgbox "Input canceled. Reverting to default:\n$DEFAULT_BASE_IMAGE" 8 60
          CUSTOM_BASE_IMAGE="$DEFAULT_BASE_IMAGE"
          BASE_IMAGE_ACTION="use_default" # Revert action
        fi
        ;;
      "pull_default")
        # Pull the default base image
        dialog --infobox "Pulling default base image:\n$DEFAULT_BASE_IMAGE..." 5 70
        sleep 1
        if ! docker pull "$DEFAULT_BASE_IMAGE"; then
          dialog --msgbox "Failed to pull default base image:\n$DEFAULT_BASE_IMAGE.\nBuild might fail if not available locally." 8 70
        else
          dialog --msgbox "Successfully pulled default base image:\n$DEFAULT_BASE_IMAGE" 8 70
        fi
        CUSTOM_BASE_IMAGE="$DEFAULT_BASE_IMAGE" # Set image to default after pull attempt
        ;;
      "use_default")
        # Use the default base image without pulling
        CUSTOM_BASE_IMAGE="$DEFAULT_BASE_IMAGE"
        ;;
    esac
  else
    # User pressed Cancel or Esc on the menu
    dialog --msgbox "Base image selection canceled. Using default:\n$DEFAULT_BASE_IMAGE" 8 70
    BASE_IMAGE_ACTION="use_default"
    CUSTOM_BASE_IMAGE="$DEFAULT_BASE_IMAGE"
  fi

  # Clean up temp files
  rm -f $temp_file $temp_file2

  # Set the final CURRENT_BASE_IMAGE to be used by the build script
  CURRENT_BASE_IMAGE="$CUSTOM_BASE_IMAGE"

  # Format the confirmation message
  local confirmation_message
  confirmation_message="Build will proceed with these settings:\n\n"
  confirmation_message+="  Build Options:\n"
  confirmation_message+="    - Use Build Cache (Yes/No): $use_cache\n"
  confirmation_message+="    - Squash Layers (Yes/No):   $use_squash\n"
  confirmation_message+="    - Skip Push/Pull (Yes=Load/No=Push): $skip_intermediate_push_pull\n\n"
  confirmation_message+="  Base Image:\n"
  confirmation_message+="    - Action Selected: $BASE_IMAGE_ACTION\n"
  confirmation_message+="    - Image To Be Used: $CURRENT_BASE_IMAGE"

  dialog --backtitle "Docker Build Configuration" \
         --title "Build Configuration Summary" \
         --msgbox "$confirmation_message" 18 85

  # Export all variables for use in the main script
  export use_cache
  export use_squash
  export skip_intermediate_push_pull
  export BASE_IMAGE_ACTION # Reflects user's menu choice
  export CUSTOM_BASE_IMAGE # Holds the custom image if specified
  export CURRENT_BASE_IMAGE # The actual image tag to use for the build

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
