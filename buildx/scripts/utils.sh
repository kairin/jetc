#!/bin/bash

# Define canonical path for .env file relative to this script's parent directory
export ENV_CANONICAL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.env"

# Initialize SCREENSHOT_TOOL_MISSING (default to true, meaning missing)
export SCREENSHOT_TOOL_MISSING="true" # <-- ADDED INITIALIZATION

# Conditional debug logging (requires logging functions to be sourced *before* calling this)
# Define a minimal version here in case logging.sh/env_setup.sh isn't sourced yet during early calls
_log_debug() {
  if [[ "${JETC_DEBUG}" == "true" || "${JETC_DEBUG}" == "1" ]]; then
    echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - ${FUNCNAME[1]:-utils.sh}: $1" >&2
  fi
}

# =========================================================================
# Function: Check if dialog is installed, optionally install it.
# Returns: 0 if dialog is available, 1 otherwise.
# =========================================================================
check_install_dialog() {
  _log_debug "Checking for 'dialog' command..."
  echo "Checking for 'dialog' command..." >&2
  if (! command -v dialog &> /dev/null); then
    _log_debug "'dialog' not found. Attempting installation..."
    echo "'dialog' not found. Attempting installation..." >&2
    # Try common package managers
    if command -v apt-get &> /dev/null; then
      sudo apt-get update -y && sudo apt-get install -y dialog || { _log_debug "Failed to install dialog via apt-get."; echo "Failed to install dialog via apt-get." >&2; return 1; }
    elif command -v yum &> /dev/null; then
      sudo yum install -y dialog || { _log_debug "Failed to install dialog via yum."; echo "Failed to install dialog via yum." >&2; return 1; }
    elif command -v dnf &> /dev/null; then
      sudo dnf install -y dialog || { _log_debug "Failed to install dialog via dnf."; echo "Failed to install dialog via dnf." >&2; return 1; }
    elif command -v pacman &> /dev/null; then
      sudo pacman -S --noconfirm dialog || { _log_debug "Failed to install dialog via pacman."; echo "Failed to install dialog via pacman." >&2; return 1; }
    else
      _log_debug "Could not attempt dialog installation: Unsupported package manager."
      echo "Could not attempt dialog installation: Unsupported package manager." >&2
      return 1
    fi
    # Verify installation succeeded
    if (! command -v dialog &> /dev/null); then
       _log_debug "Installation command ran, but 'dialog' still not found. Falling back to basic prompts."
       echo "Installation command ran, but 'dialog' still not found. Falling back to basic prompts." >&2
       return 1
    fi
    _log_debug "'dialog' installed successfully."
    echo "'dialog' installed successfully." >&2
  else
    _log_debug "'dialog' command found."
    echo "'dialog' command found." >&2
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
    # Use timedatectl in a simpler, more reliable way
    local datetime=$(timedatectl | grep "Local time" | awk '{print $3" "$4}' 2>/dev/null)
    if [ -n "$datetime" ]; then
      # Convert to desired format using date command with input date string
      echo $(date -d "$datetime" +"%Y%m%d-%H%M%S" 2>/dev/null)
      if [ $? -eq 0 ]; then
        return 0
      fi
    fi
  fi

  # Fallback to standard date command (works on both WSL and native Ubuntu)
  echo $(date +"%Y%m%d-%H%M%S")
  return 0
}

# In /workspaces/jetc/buildx/scripts/utils.sh

# =========================================================================
# Function: Check if scrot is installed, optionally install it.
# Returns: 0 if scrot is available, 1 otherwise.
# Exports: SCREENSHOT_TOOL_MISSING (true/false) - sets it to false on success
# =========================================================================
check_install_screenshot_tool() {
  # SCREENSHOT_TOOL_MISSING is initialized to "true" at the top of the script
  _log_debug "Checking for 'scrot' command..."
  echo "Checking for screenshot tool 'scrot'..." >&2
  if (! command -v scrot &> /dev/null); then
    _log_debug "'scrot' not found. Attempting installation..."
    echo "'scrot' not found. Attempting installation..." >&2
    # Try common package managers
    if command -v apt-get &> /dev/null; then
      sudo apt-get update -y && sudo apt-get install -y scrot || { _log_debug "Failed to install scrot via apt-get."; echo "Failed to install scrot via apt-get." >&2; return 1; }
    elif command -v yum &> /dev/null; then
      sudo yum install -y scrot || { _log_debug "Failed to install scrot via yum."; echo "Failed to install scrot via yum." >&2; return 1; }
    elif command -v dnf &> /dev/null; then
      sudo dnf install -y scrot || { _log_debug "Failed to install scrot via dnf."; echo "Failed to install scrot via dnf." >&2; return 1; }
    elif command -v pacman &> /dev/null; then
      sudo pacman -S --noconfirm scrot || { _log_debug "Failed to install scrot via pacman."; echo "Failed to install scrot via pacman." >&2; return 1; }
    else
      _log_debug "Could not attempt scrot installation: Unsupported package manager."
      echo "Could not attempt scrot installation: Unsupported package manager." >&2
      return 1
    fi
    # Verify installation succeeded
    if (! command -v scrot &> /dev/null); then
       _log_debug "Installation command ran, but 'scrot' still not found."
       echo "Installation command ran, but 'scrot' still not found." >&2
       return 1
    fi
    _log_debug "'scrot' installed successfully."
    echo "'scrot' installed successfully." >&2
  else
    _log_debug "'scrot' command found."
    echo "'scrot' command found." >&2
  fi
  # If we reach here, scrot is available
  export SCREENSHOT_TOOL_MISSING="false" # <-- SET TO FALSE ON SUCCESS
  return 0
}

# Add this call within setup_build_environment or call it early in build.sh
# check_install_screenshot_tool


# In /workspaces/jetc/buildx/scripts/utils.sh

# =========================================================================
# Function: Capture a screenshot if scrot is available
# Arguments: $1 = Descriptive name suffix (e.g., "step0_docker_info")
# Returns: 0 on success or if tool missing, 1 on error during capture
# =========================================================================
capture_screenshot() {
    local name_suffix="$1"
    # Check if the tool is available (using the exported variable)
    if [[ "${SCREENSHOT_TOOL_MISSING}" == "true" ]]; then
        _log_debug "Screenshot tool missing, skipping capture for '$name_suffix'."
        return 0 # Skip silently if tool is missing
    fi

    # Define screenshot directory relative to the script's parent (buildx/)
    local screenshot_dir
    screenshot_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/screenshots"
    mkdir -p "$screenshot_dir" || {
        _log_debug "Failed to create screenshot directory: $screenshot_dir"
        echo "Warning: Failed to create screenshot directory: $screenshot_dir" >&2
        return 1 # Return error if directory creation fails
    }

    local timestamp
    timestamp=$(date +"%Y%m%d-%H%M%S")
    local filename="${screenshot_dir}/screenshot_${name_suffix}_${timestamp}.png"

    _log_debug "Capturing screenshot: $filename"
    # Add a small delay to ensure the dialog is fully rendered (optional)
    # sleep 0.5
    if scrot "$filename"; then
        _log_debug "Screenshot captured successfully."
        return 0
    else
        _log_debug "Failed to capture screenshot using scrot."
        echo "Warning: Failed to capture screenshot: $filename" >&2
        return 1 # Return error if scrot command fails
    fi
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

# =========================================================================
# Function: Get and store the current datetime for reference across the app
# =========================================================================
store_current_datetime() {
  export JETC_RUN_DATETIME="$(date +"%Y-%m-%d %H:%M:%S")"
  echo "$JETC_RUN_DATETIME"
}



# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── utils.sh           <- THIS FILE
# └── ...                        <- Other project files
#
# Description: General utility functions. Centralized ENV_CANONICAL definition. Added _log_debug. Initialized SCREENSHOT_TOOL_MISSING.
# Author: Mr K / GitHub Copilot / kairin
# COMMIT-TRACKING: UUID-20250424-194340-UNBOUNDFIX
