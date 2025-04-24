#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/verification.sh

# =========================================================================
# Container Verification Script
# Responsibility: Functions to check installed apps/packages INSIDE a container,
#                 and functions to LAUNCH these checks FROM the host.
# =========================================================================

# --- Dependencies ---
SCRIPT_DIR_VERIFY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies ONLY IF they are needed by host functions AND might not be sourced by main script yet.
# Check if functions exist before sourcing, assuming main script handles primary sourcing.
if ! declare -f log_info > /dev/null; then
    echo "Warning: log_info not found in verification.sh, sourcing logging.sh for host functions." >&2
     if [ -f "$SCRIPT_DIR_VERIFY/logging.sh" ]; then source "$SCRIPT_DIR_VERIFY/logging.sh"; init_logging; else echo "ERROR: Cannot find logging.sh."; fi
fi
if ! declare -f verify_image_exists > /dev/null; then
    echo "Warning: verify_image_exists not found in verification.sh, sourcing docker_helpers.sh for host functions." >&2
     if [ -f "$SCRIPT_DIR_VERIFY/docker_helpers.sh" ]; then source "$SCRIPT_DIR_VERIFY/docker_helpers.sh"; else echo "ERROR: Cannot find docker_helpers.sh."; fi
fi
# No need to source env_setup.sh here as docker_helpers.sh sources it if needed.

# --- Internal Check Functions (Run INSIDE Container - Use echo -e) ---
V_GREEN='\033[0;32m'; V_RED='\033[0;31m'; V_YELLOW='\033[1;33m'; V_BLUE='\033[0;34m'; V_CYAN='\033[0;36m'; V_NC='\033[0m'

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

_check_ml_frameworks() {
  echo -e "\n${V_BLUE}🧠 ML/AI Frameworks:${V_NC}"
  _check_python_pkg torch
  _check_python_pkg tensorflow
  _check_python_pkg jax
  _check_python_pkg keras
}

_check_libraries() {
  echo -e "\n${V_BLUE}📚 Libraries and Utilities:${V_NC}"
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

_check_cuda_info() {
  echo -e "\n${V_BLUE}🖥️ CUDA/GPU Information:${V_NC}"
  # Block 1: PyTorch Checks
  if _check_python_pkg torch >/dev/null; then # IF 1
    local python_cmd="python3"; command -v $python_cmd &> /dev/null || python_cmd="python"
    if command -v $python_cmd &> /dev/null; then # IF 2
      echo -e "PyTorch CUDA available: $($python_cmd -c "import torch; print('${V_GREEN}Yes${V_NC}' if torch.cuda.is_available() else '${V_RED}No${V_NC}')")"
      if $python_cmd -c "import torch; exit(0 if torch.cuda.is_available() else 1)"; then # IF 3
        echo "CUDA Device count: $($python_cmd -c "import torch; print(torch.cuda.device_count())")"
        echo "CUDA Version (PyTorch): $($python_cmd -c "import torch; print(torch.version.cuda)")"
      fi # Closes IF 3
    fi # Closes IF 2
  fi # Closes IF 1

  # Block 2: nvidia-smi Check
  if command -v nvidia-smi &> /dev/null; then # IF 4
    echo -e "${V_GREEN}✅ nvidia-smi found.${V_NC} Driver/GPU info:"
    nvidia-smi --query-gpu=gpu_name,driver_version,cuda_version --format=csv,noheader || echo -e "${V_RED}nvidia-smi query failed${V_NC}"
  else
    echo -e "${V_YELLOW}ℹ️ nvidia-smi not found (may be normal if only runtime libs are installed).${V_NC}"
  fi # Closes IF 4
} # Closes the function

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


# --- Launcher Functions (Run on Host - Use log_* functions) ---

# Run verification checks or list apps inside a target container image
verify_container_apps() {
  local image_tag=$1
  local mode=${2:-quick}

  # Check if required host functions exist
  if ! declare -f log_error > /dev/null || ! declare -f verify_image_exists > /dev/null; then
      echo "ERROR: Host functions (log_error, verify_image_exists) missing in verify_container_apps." >&2
      return 1
  fi

  if [[ -z "$image_tag" ]]; then log_error "No image tag provided to verify_container_apps."; return 1; fi

  # Use verify_image_exists from docker_helpers.sh (sourced above if needed)
  if ! verify_image_exists "$image_tag"; then
    log_warning "Image '$image_tag' not found locally. Cannot run verification."
    return 1
  fi

  log_info "--- Running Verification (Mode: $mode) in container: $image_tag ---"

  local container_script_path="/tmp/verify_apps.sh"

  # Execute the script inside the container
  docker run --rm --gpus all \
    -v "${BASH_SOURCE[0]}":"$container_script_path":ro \
    --entrypoint /bin/bash \
    "$image_tag" \
    "$container_script_path" "run_checks" "$mode"
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
    # Check if required host function exists
    if ! declare -f log_info > /dev/null; then echo "ERROR: Host function log_info missing in list_installed_apps." >&2; return 1; fi

    log_info "Listing installed applications in: $image_tag"
    verify_container_apps "$image_tag" "list_apps" # Uses the launcher above
    return $?
}

# --- Main Execution (Entry point when script is executed directly) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # If called with "run_checks", execute the internal function (for container execution)
    if [[ "$1" == "run_checks" ]]; then
        run_verification_checks "$2" # Pass the mode
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
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── verification.sh    <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Container verification checks (internal) and host launchers. Relies on logging.sh, docker_helpers.sh sourced by caller for host functions.
# Author: kairin / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-205252-VERIFYFIXFINAL
