# COMMIT-TRACKING: UUID-20240729-004815-A3B1
# Description: Create comprehensive container verification tool with modular checks
# Author: Mr K
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── list_installed_apps.sh <- THIS FILE
# └── ...                        <- Other project files

#!/usr/bin/env bash
set -e

# =========================================================================
# Container Application Verification Script
# This script provides modular checks for container applications and packages
# =========================================================================

# Define colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Import generated checks if available
if [ -f "$(dirname "$0")/generated_app_checks.sh" ]; then
  source "$(dirname "$0")/generated_app_checks.sh"
fi

# =========================================================================
# Function: Check if a command exists and print its version
# =========================================================================
check_cmd() {
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
# Function: Check if a Python package is installed
# =========================================================================
check_python_pkg() {
  if python3 -c "import $1" &> /dev/null; then
    version=$(python3 -c "import $1; print(getattr($1, '__version__', 'version unknown'))" 2>/dev/null || echo "version unknown")
    echo -e "${GREEN}✅ Python $1:${NC} $version"
    return 0
  else
    echo -e "${RED}❌ Python $1:${NC} Not installed"
    return 1
  fi
}

# =========================================================================
# Function: Check common system tools
# =========================================================================
check_system_tools() {
  echo -e "\n${BLUE}🔧 System Tools:${NC}"
  
  # Basic system commands
  check_cmd bash "Bash shell"
  check_cmd ls "File listing"
  check_cmd cat "File viewing"
  check_cmd grep "Text search"
  check_cmd find "File search" 
  check_cmd awk "Text processing"
  check_cmd sed "Stream editor"
  check_cmd ps "Process status"
  check_cmd top "System monitor"
  check_cmd ssh "SSH client"
  
  # Common development tools
  check_cmd python3 "Python 3"
  check_cmd pip3 "Python package manager"
  check_cmd nvcc "NVIDIA CUDA Compiler"
  check_cmd gcc "C Compiler"
  check_cmd g++ "C++ Compiler"
  check_cmd make "Make utility"
  check_cmd cmake "CMake build system"
  check_cmd git "Git version control"
  check_cmd wget "Download utility"
  check_cmd curl "URL transfer tool"
  
  return 0
}

# =========================================================================
# Function: Check ML/AI frameworks
# =========================================================================
check_ml_frameworks() {
  echo -e "\n${BLUE}🧠 ML/AI Frameworks:${NC}"
  check_python_pkg torch
  check_python_pkg tensorflow
  check_python_pkg jax
  check_python_pkg keras
}

# =========================================================================
# Function: Check common libraries
# =========================================================================
check_libraries() {
  echo -e "\n${BLUE}📚 Libraries and Utilities:${NC}"
  check_python_pkg numpy
  check_python_pkg scipy
  check_python_pkg pandas
  check_python_pkg matplotlib
  check_python_pkg sklearn
  check_python_pkg cv2
  check_python_pkg transformers
  check_python_pkg diffusers
  check_python_pkg huggingface_hub
}

# =========================================================================
# Function: Check CUDA/GPU information
# =========================================================================
check_cuda_info() {
  echo -e "\n${BLUE}🖥️ CUDA/GPU Information:${NC}"
  if check_python_pkg torch; then
    echo -e "PyTorch CUDA available: $(python3 -c "import torch; print('${GREEN}Yes${NC}' if torch.cuda.is_available() else '${RED}No${NC}')")"
    if python3 -c "import torch; exit(0 if torch.cuda.is_available() else 1)" &>/dev/null; then
      echo "CUDA Device count: $(python3 -c "import torch; print(torch.cuda.device_count())")"
      echo "CUDA Version: $(python3 -c "import torch; print(torch.version.cuda)")"
    fi
  fi
}

# =========================================================================
# Function: List all installed system packages
# =========================================================================
list_system_packages() {
  echo -e "\n${BLUE}📦 All Installed System Packages:${NC}"
  
  if command -v dpkg > /dev/null; then
    echo -e "${YELLOW}Detected dpkg (Debian/Ubuntu-based system).${NC}"
    dpkg-query -W -f='${binary:Package}\t${Version}\n' | sort
  elif command -v rpm > /dev/null; then
    echo -e "${YELLOW}Detected rpm (RHEL/CentOS-based system).${NC}"
    rpm -qa --qf "%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n" | sort
  elif command -v apk > /dev/null; then
    echo -e "${YELLOW}Detected apk (Alpine-based system).${NC}"
    apk info -v | sort
  else
    echo -e "${RED}Unknown package manager. Cannot list all packages.${NC}"
    return 1
  fi
  
  return 0
}

# =========================================================================
# Function: List Python packages
# =========================================================================
list_python_packages() {
  echo -e "\n${BLUE}🐍 Installed Python Packages:${NC}"
  if command -v pip > /dev/null || command -v pip3 > /dev/null; then
    python3 -m pip list
  else
    echo -e "${RED}pip not found. Cannot list Python packages.${NC}"
    return 1
  fi
  
  return 0
}

# =========================================================================
# Main function to run all checks or specific checks
# =========================================================================
main() {
  local mode="${1:-all}"
  
  echo -e "${BLUE}===================================================${NC}"
  echo -e "${BLUE}🔍 CONTAINER APPLICATION VERIFICATION${NC}"
  echo -e "${BLUE}===================================================${NC}"
  
  case "$mode" in
    "all")
      check_system_tools
      # Call the dynamically generated checks if available
      if type check_installed_applications >/dev/null 2>&1; then
        check_installed_applications
      fi
      check_ml_frameworks
      check_libraries
      check_cuda_info
      list_python_packages
      list_system_packages
      ;;
    "quick")
      check_system_tools
      # Call the dynamically generated checks if available
      if type check_installed_applications >/dev/null 2>&1; then
        check_installed_applications
      fi
      check_ml_frameworks
      check_libraries
      check_cuda_info
      ;;
    "tools")
      check_system_tools
      ;;
    "ml")
      check_ml_frameworks
      ;;
    "libs")
      check_libraries
      ;;
    "cuda")
      check_cuda_info
      ;;
    "python")
      list_python_packages
      ;;
    "system")
      list_system_packages
      ;;
    *)
      echo -e "${RED}Invalid mode: $mode${NC}"
      echo "Usage: $0 [all|quick|tools|ml|libs|cuda|python|system]"
      exit 1
      ;;
  esac
  
  echo -e "\n${BLUE}===================================================${NC}"
  echo -e "${BLUE}🏁 Verification complete${NC}"
  echo -e "${BLUE}===================================================${NC}"
}



# Run the main function with arguments
main "$@"