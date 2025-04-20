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
# Returns: 0 (always succeeds now)
# Sets: DOCKER_USERNAME, DOCKER_REGISTRY, DOCKER_REPO_PREFIX and other environment variables from .env if present
# =========================================================================
load_env_variables() {
  # Check multiple locations for the .env file
  ENV_FILE=""
  if [ -f .env ]; then
    ENV_FILE=".env"
    echo "Found .env file in current directory, loading defaults..."
  elif [ -f "../.vscode/.env" ]; then
    ENV_FILE="../.vscode/.env"
    echo "Found .env file in ../.vscode directory, loading defaults..."
  elif [ -f "$(dirname "$0")/../.env" ]; then
    ENV_FILE="$(dirname "$0")/../.env"
    echo "Found .env file in parent directory, loading defaults..."
  else
    echo "No .env file found in standard locations. User will be prompted for all details."
  fi

  # Attempt to load variables if file found
  if [ -n "$ENV_FILE" ]; then
    set -a  # Automatically export all variables
    . "$ENV_FILE" # Use '.' instead of 'source' for POSIX compatibility
    set +a  # Stop automatically exporting
  fi

  # Initialize variables if they are not set (from .env or otherwise)
  # These will serve as initial defaults for the prompts
  DOCKER_REGISTRY=${DOCKER_REGISTRY:-}
  DOCKER_USERNAME=${DOCKER_USERNAME:-}
  DOCKER_REPO_PREFIX=${DOCKER_REPO_PREFIX:-}
  DEFAULT_BASE_IMAGE=${DEFAULT_BASE_IMAGE:-"kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"} # Keep a fallback default

  # Export potentially loaded or initialized variables
  # They will be confirmed/overridden in get_user_preferences
  export DOCKER_REGISTRY
  export DOCKER_USERNAME
  export DOCKER_REPO_PREFIX
  export DEFAULT_BASE_IMAGE

  # No error checks here, validation happens in get_user_preferences
  echo "Initial Docker values (will be confirmed/edited):"
  echo "  Registry: ${DOCKER_REGISTRY:-<Not Set - Docker Hub>}"
  echo "  Username: ${DOCKER_USERNAME:-<Not Set>}"
  echo "  Repo Prefix: ${DOCKER_REPO_PREFIX:-<Not Set>}"
  
  return 0 # Always return success
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
# Sets: use_cache, use_squash, skip_intermediate_push_pull, use_builder, BASE_IMAGE_ACTION, CUSTOM_BASE_IMAGE, CURRENT_BASE_IMAGE, DOCKER_REGISTRY, DOCKER_USERNAME, DOCKER_REPO_PREFIX
# =========================================================================
get_user_preferences() {
  # Check if dialog is available, fallback if not
  if ! check_install_dialog; then
    echo "Dialog not available or failed to install. Falling back to basic prompts." >&2
    return get_user_preferences_basic
  fi

  # Create temporary files safely
  local temp_options temp_base_choice temp_custom_image temp_docker_info
  temp_options=$(mktemp) || { echo "Failed to create temp file"; return 1; }
  temp_base_choice=$(mktemp) || { echo "Failed to create temp file"; rm -f "$temp_options"; return 1; }
  temp_custom_image=$(mktemp) || { echo "Failed to create temp file"; rm -f "$temp_options" "$temp_base_choice"; return 1; }
  temp_docker_info=$(mktemp) || { echo "Failed to create temp file"; rm -f "$temp_options" "$temp_base_choice" "$temp_custom_image"; return 1; }


  # Ensure temp files are cleaned up on exit or error
  trap 'rm -f "$temp_options" "$temp_base_choice" "$temp_custom_image" "$temp_docker_info"' EXIT TERM INT

  # Dialog dimensions
  local DIALOG_HEIGHT=25
  local DIALOG_WIDTH=85
  local CHECKLIST_HEIGHT=6
  local FORM_HEIGHT=6 # Number of visible lines in the form

  # --- Step 0: Docker Registry/User/Prefix Confirmation ---
  while true; do
    dialog --backtitle "Docker Build Configuration" \
           --title "Step 0: Docker Information" \
           --ok-label "Next: Build Options" \
           --cancel-label "Exit Build" \
           --form "Confirm or edit Docker details (loaded from .env):" $DIALOG_HEIGHT $DIALOG_WIDTH $FORM_HEIGHT \
           "Registry (optional, empty=Docker Hub):" 1 1 "$DOCKER_REGISTRY"     1 40 70 0 \
           "Username (required):"                   2 1 "$DOCKER_USERNAME"    2 40 70 0 \
           "Repository Prefix (required):"          3 1 "$DOCKER_REPO_PREFIX" 3 40 70 0 \
           2>"$temp_docker_info"

    local form_exit_status=$?
    if [ $form_exit_status -ne 0 ]; then
      echo "Docker information entry canceled (exit code: $form_exit_status). Exiting." >&2
      return 1 # Indicate cancellation
    fi

    # Read the values back from the temp file (one per line)
    local lines=()
    while IFS= read -r line; do
      lines+=("$line")
    done < "$temp_docker_info"

    # Assign to variables (handle potential empty registry)
    DOCKER_REGISTRY="${lines[0]:-}" # Use parameter expansion for default empty string
    DOCKER_USERNAME="${lines[1]}"
    DOCKER_REPO_PREFIX="${lines[2]}"

    # Validate required fields
    local validation_error=""
    if [[ -z "$DOCKER_USERNAME" ]]; then
      validation_error+="Username cannot be empty.\n"
    fi
    if [[ -z "$DOCKER_REPO_PREFIX" ]]; then
      validation_error+="Repository Prefix cannot be empty.\n"
    fi

    if [[ -n "$validation_error" ]]; then
      dialog --msgbox "Validation Error:\n\n$validation_error\nPlease correct the entries." 10 $DIALOG_WIDTH
      if [ $? -ne 0 ]; then echo "Msgbox closed unexpectedly. Exiting." >&2; return 1; fi
      # Loop continues
    else
      # Validation passed, break the loop
      break
    fi
  done

  # --- Step 1: Main Build Options Checklist ---
  # Define default states for checklist
  local cache_default="off"
  local squash_default="off"
  local local_build_default="on"
  local builder_default="on"

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
  # Update DEFAULT_BASE_IMAGE display if DOCKER_USERNAME or DOCKER_REPO_PREFIX changed
  # This is tricky as DEFAULT_BASE_IMAGE might be unrelated. Let's keep it simple for now
  # and just display the original DEFAULT_BASE_IMAGE from .env.
  # A more robust solution might involve reconstructing the default based on new user/prefix,
  # but that assumes a specific pattern for the default image.
  local current_default_base_image_display="$DEFAULT_BASE_IMAGE" # Use the one loaded initially

  local MENU_HEIGHT=4
  dialog --backtitle "Docker Build Configuration" \
         --title "Step 2: Base Image Selection" \
         --ok-label "Confirm Choice" \
         --cancel-label "Exit Build" \
         --radiolist "Choose the base image for the *first* build stage:" $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
         "use_default"    "Use Default (if locally available): $current_default_base_image_display"  "on" \
         "pull_default"   "Pull Default Image Now: $current_default_base_image_display"             "off" \
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
  confirmation_message+="Docker Info:\n"
  confirmation_message+="  - Registry:         ${DOCKER_REGISTRY:-Docker Hub}\n"
  confirmation_message+="  - Username:         $DOCKER_USERNAME\n"
  confirmation_message+="  - Repo Prefix:      $DOCKER_REPO_PREFIX\n\n"
  confirmation_message+="Build Options:\n"
  confirmation_message+="  - Use Cache:          $( [[ "$use_cache" == "y" ]] && echo "Yes" || echo "No (--no-cache)" )\n"
  confirmation_message+="  - Squash Layers:      $( [[ "$use_squash" == "y" ]] && echo "Yes (--squash)" || echo "No" )\n"
  confirmation_message+="  - Build Locally Only: $( [[ "$skip_intermediate_push_pull" == "y" ]] && echo "Yes (--load)" || echo "No (--push)" )\n"
  confirmation_message+="  - Use Builder:        $( [[ "$use_builder" == "y" ]] && echo "Yes (jetson-builder)" || echo "No (Default Docker)" )\n\n"
  confirmation_message+="Base Image for First Stage:\n"
  confirmation_message+="  - Action Chosen:      $BASE_IMAGE_ACTION\n"
  confirmation_message+="  - Image Tag To Use:   $CURRENT_BASE_IMAGE"

  if ! dialog --yes-label "Start Build" --no-label "Cancel Build" --yesno "$confirmation_message\n\nProceed with build?" 22 $DIALOG_WIDTH; then # Increased height slightly
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
  # Export potentially updated Docker info
  export DOCKER_REGISTRY
  export DOCKER_USERNAME
  export DOCKER_REPO_PREFIX

  # Explicitly remove trap and temp files on success
  trap - EXIT TERM INT
  rm -f "$temp_options" "$temp_base_choice" "$temp_custom_image" "$temp_docker_info"

  return 0 # Success
}

# =========================================================================
# Function: Fallback to basic prompts if dialog is not available
# Returns: 0 if successful, 1 if not
# Sets: use_cache, use_squash, skip_intermediate_push_pull, DOCKER_REGISTRY, DOCKER_USERNAME, DOCKER_REPO_PREFIX, CURRENT_BASE_IMAGE
# =========================================================================
get_user_preferences_basic() {
  # --- Docker Info ---
  echo "--- Docker Information ---"
  # Use loaded/initialized values as defaults in brackets []
  read -p "Docker Registry (leave empty for Docker Hub) [$DOCKER_REGISTRY]: " input_registry
  DOCKER_REGISTRY=${input_registry:-$DOCKER_REGISTRY} # Use entered or existing default

  # Enforce required fields
  while true; do
    read -p "Docker Username (required) [$DOCKER_USERNAME]: " input_username
    # If user entered something, use it. Otherwise, use the existing default.
    DOCKER_USERNAME=${input_username:-$DOCKER_USERNAME}
    if [[ -n "$DOCKER_USERNAME" ]]; then break; else echo "Username cannot be empty."; fi
  done

  while true; do
    read -p "Docker Repo Prefix (required) [$DOCKER_REPO_PREFIX]: " input_prefix
    DOCKER_REPO_PREFIX=${input_prefix:-$DOCKER_REPO_PREFIX}
    if [[ -n "$DOCKER_REPO_PREFIX" ]]; then break; else echo "Repo Prefix cannot be empty."; fi
  done
  echo "Using Registry: ${DOCKER_REGISTRY:-Docker Hub}, User: $DOCKER_USERNAME, Prefix: $DOCKER_REPO_PREFIX"
  echo "-------------------------"

  # --- Build Options ---
  echo "--- Build Options ---"
  # Ask user about build cache usage
  read -p "Do you want to build with cache? (y/n) [Default: n]: " use_cache_input
  use_cache=${use_cache_input:-n}
  # Ensure valid input for cache
  while [[ "$use_cache" != "y" && "$use_cache" != "n" ]]; do
    echo "Invalid input. Please enter 'y' or 'n'." >&2
    read -p "Do you want to build with cache? (y/n) [Default: n]: " use_cache_input
    use_cache=${use_cache_input:-n}
  done

  # Ask user about squashing (experimental)
  read -p "Do you want to attempt squashing image layers (experimental)? (y/n) [Default: n]: " use_squash_input
  use_squash=${use_squash_input:-n}
   while [[ "$use_squash" != "y" && "$use_squash" != "n" ]]; do
    echo "Invalid input. Please enter 'y' or 'n'." >&2
    read -p "Do you want to attempt squashing image layers (experimental)? (y/n) [Default: n]: " use_squash_input
    use_squash=${use_squash_input:-n}
  done
  if [ "$use_squash" == "y" ]; then
      echo "Warning: Buildx --squash is experimental and may affect caching or build success." >&2
  fi

  # Ask user about skipping intermediate push/pull
  read -p "Skip intermediate push/pull for each stage (Build Locally Only)? (y/n) [Default: y]: " skip_intermediate_push_pull_input
  skip_intermediate_push_pull=${skip_intermediate_push_pull_input:-y}
   while [[ "$skip_intermediate_push_pull" != "y" && "$skip_intermediate_push_pull" != "n" ]]; do
    echo "Invalid input. Please enter 'y' or 'n'." >&2
    read -p "Skip intermediate push/pull for each stage? (y/n) [Default: y]: " skip_intermediate_push_pull_input
    skip_intermediate_push_pull=${skip_intermediate_push_pull_input:-y}
  done
  if [ "$skip_intermediate_push_pull" == "y" ]; then
      echo "Note: Skipping push/pull. Will use '--load' to make images available locally." >&2
  else
      echo "Note: Intermediate images will be pushed to the registry." >&2
  fi

  # Ask about using the builder (basic prompt doesn't currently ask this, add it)
  read -p "Use Optimized Jetson Builder (jetson-builder)? (y/n) [Default: y]: " use_builder_input
  use_builder=${use_builder_input:-y}
   while [[ "$use_builder" != "y" && "$use_builder" != "n" ]]; do
    echo "Invalid input. Please enter 'y' or 'n'." >&2
    read -p "Use Optimized Jetson Builder? (y/n) [Default: y]: " use_builder_input
    use_builder=${use_builder_input:-y}
  done
   if [ "$use_builder" == "n" ]; then
      echo "Warning: Not using the dedicated 'jetson-builder' might lead to issues." >&2
  fi
  echo "-------------------------"


  # --- Base Image ---
  echo "--- Base Image ---"
  # Use the initially loaded DEFAULT_BASE_IMAGE for prompts
  local current_default_base_image_display="$DEFAULT_BASE_IMAGE"
  echo "Default base image: $current_default_base_image_display"
  read -p "Action? (u=Use existing, p=Pull default, c=Specify custom) [Default: u]: " base_action_input
  base_action=${base_action_input:-u}

  case "$base_action" in
    p|P)
      echo "Pulling base image: $current_default_base_image_display"
      if ! docker pull "$current_default_base_image_display"; then
        echo "Warning: Failed to pull base image. Build may fail if image doesn't exist locally." >&2
      fi
      CURRENT_BASE_IMAGE="$current_default_base_image_display"
      ;;
    c|C)
      read -p "Enter full URL/tag of the custom base image: " custom_image
      if [ -z "$custom_image" ]; then
        echo "No image specified, using default: $current_default_base_image_display" >&2
        CURRENT_BASE_IMAGE="$current_default_base_image_display"
      else
        CURRENT_BASE_IMAGE="$custom_image"
        echo "Attempting to pull custom base image: $CURRENT_BASE_IMAGE" >&2
         if ! docker pull "$CURRENT_BASE_IMAGE"; then
            echo "Warning: Failed to pull custom base image. Build may fail if image doesn't exist locally." >&2
         fi
      fi
      ;;
    *) # Includes 'u' or invalid input
      echo "Using existing base image (no pull): $current_default_base_image_display" >&2
      CURRENT_BASE_IMAGE="$current_default_base_image_display"
      ;;
  esac
  echo "-------------------------"

  # --- Confirmation ---
  echo "Summary:"
  echo "  Registry: ${DOCKER_REGISTRY:-Docker Hub}, User: $DOCKER_USERNAME, Prefix: $DOCKER_REPO_PREFIX"
  echo "  Use Cache: $use_cache, Squash: $use_squash, Local Build Only: $skip_intermediate_push_pull, Use Builder: $use_builder"
  echo "  Base Image for First Stage: $CURRENT_BASE_IMAGE"
  read -p "Proceed with build? (y/n) [Default: y]: " confirm_build
  if [[ "${confirm_build:-y}" != "y" ]]; then
      echo "Build cancelled."
      return 1
  fi

  export use_cache
  export use_squash
  export skip_intermediate_push_pull
  export use_builder # Export this now
  export CURRENT_BASE_IMAGE
  # Export potentially updated Docker info
  export DOCKER_REGISTRY
  export DOCKER_USERNAME
  export DOCKER_REPO_PREFIX

  return 0
}
