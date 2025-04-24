#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/verification.sh

# =========================================================================
# Container Verification Script
# Responsibility: Functions to check installed apps/packages INSIDE a container.
#                 Also includes functions to LAUNCH these checks FROM the host.
# =========================================================================

# --- Dependencies ---
SCRIPT_DIR_VERIFY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source required scripts for logging (used by launcher functions)
if [ -f "$SCRIPT_DIR_VERIFY/env_setup.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_VERIFY/env_setup.sh"
else
    # Minimal fallback for launcher functions if env_setup is missing
    echo "Warning: env_setup.sh not found. Logging/colors may be basic." >&2
    log_info() { echo "INFO: $1"; }
    log_warning() { echo "WARNING: $1" >&2; }
    log_error() { echo "ERROR: $1" >&2; }
    log_success() { echo "SUCCESS: $1"; }
    log_debug() { :; }
fi
# Source docker_helpers for verify_image_exists (used by launcher functions)
if [ -f "$SCRIPT_DIR_VERIFY/docker_helpers.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_VERIFY/docker_helpers.sh"
else
    log_error "docker_helpers.sh not found. Verification launchers will fail."
    verify_image_exists() { log_error "verify_image_exists: docker_helpers.sh not loaded"; return 1; }
fi


# --- Internal Check Functions (Run INSIDE Container) ---
# These use direct echo with colors because they run isolated inside the container.

# Define colors for output (used by internal check functions)
V_GREEN='\033[0;32m'
V_RED='\033[0;31m'
V_YELLOW='\033[1;33m'
V_BLUE='\033[0;34m'
V_CYAN='\033[0;36m'
V_NC='\033[0m' # No Color

_check_cmd() {
  local cmd=$1
  local desc=${2:-$cmd}
  if command -v $cmd &> /dev/null; then
    version=$($cmd --version 2>&1 | head -n 1 || echo "version info unavailable")
    echo -e "${V_GREEN}✅ $desc:${V_NC} $version"
    return 0
  else
    echo -e "${V_RED}❌ $desc:${V_NC} Not installed"
    return 1
  fi
}

_check_python_pkg() {
  local pkg_name=$1
  local import_name=${2:-$pkg_name}
  local python_cmd="python3"
  command -v $python_cmd &> /dev/null || python_cmd="python"
  if ! command -v $python_cmd &> /dev/null; then echo -e "${V_RED}❌ Python interpreter not found.${V_NC}"; return 1; fi
  if $python_cmd -c "import $import_name" &> /dev/null; then
    version=$($python_cmd -c "import $import_name; print(getattr($import_name, '__version__', 'version unknown'))" 2>/dev/null || echo "version unknown")
    echo -e "${V_GREEN}✅ Python $pkg_name:${V_NC} $version"
    return 0
  else
    echo -e "${V_RED}❌ Python $pkg_name:${V_NC} Not installed or import failed"
    return 1
  fi
}

_check_system_tools() {
  echo -e "\n${V_BLUE}🔧 System Tools:${V_NC}"
  _check_cmd bash; _check_cmd ls; _check_cmd grep; _check_cmd awk; _check_cmd sed;
  _check_cmd curl; _check_cmd wget; _check_cmd git;
  _check_cmd python3 || _check_cmd python;
  _check_cmd pip3 || _check_cmd pip;
  _check_cmd nvcc; _check_cmd gcc; _check_cmd g++; _check_cmd make; _check_cmd cmake;
}

_check_ml_frameworks() {
  echo -e "\n${V_BLUE}🧠 ML/AI Frameworks:${V_NC}"
  _check_python_pkg torch; _check_python_pkg tensorflow; _check_python_pkg jax; _check_python_pkg keras;
}

_check_libraries() {
  echo -e "\n${V_BLUE}📚 Libraries and Utilities:${V_NC}"
  _check_python_pkg numpy; _check_python_pkg scipy; _check_python_pkg pandas;
  _check_python_pkg matplotlib; _check_python_pkg sklearn "scikit-learn";
  _check_python_pkg cv2 "OpenCV"; _check_python_pkg transformers;
  _check_python_pkg diffusers; _check_python_pkg huggingface_hub;
}

_check_cuda_info() {
  echo -e "\n${V_BLUE}🖥️ CUDA/GPU Information:${V_NC}"
  if _check_python_pkg torch >/dev/null; then
    local python_cmd="python3"; command -v $python_cmd &> /dev/null || python_cmd="python"
    if command -v $python_cmd &> /dev/null; then
      echo -e "PyTorch CUDA available: $($python_cmd -c "import torch; print('${V_GREEN}Yes${V_NC}' if torch.cuda.is_available() else '${V_RED}No${V_NC}')")"
      if $python_cmd -c "import torch; exit(0 if torch.cuda.is_available() else 1)"; then
        echo "CUDA Device count: $($python_cmd -c "import torch; print(torch.cuda.device_count())")"
        echo "CUDA Version (PyTorch): $($python_cmd -c "import torch; print(torch.version.cuda)")"
      fi
    fi
  fi
  if command -v nvidia-smi &> /dev/null; then
    echo -e "${V_GREEN}✅ nvidia-smi found.${V_NC} Driver/GPU info:"
    nvidia-smi --query-gpu=gpu_name,driver_version,cuda_version --format=csv,noheader || echo -e "${V_RED}nvidia-smi query failed${V_NC}"
  else
    echo -e "${V_YELLOW}ℹ️ nvidia-smi not found (may be normal if only runtime libs are installed).${V_NC}"
  fi
}

_list_system_packages() {
  echo -e "\n${V_BLUE}📦 All Installed System Packages:${V_NC}"
  if command -v dpkg &> /dev/null; then echo -e "${V_YELLOW}dpkg packages:${V_NC}"; dpkg-query -W -f='${binary:Package}\t${Version}\n' | sort;
  elif command -v rpm &> /dev/null; then echo -e "${V_YELLOW}rpm packages:${V_NC}"; rpm -qa --qf "%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n" | sort;
  elif command -v apk &> /dev/null; then echo -e "${V_YELLOW}apk packages:${V_NC}"; apk info -v | sort;
  else echo -e "${V_RED}Unknown package manager.${V_NC}"; return 1; fi
  return 0
}

_list_python_packages() {
  echo -e "\n${V_BLUE}🐍 Installed Python Packages:${V_NC}"
  local pip_cmd="pip3"; command -v $pip_cmd &> /dev/null || pip_cmd="pip"
  if ! command -v $pip_cmd &> /dev/null; then echo -e "${V_RED}pip/pip3 not found.${V_NC}"; return 1; fi
  $pip_cmd list
  return 0
}

_list_installed_apps() {
  echo -e "${V_CYAN}--- Detecting Installed Applications ---${V_NC}"
  local output; output=$( (_check_system_tools; _check_ml_frameworks; _check_libraries; _check_cuda_info) 2>&1 )
  echo "$output" | grep -Eo '✅ [^:]+:' | sed 's/✅ //;s/://' | sort -u
}

# Main internal verification function called INSIDE the container
run_verification_checks() {
  local mode=${1:-quick}
  echo -e "${V_BLUE}=========================================${V_NC}"
  echo -e "${V_BLUE} Running Verification Checks (Mode: $mode)${V_NC}"
  echo -e "${V_BLUE}=========================================${V_NC}"
  case "$mode" in
    all) _check_system_tools; _check_ml_frameworks; _check_libraries; _check_cuda_info; _list_system_packages; _list_python_packages ;;
    quick) _check_system_tools; _check_ml_frameworks; _check_libraries; _check_cuda_info ;;
    tools) _check_system_tools ;;
    ml) _check_ml_frameworks ;;
    libs) _check_libraries ;;
    cuda) _check_cuda_info ;;
    python) _list_python_packages ;;
    system) _list_system_packages ;;
    list_apps) _list_installed_apps ;;
    *) echo -e "${V_RED}Error: Invalid verification mode '$mode'.${V_NC}"; return 1 ;;
  esac
  local exit_code=$?
  echo -e "${V_BLUE}=========================================${V_NC}"
  echo -e "${V_BLUE} Verification Checks Complete (Mode: $mode)${V_NC}"
  echo -e "${V_BLUE}=========================================${V_NC}"
  return $exit_code
}


# --- Launcher Functions (Run on Host) ---
# These use log_* functions from env_setup.sh

# Run verification checks or list apps inside a target container image
verify_container_apps() {
  local image_tag=$1
  local mode=${2:-quick}

  if [[ -z "$image_tag" ]]; then
    log_error "No image tag provided to verify_container_apps."
    return 1
  fi

  # Use verify_image_exists from docker_helpers.sh
  if ! verify_image_exists "$image_tag"; then
    log_warning "Image '$image_tag' not found locally. Cannot run verification."
    return 1
  fi

  log_info "--- Running Verification (Mode: $mode) in container: $image_tag ---"

  # Define path inside container for this script
  local container_script_path="/tmp/verify_apps.sh"

  # Use docker run with volume mount to execute this script inside the container
  # Mount this script file itself into the container (read-only)
  # Use --entrypoint to override default CMD/ENTRYPOINT
  # Execute the run_verification_checks function within the container context
  docker run --rm --gpus all \
    -v "${BASH_SOURCE[0]}":"$container_script_path":ro \
    --entrypoint /bin/bash \
    "$image_tag" \
    "$container_script_path" "run_checks" "$mode" # Pass args to script

  local exit_status=$?

  if [ $exit_status -ne 0 ]; then
    log_error "--- Verification (Mode: $mode) failed in container: $image_tag (Exit code: $exit_status) ---"
  else
    log_success "--- Verification (Mode: $mode) completed successfully in container: $image_tag ---"
  fi

  return $exit_status
}

# List installed apps inside a target container image
list_installed_apps() {
    local image_tag=$1
    log_info "Listing installed applications in: $image_tag"
    verify_container_apps "$image_tag" "list_apps" # Use the dedicated mode
    return $?
}

# --- REMOVED DUPLICATE FUNCTIONS ---
# The following functions are defined in docker_helpers.sh and were removed from here:
# - verify_image_locally (use verify_image_exists from docker_helpers.sh)
# - pull_image

# --- Main Execution (Entry point when script is executed directly) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # If called with "run_checks", execute the internal function (for container execution)
    if [[ "$1" == "run_checks" ]]; then
        run_verification_checks "$2" # Pass the mode (e.g., quick, all)
        exit $?
    else
        # If executed directly without "run_checks", show usage for host functions
        echo "This script provides functions to run checks inside containers." >&2
        echo "Usage (source the script first):" >&2
        echo "  verify_container_apps <image_tag> [mode]" >&2
        echo "  list_installed_apps <image_tag>" >&2
        echo "Modes: all, quick, tools, ml, libs, cuda, python, system, list_apps" >&2
        exit 1
    fi
fi

# --- Footer ---
# File location diagram: ... (omitted)
# Description: Verification functions for checking installed apps/packages in Jetson containers.
#              Removed duplicate function definitions. Uses env_setup for host logging.
# Author: Mr K / GitHub Copilot / kairin
# COMMIT-TRACKING: UUID-20250424-203535-VERIFYCLEANUP
