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
 (e.g., on cancel)
# =========================================================================ON, CUSTOM_BASE_IMAGE, CURRENT_BASE_IMAGE
# Function: Check if dialog is installed and install if needed===================================================
# Returns: 0 if successful, 1 if not
# =========================================================================
check_install_dialog() {
  if ! command -v dialog &> /dev/null; thenilable
    echo "Dialog package not found. Installing dialog..." >&2
    if command -v apt-get &> /dev/null; then
      sudo apt-get update -y && sudo apt-get install -y dialog
    elif command -v yum &> /dev/null; then
      sudo yum install -y dialogmktemp)
    else_file2=$(mktemp) # Second temp file for menu
      echo "Could not install dialog: Unsupported package manager." >&2
      return 1# Define default states for checklist
    fie --no-cache
  fi
  _push_pull_default="on" # on = Yes = Use --load
  if ! command -v dialog &> /dev/null; then
    echo "Failed to install dialog. Falling back to basic prompts." >&2# Use --checklist for boolean options - Added visual '[ ]' for 'No'
    return 1Only the first checkbox [ ] is functional. The second is just text.
  fi dialog --backtitle "Docker Build Configuration" \
           --title "Build Preferences ([X]=Yes, [ ]=No)" \
  return 0onfirms):" 18 85 4 \
}che)" "$cache_default" \
ash)" "$squash_default" \
# =========================================================================
# Function: Get user preferences for build using dialogn" \
# Returns: 0 if successful, 1 if not (e.g., on cancel)
# Sets: use_cache, use_squash, skip_intermediate_push_pull, BASE_IMAGE_ACTION, CUSTOM_BASE_IMAGE, CURRENT_BASE_IMAGE
# =========================================================================
get_user_preferences() {
  # Try to use dialog interface
  if ! check_install_dialog; thenProcess checklist results - Exit on Cancel/Esc
    # Fall back to original prompting method if dialog not available  if [ $checklist_exit_status -ne 0 ]; then
    return get_user_preferences_basiceled. Exiting." >&2
  fi$temp_file2

  # Create temporary file to store results  fi
  temp_file=$(mktemp)
  temp_file2=$(mktemp) # Second temp file for menu
|| use_cache="n"
  # Define default states for checklisty" || use_squash="n"
  local cache_default="off" # off = No = Use --no-cache  [[ "$selected_options" == *'"skip_push_pull"'* ]] && skip_intermediate_push_pull="y" || skip_intermediate_push_pull="n"
  local squash_default="off" # off = No = Don't use --squash
  local skip_push_pull_default="on" # on = Yes = Use --load
ions for clarity
  # Use --checklist for boolean options - Added visual '[ ]' for 'No'
  # Note: Only the first checkbox [ ] is functional. The second is just text.
  dialog --backtitle "Docker Build Configuration" \
         --title "Build Preferences ([X]=Yes, [ ]=No)" \
         --checklist "\nSelect build options (Spacebar toggles [X], Enter confirms):" 18 85 4 \
         "cache" "[ ] Use Build Cache   [ ] No (--no-cache)" "$cache_default" \
         "squash" "[ ] Squash Layers     [ ] No (--squash)" "$squash_default" \2 # Use the second temp file
         "skip_push_pull" "[ ] Skip Push/Pull  [ ] No (--load)" "$skip_push_pull_default" \
         "use_builder" "[ ] Use Builder       [ ] No (Recommended: Yes)" "on" \
         2>$temp_file2)

  checklist_exit_status=$?
  selected_options=$(cat $temp_file)

  # Process checklist results - Exit on Cancel/Esc
  if [ $checklist_exit_status -ne 0 ]; then
    echo "Build preferences selection canceled. Exiting." >&2
    rm -f $temp_file $temp_file2
    return 1 # Indicate cancellationd
  fi

  # Parse selections if OK was pressed
  [[ "$selected_options" == *'"cache"'* ]] && use_cache="y" || use_cache="n"on" \
  [[ "$selected_options" == *'"squash"'* ]] && use_squash="y" || use_squash="n"             --title "Custom Base Image" \
  [[ "$selected_options" == *'"skip_push_pull"'* ]] && skip_intermediate_push_pull="y" || skip_intermediate_push_pull="n"o use and pull (Enter to confirm):" 10 85 "$DEFAULT_BASE_IMAGE" \
  # 'use_builder' is assumed yes if dialog is used

  # Base image selection using --menu - Renamed options for clarity
  dialog --backtitle "Docker Build Configuration" \
         --title "Base Image Selection" \
         --menu "Select base image action (Enter to confirm):" 18 85 3 \
         "use_default" "Use Default (No Pull): $DEFAULT_BASE_IMAGE" \
         "pull_default" "Pull Default: $DEFAULT_BASE_IMAGE" \        echo "Custom base image input canceled. Exiting." >&2
         "specify_custom" "Specify Custom Image (Will Pull)" \ile $temp_file2
         2>$temp_file2 # Use the second temp fileon
      fi
  menu_exit_status=$?
  BASE_IMAGE_ACTION=$(cat $temp_file2)d

  # Process menu results - Exit on Cancel/Esc image entered. Reverting to default:\n$DEFAULT_BASE_IMAGE" 8 60
  if [ $menu_exit_status -ne 0 ]; thenBASE_IMAGE"
    echo "Base image selection canceled. Exiting." >&2    BASE_IMAGE_ACTION="use_default" # Revert action
    rm -f $temp_file $temp_file2      else
    return 1 # Indicate cancellationbase image: $CUSTOM_BASE_IMAGE" >&2
  ficustom image immediately
box "Pulling custom base image:\n$CUSTOM_BASE_IMAGE..." 5 70
  # Process selection if OK was pressede the message
  case "$BASE_IMAGE_ACTION" in
    "specify_custom")efore exiting
      # Ask for custom base imageult image ($DEFAULT_BASE_IMAGE)?" 12 70; then
      dialog --backtitle "Docker Build Configuration" \GE"
             --title "Custom Base Image" \             BASE_IMAGE_ACTION="use_default" # Revert on pull failure but continue
             --inputbox "Enter the full URL/tag of the base image to use and pull (Enter to confirm):" 10 85 "$DEFAULT_BASE_IMAGE" \ing with default base image." >&2
             2>$temp_file # Reuse first temp file
             echo "User chose to exit after failed custom image pull." >&2
      input_exit_status=$?e2
      CUSTOM_BASE_IMAGE=$(cat $temp_file)s No

      # Exit on Cancel/Esc in input box
      if [ $input_exit_status -ne 0 ]; thenpulled custom base image:\n$CUSTOM_BASE_IMAGE" 8 70
        echo "Custom base image input canceled. Exiting." >&2  # Keep BASE_IMAGE_ACTION as specify_custom, image is set
        rm -f $temp_file $temp_file2        fi
        return 1 # Indicate cancellation
      fi

      # Process input if OK was pressed
      if [ -z "$CUSTOM_BASE_IMAGE" ]; thenEFAULT_BASE_IMAGE..." 5 70
        dialog --msgbox "No base image entered. Reverting to default:\n$DEFAULT_BASE_IMAGE" 8 60p 1
        CUSTOM_BASE_IMAGE="$DEFAULT_BASE_IMAGE"
        BASE_IMAGE_ACTION="use_default" # Revert action
      elseGE.\nBuild might fail if not available locally.\n\nContinue anyway?" 12 70; then
        echo "Attempting to use custom base image: $CUSTOM_BASE_IMAGE" >&2d default base image." >&2
        # Attempt to pull the custom image immediately
        dialog --infobox "Pulling custom base image:\n$CUSTOM_BASE_IMAGE..." 5 70lt image pull." >&2
        sleep 1 # Give time to see the message
        if ! docker pull "$CUSTOM_BASE_IMAGE"; then
          # Use --yesno for confirmation before exiting
          if dialog --yesno "Failed to pull custom base image:\n$CUSTOM_BASE_IMAGE.\nPlease check the tag/URL.\n\nContinue with default image ($DEFAULT_BASE_IMAGE)?" 12 70; then
             CUSTOM_BASE_IMAGE="$DEFAULT_BASE_IMAGE" --msgbox "Successfully pulled default base image:\n$DEFAULT_BASE_IMAGE" 8 70
             BASE_IMAGE_ACTION="use_default" # Revert on pull failure but continue
             echo "Proceeding with default base image." >&2AGE" # Set image to default after pull attempt
          else
             echo "User chose to exit after failed custom image pull." >&2ault")
             rm -f $temp_file $temp_file2the default base image without pulling
             return 1 # Exit if user selects No
          fi
        else
          dialog --msgbox "Successfully pulled custom base image:\n$CUSTOM_BASE_IMAGE" 8 70
          # Keep BASE_IMAGE_ACTION as specify_custom, image is setn up temp files
        fi$temp_file2
      fi
      ;;
    "pull_default")E_IMAGE="$CUSTOM_BASE_IMAGE"
      # Pull the default base image
      dialog --infobox "Pulling default base image:\n$DEFAULT_BASE_IMAGE..." 5 70
      sleep 1
      if ! docker pull "$DEFAULT_BASE_IMAGE"; then
         # Use --yesno for confirmation before exitingn_message+="  Build Options:\n"
         if dialog --yesno "Failed to pull default base image:\n$DEFAULT_BASE_IMAGE.\nBuild might fail if not available locally.\n\nContinue anyway?" 12 70; then
            echo "Proceeding without guaranteed default base image." >&2yers (Yes/No):   $use_squash\n"
         else(Yes=Load/No=Push): $skip_intermediate_push_pull\n\n"
            echo "User chose to exit after failed default image pull." >&2ion_message+="  Base Image:\n"
            rm -f $temp_file $temp_file2tion_message+="    - Action Selected: $BASE_IMAGE_ACTION\n"
            return 1 # Exit if user selects No
         fi
      else
        dialog --msgbox "Successfully pulled default base image:\n$DEFAULT_BASE_IMAGE" 8 70ialog --yesno "$confirmation_message\n\nProceed with build?" 22 85; then
      ficanceled by user at confirmation screen. Exiting." >&2
      CUSTOM_BASE_IMAGE="$DEFAULT_BASE_IMAGE" # Set image to default after pull attempt
      ;;
    "use_default")
      # Use the default base image without pullingport all variables for use in the main script
      CUSTOM_BASE_IMAGE="$DEFAULT_BASE_IMAGE"  export use_cache
      ;;
  esach_pull
  export BASE_IMAGE_ACTION # Reflects user's menu choice
  # Clean up temp files
  rm -f $temp_file $temp_file2image tag to use for the build

  # Set the final CURRENT_BASE_IMAGE to be used by the build script
  CURRENT_BASE_IMAGE="$CUSTOM_BASE_IMAGE"

  # Format the confirmation message===============================
  local confirmation_message
  confirmation_message="Build will proceed with these settings:\n\n"
  confirmation_message+="  Build Options:\n"
  confirmation_message+="    - Use Build Cache (Yes/No): $use_cache\n"==================================
  confirmation_message+="    - Squash Layers (Yes/No):   $use_squash\n"
  confirmation_message+="    - Skip Push/Pull (Yes=Load/No=Push): $skip_intermediate_push_pull\n\n"
  confirmation_message+="  Base Image:\n"  read -p "Do you want to build with cache? (y/n): " use_cache
  confirmation_message+="    - Action Selected: $BASE_IMAGE_ACTION\n"= "n" ]]; do
  confirmation_message+="    - Image To Be Used: $CURRENT_BASE_IMAGE"

  # Ask for final confirmation before proceeding
  if ! dialog --yesno "$confirmation_message\n\nProceed with build?" 22 85; then
      echo "Build canceled by user at confirmation screen. Exiting." >&2  # Ask user about squashing (experimental)
      return 1 # Indicate cancellationayers (experimental)? (y/n): " use_squash
  fiquash" != "y" && "$use_squash" != "n" ]]; do
nput. Please enter 'y' for yes or 'n' for no." >&2
  # Export all variables for use in the main scriptsquashing image layers (experimental)? (y/n): " use_squash
  export use_cache
  export use_squash
  export skip_intermediate_push_pullhing or build success." >&2
  export BASE_IMAGE_ACTION # Reflects user's menu choice  fi
  export CUSTOM_BASE_IMAGE # Holds the custom image if specified
  export CURRENT_BASE_IMAGE # The actual image tag to use for the build # Ask user about skipping intermediate push/pull
  read -p "Skip intermediate push/pull for each stage (requires --load)? (y/n): " skip_intermediate_push_pull
  return 0 # Successh_pull" != "n" ]]; do
}" >&2
pull for each stage? (y/n): " skip_intermediate_push_pull
# =========================================================================
# Function: Fallback to basic prompts if dialog is not available
# Returns: 0 if successful, 1 if noth/pull. Will use '--load' to make images available locally." >&2
# Sets: use_cache, use_squash, skip_intermediate_push_pull
# =========================================================================
get_user_preferences_basic() {
  # Ask user about build cache usage
  read -p "Do you want to build with cache? (y/n): " use_cache base_action
  while [[ "$use_cache" != "y" && "$use_cache" != "n" ]]; do
    echo "Invalid input. Please enter 'y' for yes or 'n' for no." >&2  case "$base_action" in
    read -p "Do you want to build with cache? (y/n): " use_cache
  done

  # Ask user about squashing (experimental)mage doesn't exist locally." >&2
  read -p "Do you want to attempt squashing image layers (experimental)? (y/n): " use_squash
  while [[ "$use_squash" != "y" && "$use_squash" != "n" ]]; doCURRENT_BASE_IMAGE="$DEFAULT_BASE_IMAGE"
    echo "Invalid input. Please enter 'y' for yes or 'n' for no." >&2
    read -p "Do you want to attempt squashing image layers (experimental)? (y/n): " use_squash
  donec|C|change|CHANGE|Change)
  if [ "$use_squash" == "y" ]; then      read -p "Enter full URL/tag of the base image: " custom_image
      echo "Warning: Buildx --squash is experimental and may affect caching or build success." >&2
  fi

  # Ask user about skipping intermediate push/pull
  read -p "Skip intermediate push/pull for each stage (requires --load)? (y/n): " skip_intermediate_push_pull
  while [[ "$skip_intermediate_push_pull" != "y" && "$skip_intermediate_push_pull" != "n" ]]; do  echo "Using custom base image: $CURRENT_BASE_IMAGE" >&2
    echo "Invalid input. Please enter 'y' for yes or 'n' for no." >&2
    read -p "Skip intermediate push/pull for each stage? (y/n): " skip_intermediate_push_pull
  done  
  if [ "$skip_intermediate_push_pull" == "y" ]; then  *)
      echo "Note: Skipping push/pull. Will use '--load' to make images available locally." >&2ng base image (no pull): $DEFAULT_BASE_IMAGE" >&2
  fi
  
  # Ask about base imageesac
  echo "Current base image: $DEFAULT_BASE_IMAGE"
  read -p "Pull this base image before building? (y/n/change): " base_action
  
  case "$base_action" in
    y|Y|yes|YES|Yes)
      echo "Pulling base image: $DEFAULT_BASE_IMAGE" 0
      if ! docker pull "$DEFAULT_BASE_IMAGE"; then
        echo "Warning: Failed to pull base image. Build may fail if image doesn't exist locally." >&2      fi      CURRENT_BASE_IMAGE="$DEFAULT_BASE_IMAGE"      ;;          c|C|change|CHANGE|Change)      read -p "Enter full URL/tag of the base image: " custom_image      if [ -z "$custom_image" ]; then        echo "No image specified, using default: $DEFAULT_BASE_IMAGE" >&2        CURRENT_BASE_IMAGE="$DEFAULT_BASE_IMAGE"      else        CURRENT_BASE_IMAGE="$custom_image"        echo "Using custom base image: $CURRENT_BASE_IMAGE" >&2      fi      ;;          *)      echo "Using existing base image (no pull): $DEFAULT_BASE_IMAGE" >&2      CURRENT_BASE_IMAGE="$DEFAULT_BASE_IMAGE"      ;;  esac  export use_cache  export use_squash  export skip_intermediate_push_pull  export CURRENT_BASE_IMAGE
  return 0
}
