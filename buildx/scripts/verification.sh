#!/bin/bash
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── verification.sh    <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Functions for verifying installed applications and packages inside a container.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250421-020700-REFA

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
# Main verification function called inside the container
# Arguments: $1 = mode (all, quick, tools, ml, libs, cuda, python, system)
# =========================================================================
run_verification_checks() {
  local mode="${1:-quick}" # Default to quick verification

  echo -e "${BLUE}===================================================${NC}"
  echo -e "${BLUE}🔍 CONTAINER APPLICATION VERIFICATION (Mode: $mode)${NC}"
  echo -e "${BLUE}===================================================${NC}"

  case "$mode" in
    "all")
      _check_system_tools
      _check_ml_frameworks
      _check_libraries
      _check_cuda_info
      _list_python_packages
      _list_system_packages
      ;;
    "quick")
      _check_system_tools
      _check_ml_frameworks
      _check_libraries
      _check_cuda_info
      ;;
    "tools")
      _check_system_tools
      ;;
    "ml")
      _check_ml_frameworks
      ;;
    "libs")
      _check_libraries
      ;;
    "cuda")
      _check_cuda_info
      ;;
    "python")
      _list_python_packages
      ;;
    "system")
      _list_system_packages
      ;;
    *)
      echo -e "${RED}Invalid mode: $mode${NC}" >&2
      echo "Usage: $0 [all|quick|tools|ml|libs|cuda|python|system]" >&2
      exit 1
      ;;
  esac

  echo -e "\n${BLUE}===================================================${NC}"
  echo -e "${BLUE}🏁 Verification complete (Mode: $mode)${NC}"
  echo -e "${BLUE}===================================================${NC}"
}

# =========================================================================
# Function: Run verification checks inside a target container image
# Arguments: $1 = image tag, $2 = verification mode (optional, default: quick)
# Returns: Exit status of the verification script inside the container
# =========================================================================
verify_container_apps() {
  local tag=$1
  local verify_mode="${2:-quick}"
  local this_script_path="${BASH_SOURCE[0]}" # Path to this script file

  echo "Running verification for image $tag (mode: $verify_mode)..." >&2

  # Check if docker is available
  if ! command -v docker &> /dev/null; then
      echo "Error: Docker command not found." >&2
      return 1
  fi

  # Check if image exists locally
  if ! docker image inspect "$tag" >/dev/null 2>&1; then
      echo "Error: Image $tag not found locally." >&2
      return 1
  fi

  # Define path inside container
  local container_script_path="/tmp/verify_apps.sh"

  # Use docker run with volume mount to execute this script inside the container
  # Mount this script file itself into the container
  # Use --entrypoint to override default CMD/ENTRYPOINT
  # Execute the run_verification_checks function within the container context
  docker run --rm \
    -v "$this_script_path":"$container_script_path":ro \
    --entrypoint /bin/bash \
    "$tag" \
    "$container_script_path" "run_checks" "$verify_mode" # Pass args to script

  local exit_status=$?
  if [ $exit_status -eq 0 ]; then
      echo "Verification successful for $tag (mode: $verify_mode)." >&2
  else
      echo "Verification failed for $tag (mode: $verify_mode). Exit status: $exit_status" >&2
  fi
  return $exit_status
}

# =========================================================================
# Function: List installed applications (runs verification in 'all' mode)
# Arguments: $1 = image tag
# Returns: Exit status of the verification script inside the container
# =========================================================================
list_installed_apps() {
    local image_tag=$1
    echo "Listing all installed packages and tools in: $image_tag" >&2
    # Run verification in 'all' mode which includes listing packages
    verify_container_apps "$image_tag" "all"
    return $?
}


# =========================================================================
# Entry point when script is executed directly (e.g., inside container)
# =========================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] || [[ "$1" == "run_checks" ]]; then
    # If called with "run_checks", execute the internal function
    if [[ "$1" == "run_checks" ]]; then
        run_verification_checks "$2" # Pass the mode (e.g., quick, all)
        exit $?
    else
        # If executed directly without "run_checks", show usage
        echo "This script is intended to be run inside a Docker container via 'verify_container_apps' or 'list_installed_apps'." >&2
        echo "Usage (within container): /tmp/verify_apps.sh run_checks [mode]" >&2
        exit 1
    fi
fi
