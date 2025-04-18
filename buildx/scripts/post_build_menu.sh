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
