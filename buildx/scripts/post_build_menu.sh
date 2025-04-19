# COMMIT-TRACKING: UUID-20240729-004815-A3B1
# Description: Implement interactive menu for post-build container operations
# Author: Mr K
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── post_build_menu.sh <- THIS FILE
# └── ...                        <- Other project files

#!/bin/bash

# Import utility functions
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/docker_utils.sh"
source "$SCRIPT_DIR/check_install_dialog.sh" # Import dialog check

# =========================================================================
# Function: Show post-build menu and handle user selections
# Arguments: $1 = final image tag to operate on
# Returns: 0 if successful, non-zero otherwise
# =========================================================================
show_post_build_menu() {
  local image_tag=$1
  
  echo "--------------------------------------------------"
  echo "Final Image: $image_tag"
  echo "--------------------------------------------------"
  
  # Verify the image exists before offering options
  if ! verify_image_exists "$image_tag"; then
    echo "Error: Final image $image_tag not found locally, cannot proceed."
    return 1
  fi
  
  # Check if dialog is installed and use it; otherwise fall back to basic prompt
  if check_install_dialog; then
    # Dialog-based menu
    show_dialog_menu "$image_tag"
  else
    # Fall back to original text-based menu
    show_text_menu "$image_tag"
  fi
}

# =========================================================================
# Function: Display radiolist-based dialog menu and process selection
# Arguments: $1 = image tag to operate on
# Returns: The exit status of the chosen operation
# =========================================================================
show_dialog_menu() {
  local image_tag=$1
  local temp_file=$(mktemp)
  
  # Dialog dimensions
  local HEIGHT=20
  local WIDTH=70
  local LIST_HEIGHT=6  # Show all options in the list
  
  # Dialog text
  local TITLE="Post-Build Operations"
  local TEXT="Select an action for image: $image_tag"
  
  # Options: tag item status
  local OPTIONS=(
    "shell"      "Start an interactive shell"                   "off"
    "verify"     "Run quick verification (common tools)"        "on"   # Default selection
    "full"       "Run full verification (all packages)"         "off"
    "list"       "List installed apps in the container"         "off"
    "skip"       "Skip (do nothing)"                            "off"
  )
  
  # Display the radiolist dialog
  dialog --clear \
         --backtitle "Docker Image Operations" \
         --title "$TITLE" \
         --radiolist "$TEXT" $HEIGHT $WIDTH $LIST_HEIGHT \
         "${OPTIONS[@]}" \
         2>$temp_file
  
  # Get the exit status and selection
  local exit_status=$?
  local selection=$(cat $temp_file)
  rm -f $temp_file
  
  # Clear screen after dialog
  clear
  
  # If ESC or Cancel was pressed, exit
  if [ $exit_status -ne 0 ]; then
    echo "Operation cancelled."
    return 0
  fi
  
  # Process the selection
  case $selection in
    "shell")
      echo "Starting interactive shell..."
      docker run -it --rm "$image_tag" bash
      return $?
      ;;
    "verify")
      verify_container_apps "$image_tag" "quick"
      return $?
      ;;
    "full")
      verify_container_apps "$image_tag" "all"
      return $?
      ;;
    "list")
      list_installed_apps "$image_tag"
      return $?
      ;;
    "skip"|"")
      echo "Skipping container run."
      return 0
      ;;
    *)
      echo "Invalid choice. Skipping container run."
      return 0
      ;;
  esac
}

# =========================================================================
# Function: Original text-based menu (fallback)
# Arguments: $1 = image tag to operate on
# Returns: The exit status of the chosen operation
# =========================================================================
show_text_menu() {
  local image_tag=$1
  
  # Offer options for what to do with the image
  echo "What would you like to do with the final image?"
  echo "1) Start an interactive shell"
  echo "2) Run quick verification (common tools and packages)"
  echo "3) Run full verification (all system packages, may be verbose)"
  echo "4) List installed apps in the container"
  echo "5) Skip (do nothing)"
  
  read -p "Enter your choice (1-5): " user_choice
  
  case $user_choice in
    1)
      echo "Starting interactive shell..."
      docker run -it --rm "$image_tag" bash
      return $?
      ;;
    2)
      verify_container_apps "$image_tag" "quick"
      return $?
      ;;
    3)
      verify_container_apps "$image_tag" "all"
      return $?
      ;;
    4)
      list_installed_apps "$image_tag"
      return $?
      ;;
    5)
      echo "Skipping container run."
      return 0
      ;;
    *)
      echo "Invalid choice. Skipping container run."
      return 0
      ;;
  esac
}
