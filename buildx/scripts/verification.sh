#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/verification.sh

# =========================================================================
# Verification Script
# Responsibility: Run checks inside a built container image.
#                 Includes host-side function to launch the container
#                 and self-contained functions to run inside.
# =========================================================================

# --- Host-Side Dependencies (Only for run_container_verification) ---
# Assumes logging.sh, env_setup.sh, docker_helpers.sh are sourced by the main build.sh
SCRIPT_DIR_VERIFY="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# =========================================================================
# Host-Side Function: Run verification script inside a container
# Arguments: $1 = Image Tag, $2 = Verification Mode (e.g., "basic", "python", "all")
# Returns: 0 on success, 1 on failure
# =========================================================================
run_container_verification() {
    local image_tag="$1"
    local mode="${2:-all}" # Default to 'all' mode if not specified

    # --- Host-Side Checks ---
    # Ensure required host functions exist
    if ! declare -f log_info > /dev/null || ! declare -f verify_image_exists > /dev/null; then
        echo "ERROR (verification.sh): Required host functions (log_info, verify_image_exists) not found." >&2
         return 1
    fi

    log_info "Running full verification for $image_tag..."

    # Verify image exists locally before trying to run it
    if ! verify_image_exists "$image_tag"; then
        log_error "Image '$image_tag' not found locally. Cannot run verification."
        return 1
    fi

    # --- Container Execution ---
    log_info "--- Running Verification (Mode: $mode) in container: $image_tag ---"

    # Copy this script itself into a temporary file to mount into the container
    local temp_script
    temp_script=$(mktemp --suffix=_verify.sh) || { log_error "Failed to create temp script file"; return 1; }
    trap 'rm -f "$temp_script"' RETURN # Cleanup temp file on function return

    # Copy the ENTIRE content of this script file to the temp file
    # This ensures the _run_verification_in_container and helper functions are available inside
    cat "${BASH_SOURCE[0]}" > "$temp_script"
    chmod +x "$temp_script"

    # Run the container, mounting the temp script and executing the internal function
    # Use --rm for automatic cleanup, run non-interactively (-t can cause issues)
    # Mount the script to /tmp/verify.sh inside the container
    # Execute bash /tmp/verify.sh with the internal function name and mode as arguments
    if docker run --rm \
        --gpus all \
        -v "$temp_script:/tmp/verify.sh" \
        "$image_tag" \
        bash /tmp/verify.sh _run_verification_in_container "$mode"; then
        log_success "Container verification completed successfully for $image_tag (Mode: $mode)."
        return 0
    else
        log_error "Container verification failed for $image_tag (Mode: $mode)."
        return 1
    fi
}


# =========================================================================
# =========================================================================
# == Functions Below This Line Run INSIDE The Container ==
# =========================================================================
# =========================================================================

# --- Self-Contained Helper Functions (for inside container) ---

# Define colors locally for container use
V_RED='\033[0;31m'
V_GREEN='\033[0;32m'
V_YELLOW='\033[1;33m'
V_BLUE='\033[0;34m'
V_NC='\033[0m' # No Color

# Basic echo replacements for logging inside container
_v_echo_info() { echo -e "${V_BLUE}INFO:${V_NC} $1"; }
_v_echo_success() { echo -e "${V_GREEN}SUCCESS:${V_NC} $1"; }
_v_echo_warning() { echo -e "${V_YELLOW}WARNING:${V_NC} $1" >&2; }
_v_echo_error() { echo -e "${V_RED}ERROR:${V_NC} $1" >&2; }

# --- Verification Check Functions (Run inside container) ---

# Check basic OS info
_check_os() {
  echo "--- OS Information ---"
  if [ -f /etc/os-release ]; then
    # Use awk for safer parsing than source
    cat /etc/os-release | awk -F= '/^(NAME|VERSION|ID|PRETTY_NAME)=/{gsub(/"/, "", $2); print $1 "=" $2}'
  else
    echo "Cannot find /etc/os-release"
  fi
  echo "Architecture: $(uname -m)"
  echo "--------------------"
}

# Check if a command exists
_check_command() {
  local cmd=$1
  if command -v "$cmd" &> /dev/null; then
    echo -e "${V_GREEN}✅ Command '$cmd':${V_NC} Found ($(command -v "$cmd"))"
    return 0
  else
    echo -e "${V_RED}❌ Command '$cmd':${V_NC} Not Found"
    return 1
  fi
}

# Check Python package existence and version
_check_python_pkg() {
  local pkg_name=$1
  local import_name=${2:-$pkg_name} # Use pkg_name for import if $2 not given
  local python_cmd="python3" # Default to python3

  # Find available python interpreter
  command -v $python_cmd &> /dev/null || python_cmd="python"
  if ! command -v $python_cmd &> /dev/null; then
      echo -e "${V_RED}❌ Python interpreter ('python3' or 'python') not found.${V_NC}"
      return 1 # Critical failure if no python
  fi

  # Try importing the package
  if $python_cmd -c "import $import_name" &> /dev/null; then
    # Try getting version, handle potential errors
    version=$($python_cmd -c "import $import_name; print(getattr($import_name, '__version__', 'version unknown'))" 2>/dev/null || echo "import ok, version check failed")
    echo -e "${V_GREEN}✅ Python '$pkg_name':${V_NC} $version"
    return 0
  else
    echo -e "${V_RED}❌ Python '$pkg_name':${V_NC} Not installed or import failed"
    return 1
  fi
}


# Check environment variables
_check_env_vars() {
    echo "--- Environment Variables ---"
    # List specific important variables, avoid dumping everything
    echo "PATH=$PATH"
    echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-<unset>}"
    echo "PYTHONPATH=${PYTHONPATH:-<unset>}"
    echo "DEBIAN_FRONTEND=${DEBIAN_FRONTEND:-<unset>}"
    echo "LANG=${LANG:-<unset>}"
    # Add others as needed
    echo "---------------------------"
}

# List installed packages (basic example for apt)
_list_packages() {
    echo "--- Installed Packages (apt) ---"
    if command -v dpkg &> /dev/null; then
        dpkg -l | tail -n +6 # Show list without header
    else
        echo "dpkg command not found, cannot list apt packages."
    fi
    echo "--------------------------------"
    echo "--- Installed Python Packages (pip) ---"
    local python_cmd="python3"
    command -v $python_cmd &> /dev/null || python_cmd="python"
    if command -v $python_cmd &> /dev/null && $python_cmd -m pip --version &> /dev/null; then
         $python_cmd -m pip list
    else
         echo "pip not found or not functional for $python_cmd."
    fi
     echo "---------------------------------------"
}


# =========================================================================
# Main Verification Function (Runs inside container)
# Arguments: $1 = Verification Mode ("basic", "python", "all")
# Returns: 0 on success, 1 if any check fails
# =========================================================================
_run_verification_in_container() {
    local mode="${1:-all}"
    local overall_status=0 # 0 = success, 1 = failure

    echo "========================================="
    echo " Running Verification Checks (Mode: $mode)"
    echo "========================================="

    # --- Basic Checks (Always Run) ---
    if [[ "$mode" == "basic" || "$mode" == "all" ]]; then
        _v_echo_info "Running Basic Checks..."
        _check_os
        _check_command "bash" || overall_status=1
        _check_command "curl" || overall_status=1
        _check_command "git" || overall_status=1
        _check_env_vars
    fi

    # --- Python Checks ---
    if [[ "$mode" == "python" || "$mode" == "all" ]]; then
        _v_echo_info "Running Python Checks..."
        if _check_command "python3"; then
             _check_python_pkg "pip" "__main__" # Check pip itself
             _check_python_pkg "numpy" || overall_status=1
             _check_python_pkg "torch" || overall_status=1
             _check_python_pkg "torchvision" || overall_status=1
             _check_python_pkg "torchaudio" || overall_status=1
             # Add more critical python packages here
             _check_python_pkg "cv2" "cv2" || overall_status=1 # OpenCV python binding
        else
             overall_status=1 # Fail if python3 command missing
        fi
    fi

    # --- Full Checks ---
     if [[ "$mode" == "all" ]]; then
         _v_echo_info "Running Full Package Listing..."
         _list_packages # Don't fail build based on listing
     fi

    echo "========================================="
    if [[ $overall_status -eq 0 ]]; then
        echo " Verification Checks Complete (Mode: $mode) - SUCCESS"
        echo "========================================="
        exit 0
    else
        echo " Verification Checks Complete (Mode: $mode) - FAILED"
        echo "========================================="
        exit 1
    fi
}

# =========================================================================
# Script Entry Point Logic (Handles being called by host or directly)
# =========================================================================
# Check if the first argument is the internal function name
 if [[ "${1:-}" == "_run_verification_in_container" ]]; then
    # Call the internal function with the mode argument ($2)
    _run_verification_in_container "${2:-all}"
     exit $? # Exit with the status of the internal function
 fi

 # --- Host-Side Main Execution (for testing run_container_verification) ---
 if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script is intended to be sourced or called by other scripts."
    echo "To test verification, use the main build script or call run_container_verification <image_tag> [mode]."
     exit 0
 fi


# --- Footer ---
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── verification.sh    <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Functions for verifying system state and Docker image properties.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250425-080000-42595D
