# COMMIT-TRACKING: UUID-20240803-111500-DLGS # Use current system time
# Description: Simplified dialog interface for build options with clearer language and consolidated steps.
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

# Import dialog check utility
source "$(dirname "$0")/check_install_dialog.sh"

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
# Returns: 0 if successful, 1 if not (e.g., on cancel)
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
# Returns: 0 if successful, 1 if not (e.g., on cancel/error)
# Sets: use_cache, use_squash, skip_intermediate_push_pull, use_builder, BASE_IMAGE_ACTION, CUSTOM_BASE_IMAGE, CURRENT_BASE_IMAGE
# =========================================================================
get_user_preferences() {
  # Check if dialog is available, fallback if not
  if ! check_install_dialog; then
    echo "Dialog not available or failed to install. Falling back to basic prompts." >&2
    return get_user_preferences_basic
  fi

  # Create temporary files safely
  local temp_options temp_base_choice temp_custom_image
  temp_options=$(mktemp) || { echo "Failed to create temp file"; return 1; }
  temp_base_choice=$(mktemp) || { echo "Failed to create temp file"; rm -f "$temp_options"; return 1; }
  temp_custom_image=$(mktemp) || { echo "Failed to create temp file"; rm -f "$temp_options" "$temp_base_choice"; return 1; }

  # Ensure temp files are cleaned up on exit or error
  trap 'rm -f "$temp_options" "$temp_base_choice" "$temp_custom_image"' EXIT TERM INT

  # Define default states for checklist
  local cache_default="off"
  local squash_default="off"
  local local_build_default="on"
  local builder_default="on"

  # Dialog dimensions
  local DIALOG_HEIGHT=25
  local DIALOG_WIDTH=85
  local CHECKLIST_HEIGHT=6

  # --- Step 1: Main Build Options Checklist ---
  dialog --backtitle "Docker Build Configuration" \
         --title "Step 1: Build Options" \
         --ok-label "Next: Base Image" \
         --cancel-label "Exit Build" \
         --checklist "Use Spacebar to toggle options, Enter to confirm:" $DIALOG_HEIGHT $DIALOG_WIDTH $CHECKLIST_HEIGHT \
         "cache"         "Use Build Cache (Faster, uses previous layers)"        "$cache_default" \
         "squash"        "Squash Layers (Smaller final image, experimental)"     "$squash_default" \
         "local_build"   "Build Locally Only (Faster, no registry push/pull)"    "$local_build_default" \
         "use_builder"   "Use Optimized Jetson Builder (Recommended)"            "$builder_default" \
          2>"$temp_options"

  local checklist_exit_status=$?
  if [ $checklist_exit_status -ne 0 ]; then
    echo "Build options selection canceled (exit code: $checklist_exit_status). Exiting." >&2
    # Trap will clean up temp files
    return 1 # Indicate cancellation
  fi
  local selected_options
  selected_options=$(cat "$temp_options")

  # Parse checklist selections
  [[ "$selected_options" == *'"cache"'* ]] && use_cache="y" || use_cache="n"
  [[ "$selected_options" == *'"squash"'* ]] && use_squash="y" || use_squash="n"
  [[ "$selected_options" == *'"local_build"'* ]] && skip_intermediate_push_pull="y" || skip_intermediate_push_pull="n"
  [[ "$selected_options" == *'"use_builder"'* ]] && use_builder="y" || use_builder="n"

  if [[ "$use_builder" == "n" ]]; then
      dialog --msgbox "Warning: Not using the dedicated 'jetson-builder' might lead to issues with NVIDIA runtime during build." 8 70
      # Check exit status of msgbox (though usually just 0)
      if [ $? -ne 0 ]; then echo "Msgbox closed unexpectedly. Exiting." >&2; return 1; fi
  fi

  # --- Step 2: Base Image Selection ---
  local MENU_HEIGHT=4
  dialog --backtitle "Docker Build Configuration" \
         --title "Step 2: Base Image Selection" \
         --ok-label "Confirm Choice" \
         --cancel-label "Exit Build" \
         --radiolist "Choose the base image for the *first* build stage:" $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
         "use_default"    "Use Default (if locally available): $DEFAULT_BASE_IMAGE"  "on" \
         "pull_default"   "Pull Default Image Now: $DEFAULT_BASE_IMAGE"             "off" \
         "specify_custom" "Specify Custom Image (will attempt pull)"                "off" \
         2>"$temp_base_choice"

  local menu_exit_status=$?
  if [ $menu_exit_status -ne 0 ]; then
    echo "Base image selection canceled (exit code: $menu_exit_status). Exiting." >&2
    # Trap will clean up temp files
    return 1 # Indicate cancellation
  fi
  BASE_IMAGE_ACTION=$(cat "$temp_base_choice")

  # Process base image choice
  CUSTOM_BASE_IMAGE="$DEFAULT_BASE_IMAGE" # Initialize

  case "$BASE_IMAGE_ACTION" in
    "specify_custom")
      dialog --backtitle "Docker Build Configuration" \
             --title "Step 2a: Custom Base Image" \
             --ok-label "Confirm Image" \
             --cancel-label "Exit Build" \
             --inputbox "Enter the full Docker image tag (e.g., user/repo:tag):" 10 $DIALOG_WIDTH "$DEFAULT_BASE_IMAGE" \
             2>"$temp_custom_image"
      local input_exit_status=$?
      if [ $input_exit_status -ne 0 ]; then
        echo "Custom base image input canceled (exit code: $input_exit_status). Exiting." >&2
        # Trap will clean up temp files
        return 1
      fi
      local entered_image
      entered_image=$(cat "$temp_custom_image")

      if [ -z "$entered_image" ]; then
        dialog --msgbox "No custom image entered. Reverting to default:\n$DEFAULT_BASE_IMAGE" 8 $DIALOG_WIDTH
        if [ $? -ne 0 ]; then echo "Msgbox closed unexpectedly. Exiting." >&2; return 1; fi
        CUSTOM_BASE_IMAGE="$DEFAULT_BASE_IMAGE"
        BASE_IMAGE_ACTION="use_default"
      else
        CUSTOM_BASE_IMAGE="$entered_image"
        dialog --infobox "Attempting to pull custom base image:\n$CUSTOM_BASE_IMAGE..." 5 $DIALOG_WIDTH
        sleep 1 # Give time to see the message
        if ! docker pull "$CUSTOM_BASE_IMAGE"; then
          if dialog --yesno "Failed to pull custom base image:\n$CUSTOM_BASE_IMAGE.\nCheck tag/URL.\n\nContinue build using default ($DEFAULT_BASE_IMAGE)?" 12 $DIALOG_WIDTH; then
             CUSTOM_BASE_IMAGE="$DEFAULT_BASE_IMAGE"
             BASE_IMAGE_ACTION="use_default"
             dialog --msgbox "Proceeding with default base image:\n$DEFAULT_BASE_IMAGE" 8 $DIALOG_WIDTH
             if [ $? -ne 0 ]; then echo "Msgbox closed unexpectedly. Exiting." >&2; return 1; fi
          else
             echo "User chose to exit after failed custom image pull." >&2
             return 1
          fi
        else
          dialog --msgbox "Successfully pulled custom base image:\n$CUSTOM_BASE_IMAGE" 8 $DIALOG_WIDTH
          if [ $? -ne 0 ]; then echo "Msgbox closed unexpectedly. Exiting." >&2; return 1; fi
        fi
      fi
      ;;
    "pull_default")
      dialog --infobox "Attempting to pull default base image:\n$DEFAULT_BASE_IMAGE..." 5 $DIALOG_WIDTH
      sleep 1
      if ! docker pull "$DEFAULT_BASE_IMAGE"; then
         if dialog --yesno "Failed to pull default base image:\n$DEFAULT_BASE_IMAGE.\nBuild might fail if not local.\n\nContinue anyway?" 12 $DIALOG_WIDTH; then
            dialog --msgbox "Warning: Default image not pulled. Using local if available." 8 $DIALOG_WIDTH
            if [ $? -ne 0 ]; then echo "Msgbox closed unexpectedly. Exiting." >&2; return 1; fi
         else
            echo "User chose to exit after failed default image pull." >&2
            return 1
         fi
      else
        dialog --msgbox "Successfully pulled default base image:\n$DEFAULT_BASE_IMAGE" 8 $DIALOG_WIDTH
        if [ $? -ne 0 ]; then echo "Msgbox closed unexpectedly. Exiting." >&2; return 1; fi
      fi
      CUSTOM_BASE_IMAGE="$DEFAULT_BASE_IMAGE"
      ;;
    "use_default")
      CUSTOM_BASE_IMAGE="$DEFAULT_BASE_IMAGE"
      dialog --msgbox "Using default base image (local version if available):\n$DEFAULT_BASE_IMAGE" 8 $DIALOG_WIDTH
      if [ $? -ne 0 ]; then echo "Msgbox closed unexpectedly. Exiting." >&2; return 1; fi
      ;;
    *)
      echo "Invalid base image action selected: '$BASE_IMAGE_ACTION'. Exiting." >&2
      return 1
      ;;
  esac

  # Set the final CURRENT_BASE_IMAGE
  CURRENT_BASE_IMAGE="$CUSTOM_BASE_IMAGE"

  # --- Step 3: Final Confirmation ---
  local confirmation_message
  confirmation_message="Build Configuration Summary:\n\n"
  confirmation_message+="Build Options:\n"
  confirmation_message+="  - Use Cache:          $( [[ "$use_cache" == "y" ]] && echo "Yes" || echo "No (--no-cache)" )\n"
  confirmation_message+="  - Squash Layers:      $( [[ "$use_squash" == "y" ]] && echo "Yes (--squash)" || echo "No" )\n"
  confirmation_message+="  - Build Locally Only: $( [[ "$skip_intermediate_push_pull" == "y" ]] && echo "Yes (--load)" || echo "No (--push)" )\n"
  confirmation_message+="  - Use Builder:        $( [[ "$use_builder" == "y" ]] && echo "Yes (jetson-builder)" || echo "No (Default Docker)" )\n\n"
  confirmation_message+="Base Image for First Stage:\n"
  confirmation_message+="  - Action Chosen:      $BASE_IMAGE_ACTION\n"
  confirmation_message+="  - Image Tag To Use:   $CURRENT_BASE_IMAGE"

  if ! dialog --yes-label "Start Build" --no-label "Cancel Build" --yesno "$confirmation_message\n\nProceed with build?" 20 $DIALOG_WIDTH; then
      echo "Build canceled by user at confirmation screen. Exiting." >&2
      # Trap will clean up temp files
      return 1 # Indicate cancellation
  fi

  # Export all variables for use in the main script
  export use_cache
  export use_squash
  export skip_intermediate_push_pull
  export use_builder # Export this as well
  export BASE_IMAGE_ACTION
  export CUSTOM_BASE_IMAGE # Holds the custom image if specified or default
  export CURRENT_BASE_IMAGE # The actual image tag to use for the build

  # Explicitly remove trap and temp files on success
  trap - EXIT TERM INT
  rm -f "$temp_options" "$temp_base_choice" "$temp_custom_image"

  return 0 # Success
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
