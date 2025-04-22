#!/bin/bash

# =========================================================================
# Function: Check if dialog is installed, optionally install it.
# Returns: 0 if dialog is available, 1 otherwise.
# =========================================================================
check_install_dialog() {
  if ! command -v dialog &> /dev/null; then
    echo "Dialog package not found. Attempting to install..." >&2
    # Try common package managers
    if command -v apt-get &> /dev/null; then
      sudo apt-get update -y && sudo apt-get install -y dialog || { echo "Failed via apt-get." >&2; return 1; }
    elif command -v yum &> /dev/null; then
      sudo yum install -y dialog || { echo "Failed via yum." >&2; return 1; }
    elif command -v dnf &> /dev/null; then
      sudo dnf install -y dialog || { echo "Failed via dnf." >&2; return 1; }
    elif command -v pacman &> /dev/null; then
      sudo pacman -S --noconfirm dialog || { echo "Failed via pacman." >&2; return 1; }
    else
      echo "Could not attempt dialog installation: Unsupported package manager." >&2
      return 1
    fi
    # Verify installation succeeded
    if ! command -v dialog &> /dev/null; then
       echo "Failed to install dialog. Falling back to basic prompts." >&2
       return 1
    fi
    echo "Dialog installed successfully." >&2
  fi
  return 0
}

# =========================================================================
# Function: Get system datetime from Ubuntu 22.04+ or WSL
# Returns: Formatted datetime string as YYYYMMDD-HHMMSS
# =========================================================================
get_system_datetime() {
  # Check if timedatectl is available (systemd-based systems like Ubuntu 22.04+)
  if command -v timedatectl &> /dev/null; then
    # Use timedatectl to get synchronized system time
    local datetime=$(timedatectl show --property=TimeUSec --value 2>/dev/null | cut -d' ' -f1)
    if [ -n "$datetime" ]; then
      # Convert to desired format
      echo $(date -d "@$(echo $datetime | cut -d. -f1)" +"%Y%m%d-%H%M%S")
      return 0
    fi
  fi

  # Fallback to standard date command (works on both WSL and native Ubuntu)
  echo $(date +"%Y%m%d-%H%M%S")
  return 0
}

# =========================================================================
# Function: Setup basic build environment variables (ARCH, PLATFORM, DATE)
# Exports: ARCH, PLATFORM, CURRENT_DATE_TIME
# Returns: 0 on success
# =========================================================================
setup_build_environment() {
  # Detect architecture (default to arm64 for Jetson)
  export ARCH="${ARCH:-arm64}"
  export PLATFORM="${PLATFORM:-linux/arm64}"
  export CURRENT_DATE_TIME="$(get_system_datetime)"
  return 0
}

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── utils.sh           <- THIS FILE
# └── ...                        <- Other project files
#
# Description: General utility functions for dialog, datetime, and system checks.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250422-083100-UTIL
