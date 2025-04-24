#!/bin/bash

# Define colors for output (used by check functions)
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# =========================================================================
# Function: Check if a command exists and print its version (Internal use)
# =========================================================================
_check_cmd() {
  local cmd=$1
  local desc=${2:-$cmd}

  if command -v $cmd &> /dev/null; then
    version=$($cmd --version 2>&1 | head -n 1 || echo "version info unavailable")
    echo -e "${GREEN}✅ $desc:${NC} $version"
    return 0
  else
    echo -e "${RED}❌ $desc:${NC} Not installed"
    return 1
  fi
}

# =========================================================================
# Function: Check if a Python package is installed (Internal use)
# =========================================================================
_check_python_pkg() {
  local pkg_name=$1
  local import_name=${2:-$pkg_name} # Allow different import name if needed

  # Try python3 first, then python
  local python_cmd="python3"
  if ! command -v $python_cmd &> /dev/null; then
      python_cmd="python"
      if ! command -v $python_cmd &> /dev/null; then
          echo -e "${RED}❌ Python interpreter not found.${NC}"
          return 1
      fi
  fi

  if $python_cmd -c "import $import_name" &> /dev/null; then
    version=$($python_cmd -c "import $import_name; print(getattr($import_name, '__version__', 'version unknown'))" 2>/dev/null || echo "version unknown")
    echo -e "${GREEN}✅ Python $pkg_name:${NC} $version"
    return 0
  else
    echo -e "${RED}❌ Python $pkg_name:${NC} Not installed or import failed"
    return 1
  fi
}

# =========================================================================
# Function: Check common system tools (Internal use)
# =========================================================================
_check_system_tools() {
  echo -e "\n${BLUE}🔧 System Tools:${NC}"
  _check_cmd bash "Bash shell"
  _check_cmd ls "File listing"
  _check_cmd grep "Text search"
  _check_cmd awk "Text processing"
  _check_cmd sed "Stream editor"
  _check_cmd curl "URL transfer tool"
  _check_cmd wget "Download utility"
  _check_cmd git "Git version control"
  _check_cmd python3 "Python 3" || _check_cmd python "Python"
  _check_cmd pip3 "Pip 3" || _check_cmd pip "Pip"
  _check_cmd nvcc "NVIDIA CUDA Compiler"
  _check_cmd gcc "C Compiler"
  _check_cmd g++ "C++ Compiler"
  _check_cmd make "Make utility"
  _check_cmd cmake "CMake build system"
}

# =========================================================================
# Function: Check ML/AI frameworks (Internal use)
# =========================================================================
_check_ml_frameworks() {
  echo -e "\n${BLUE}🧠 ML/AI Frameworks:${NC}"
  _check_python_pkg torch
  _check_python_pkg tensorflow
  _check_python_pkg jax
  _check_python_pkg keras
}

# =========================================================================
# Function: Check common libraries (Internal use)
# =========================================================================
_check_libraries() {
  echo -e "\n${BLUE}📚 Libraries and Utilities:${NC}"
  _check_python_pkg numpy
  _check_python_pkg scipy
  _check_python_pkg pandas
  _check_python_pkg matplotlib
  _check_python_pkg sklearn "scikit-learn" # Use common name
  _check_python_pkg cv2 "OpenCV"
  _check_python_pkg transformers
  _check_python_pkg diffusers
  _check_python_pkg huggingface_hub
}

# =========================================================================
# Function: Check CUDA/GPU information (Internal use)
# =========================================================================
_check_cuda_info() {
  echo -e "\n${BLUE}🖥️ CUDA/GPU Information:${NC}"
  if _check_python_pkg torch >/dev/null; then # Check if torch exists first
    local python_cmd="python3"
    command -v $python_cmd &> /dev/null || python_cmd="python"
    if command -v $python_cmd &> /dev/null; then
        echo -e "PyTorch CUDA available: $($python_cmd -c "import torch; print('${GREEN}Yes${NC}' if torch.cuda.is_available() else '${RED}No${NC}')")"
        if $python_cmd -c "import torch; exit(0 if torch.cuda.is_available() else 1)"; then
          echo "CUDA Device count: $($python_cmd -c "import torch; print(torch.cuda.device_count())")"
          echo "CUDA Version (PyTorch): $($python_cmd -c "import torch; print(torch.version.cuda)")"
        fi
    fi
  fi
  # Check nvidia-smi if available
  if command -v nvidia-smi &> /dev/null; then
      echo -e "${GREEN}✅ nvidia-smi found.${NC} Driver/GPU info:"
      nvidia-smi --query-gpu=gpu_name,driver_version,cuda_version --format=csv,noheader
  else
      echo -e "${YELLOW}ℹ️ nvidia-smi not found (may be normal if only runtime libs are installed).${NC}"
  fi
}

# =========================================================================
# Function: List all installed system packages (Internal use)
# =========================================================================
_list_system_packages() {
  echo -e "\n${BLUE}📦 All Installed System Packages:${NC}"
  if command -v dpkg &> /dev/null; then
    echo -e "${YELLOW}Detected dpkg (Debian/Ubuntu-based system).${NC}"
    dpkg-query -W -f='${binary:Package}\t${Version}\n' | sort
  elif command -v rpm &> /dev/null; then
    echo -e "${YELLOW}Detected rpm (RHEL/CentOS-based system).${NC}"
    rpm -qa --qf "%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n" | sort
  elif command -v apk &> /dev/null; then
    echo -e "${YELLOW}Detected apk (Alpine-based system).${NC}"
    apk info -v | sort
  else
    echo -e "${RED}Unknown package manager. Cannot list all system packages.${NC}"
    return 1
  fi
  return 0
}

# =========================================================================
# Function: List Python packages (Internal use)
# =========================================================================
_list_python_packages() {
  echo -e "\n${BLUE}🐍 Installed Python Packages:${NC}"
  local pip_cmd="pip3"
  if ! command -v $pip_cmd &> /dev/null; then
      pip_cmd="pip"
      if ! command -v $pip_cmd &> /dev/null; then
          echo -e "${RED}pip/pip3 not found. Cannot list Python packages.${NC}"
          return 1
      fi
  fi
  $pip_cmd list
  return 0
}

# =========================================================================
# Function: List installed applications detected by checks (Internal use)
# Arguments: None (runs all checks internally)
# Returns: List of detected app names, one per line
# =========================================================================
_list_installed_apps() {
  echo -e "${CYAN}--- Detecting Installed Applications ---${NC}"
  # Run checks silently and capture output
  local output
  output=$( (
    _check_system_tools
    _check_ml_frameworks
    _check_libraries
    _check_cuda_info
  ) 2>&1 ) # Capture stdout and stderr

  # Extract app names from lines containing the checkmark
  echo "$output" | grep -Eo '✅ [^:]+:' | sed 's/✅ //;s/://' | sort -u
}

# =========================================================================
# Main verification function called inside the container
# Arguments: $1 = mode (all, quick, tools, ml, libs, cuda, python, system, list_apps)
# =========================================================================
run_verification_checks() {
  local mode=${1:-quick} # Default to quick check

  echo -e "${BLUE}=========================================${NC}"
  echo -e "${BLUE} Running Verification Checks (Mode: $mode)${NC}"
  echo -e "${BLUE}=========================================${NC}"

  case "$mode" in
    all)
      _check_system_tools
      _check_ml_frameworks
      _check_libraries
      _check_cuda_info
      _list_system_packages # List all system packages
      _list_python_packages # List all python packages
      ;;
    quick)
      _check_system_tools
      _check_ml_frameworks
      _check_libraries
      _check_cuda_info
      ;;
    tools) _check_system_tools ;;
    ml) _check_ml_frameworks ;;
    libs) _check_libraries ;;
    cuda) _check_cuda_info ;;
    python) _list_python_packages ;;
    system) _list_system_packages ;;
    list_apps) _list_installed_apps ;; # New mode to just list apps
    *)
      echo -e "${RED}Error: Invalid verification mode '$mode'. Valid modes: all, quick, tools, ml, libs, cuda, python, system, list_apps.${NC}"
      return 1
      ;;
  esac

  echo -e "${BLUE}=========================================${NC}"
  echo -e "${BLUE} Verification Checks Complete (Mode: $mode)${NC}"
  echo -e "${BLUE}=========================================${NC}"
  return 0
}

# =========================================================================
# Function: Run verification checks or list apps inside a target container image
# Arguments: $1 = image tag, $2 = verification mode (optional, default: quick)
# Returns: Exit status of the verification script inside the container
# =========================================================================
verify_container_apps() {
  local image_tag=$1
  local mode=${2:-quick} # Default to quick verification

  if [[ -z "$image_tag" ]]; then
    echo -e "${RED}Error: No image tag provided to verify_container_apps.${NC}"
    return 1
  fi

  # Check if image exists locally
  if ! docker image inspect "$image_tag" &>/dev/null; then
    echo -e "${YELLOW}Warning: Image '$image_tag' not found locally. Cannot run verification.${NC}"
    return 1
  fi

  echo -e "${BLUE}--- Running Verification (Mode: $mode) in container: $image_tag ---${NC}"

  # Copy this script into the container temporarily
  local container_id
  container_id=$(docker create "$image_tag")
  if [ -z "$container_id" ]; then
      echo -e "${RED}Error: Failed to create temporary container for verification.${NC}"
      return 1
  fi

  # Ensure the /tmp directory exists in the container (should always be true)
  docker cp "$0" "${container_id}:/tmp/verify_apps.sh"
  if [ $? -ne 0 ]; then
      echo -e "${RED}Error: Failed to copy verification script into container.${NC}"
      docker rm -f "$container_id" &>/dev/null
      return 1
  fi

  # Run the script inside the container
  # Use docker exec on a running container, or docker run --rm for a one-off
  # Using docker run --rm is simpler here
  docker run --rm --gpus all -v "/tmp/verify_apps.sh:/tmp/verify_apps.sh:ro" "$image_tag" bash /tmp/verify_apps.sh run_checks "$mode"
  local exit_status=$?

  # Clean up the temporary container created earlier if needed (docker run --rm handles this)
  # docker rm -f "$container_id" &>/dev/null

  if [ $exit_status -ne 0 ]; then
    echo -e "${RED}--- Verification (Mode: $mode) failed in container: $image_tag (Exit code: $exit_status) ---${NC}"
  else
    echo -e "${GREEN}--- Verification (Mode: $mode) completed successfully in container: $image_tag ---${NC}"
  fi

  return $exit_status
}

# =========================================================================
# Function: List installed apps inside a target container image
# Arguments: $1 = image tag
# Returns: Prints list of apps to stdout, returns 0 on success, 1 on failure
# =========================================================================
list_installed_apps() {
    local image_tag=$1
    verify_container_apps "$image_tag" "list_apps" # Use the new mode
    return $?
}

# =========================================================================
# Entry point when script is executed directly (e.g., inside container)
# =========================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Only print usage and exit if executed directly, not when sourced or called as a function
    if [[ "$1" == "run_checks" ]]; then
        run_verification_checks "$2" # Pass the mode (e.g., quick, all)
        exit $?
    else
        echo "This script is intended to be run inside a Docker container via 'verify_container_apps' or 'list_installed_apps'." >&2
        echo "Usage (within container): /tmp/verify_apps.sh run_checks [mode]" >&2
        exit 1
    fi
fi

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── verification.sh    <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Verification functions for checking installed apps and packages in Jetson containers.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20240806-103000-MODULAR # Updated UUID to match refactor

# =========================================================================
# Image Verification and Pulling Script
# Responsibility: Verify local image existence and pull images from registry.
# =========================================================================

# --- Dependencies ---
SCRIPT_DIR_VERIFY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source required scripts (use fallbacks if sourcing fails)
if [ -f "$SCRIPT_DIR_VERIFY/env_setup.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_VERIFY/env_setup.sh"
else
    echo "Warning: env_setup.sh not found. Logging/colors may be basic." >&2
    log_info() { echo "INFO: $1"; }
    log_warning() { echo "WARNING: $1" >&2; }
    log_error() { echo "ERROR: $1" >&2; }
    log_success() { echo "SUCCESS: $1"; }
    log_debug() { :; }
fi

# --- Functions --- #

# Verify if a Docker image exists locally
# Input: $1 = image_tag (full tag, e.g., user/repo:tag)
# Return: 0 if image exists locally, 1 otherwise.
verify_image_locally() {
    local image_tag="$1"
    if [ -z "$image_tag" ]; then
        log_error "verify_image_locally: No image tag provided."
        return 1
    fi

    log_debug "Checking for local image: $image_tag"
    if docker image inspect "$image_tag" >/dev/null 2>&1; then
        log_debug " -> Image found locally: $image_tag"
        return 0
    else
        log_debug " -> Image not found locally: $image_tag"
        return 1
    fi
}

# Pull a Docker image from the registry
# Input: $1 = image_tag (full tag, e.g., user/repo:tag)
# Return: 0 on successful pull, 1 on failure.
pull_image() {
    local image_tag="$1"
    if [ -z "$image_tag" ]; then
        log_error "pull_image: No image tag provided."
        return 1
    fi

    log_info "Attempting to pull image: $image_tag"
    if docker pull "$image_tag"; then
        log_success " -> Successfully pulled image: $image_tag"
        # Optionally, verify again locally after pull
        if verify_image_locally "$image_tag"; then
            return 0
        else
            log_error " -> Pulled image '$image_tag' but could not verify it locally immediately."
            return 1
        fi
    else
        log_error " -> Failed to pull image: $image_tag"
        log_error "    Check image tag, registry access, and network connection."
        return 1
    fi
}

# --- Main Execution (for testing) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_info "Running verification.sh directly for testing..."

    # Test Case 1: Verify a common image (likely exists or is easily pulled)
    test_image_1="ubuntu:22.04"
    log_info "Test 1: Verifying/Pulling '$test_image_1'"
    if verify_image_locally "$test_image_1"; then
        log_success " -> '$test_image_1' exists locally."
    else
        log_info " -> '$test_image_1' not found locally. Attempting pull..."
        if pull_image "$test_image_1"; then
            log_success " -> Pull successful for '$test_image_1'."
        else
            log_error " -> Pull failed for '$test_image_1'."
        fi
    fi

    # Test Case 2: Verify a non-existent image
    test_image_2="nonexistent-repo/nonexistent-image:latest-$(date +%s)"
    log_info "Test 2: Verifying '$test_image_2' (expected not found)"
    if verify_image_locally "$test_image_2"; then
        log_warning " -> '$test_image_2' unexpectedly found locally."
    else
        log_success " -> '$test_image_2' correctly not found locally."
    fi

    # Test Case 3: Attempt to pull a non-existent image
    log_info "Test 3: Attempting to pull '$test_image_2' (expected failure)"
    if pull_image "$test_image_2"; then
        log_error " -> Pull unexpectedly succeeded for '$test_image_2'."
    else
        log_success " -> Pull correctly failed for '$test_image_2'."
    fi

    log_info "Verification script test finished."
    exit 0
fi

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── verification.sh    <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Provides functions to verify local Docker image existence and pull images from a registry.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-093000-VERIFY
