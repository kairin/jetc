#!/bin/bash

# COMMIT-TRACKING: UUID-20240729-101500-B4E1
# Description: Script to check and install dialog utility
# Author: GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Buildx directory
# │   └── scripts/               <- Scripts directory
# │       └── check_install_dialog.sh  <- THIS FILE
# └── ...                        <- Other project files

# Function to check if dialog is installed
check_install_dialog() {
  if ! command -v dialog &> /dev/null; then
    echo "Dialog package not found. Installing dialog..." >&2
    if command -v apt-get &> /dev/null; then
      sudo apt-get update -y && sudo apt-get install -y dialog
    elif command -v yum &> /dev/null; then
      sudo yum install -y dialog
    elif command -v dnf &> /dev/null; then
      sudo dnf install -y dialog
    elif command -v pacman &> /dev/null; then
      sudo pacman -S --noconfirm dialog
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

# Run the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  check_install_dialog
  exit $?
fi
