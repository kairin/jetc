#!/bin/bash

# Post-build menu helpers for Jetson Container build system

SCRIPT_DIR_POST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR_POST/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_POST/docker_helpers.sh" || { echo "Error: docker_helpers.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_POST/verification.sh" || { echo "Error: verification.sh not found."; exit 1; }

show_dialog_menu() {
  local image_tag=$1
  local temp_file=$(mktemp)
  local HEIGHT=20
  local WIDTH=70
  local LIST_HEIGHT=6
  local TITLE="Post-Build Operations"
  local TEXT="Select an action for image: $image_tag"
  local OPTIONS=(
    "shell"      "Start an interactive shell"                   "off"
    "verify"     "Run quick verification (common tools)"        "on"
    "full"       "Run full verification (all packages)"         "off"
    "list"       "List installed apps in the container"         "off"
    "skip"       "Skip (do nothing)"                            "off"
  )
  dialog --clear \
         --backtitle "Docker Image Operations" \
         --title "$TITLE" \
         --radiolist "$TEXT" $HEIGHT $WIDTH $LIST_HEIGHT \
         "${OPTIONS[@]}" \
         2>$temp_file
  local exit_status=$?
  local selection=$(cat $temp_file)
  rm -f $temp_file
  clear
  if [ $exit_status -ne 0 ]; then
    echo "Operation cancelled." >&2
    return 0
  fi
  case $selection in
    "shell")
      echo "Starting interactive shell for $image_tag..." >&2
      docker run -it --rm --gpus all "$image_tag" bash
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
      echo "Skipping post-build container action." >&2
      return 0
      ;;
    *)
      echo "Invalid choice '$selection'. Skipping container action." >&2
      return 0
      ;;
  esac
}

show_text_menu() {
  local image_tag=$1
  echo "--------------------------------------------------"
  echo "Post-Build Options for Image: $image_tag"
  echo "--------------------------------------------------"
  echo "1) Start an interactive shell"
  echo "2) Run quick verification (common tools and packages)"
  echo "3) Run full verification (all system packages, may be verbose)"
  echo "4) List installed apps in the container"
  echo "5) Skip (do nothing)"
  read -p "Enter your choice [1-5, default: 2]: " user_choice
  user_choice=${user_choice:-2}
  case $user_choice in
    1)
      echo "Starting interactive shell for $image_tag..." >&2
      docker run -it --rm --gpus all "$image_tag" bash
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
      echo "Skipping post-build container action." >&2
      return 0
      ;;
    *)
      echo "Invalid choice '$user_choice'. Skipping container action." >&2
      return 0
      ;;
  esac
}

show_post_build_menu() {
  local image_tag=$1
  echo "--------------------------------------------------" >&2
  echo "Final Image Built: $image_tag" >&2
  echo "--------------------------------------------------" >&2
  if ! verify_image_exists "$image_tag"; then
    echo "Error: Final image $image_tag not found locally, cannot proceed with post-build actions." >&2
    return 1
  fi
  if check_install_dialog; then
    show_dialog_menu "$image_tag"
    return $?
  else
    show_text_menu "$image_tag"
    return $?
  fi
}

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── post_build_menu.sh <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Post-build menu logic for Jetson Container build system (run, verify, skip, etc).
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250423-232231-PSTBM
