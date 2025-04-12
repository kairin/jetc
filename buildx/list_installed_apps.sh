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
NC='\033[0m' # No Color

# =========================================================================
# Function: Check if a command exists and print its version
# =========================================================================
check_cmd() {
  if command -v $1 &> /dev/null; then
    version=$($1 --version 2>&1 | head -n 1 || echo "version info unavailable")
    echo -e "${GREEN}✅ $1:${NC} $version"
    return 0
  else
    echo -e "${RED}❌ $1:${NC} Not installed"
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
  check_cmd python3
  check_cmd pip
  check_cmd nvcc
  check_cmd gcc
  check_cmd g++
  check_cmd make
  check_cmd cmake
  check_cmd git
  check_cmd wget
  check_cmd curl
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
      check_ml_frameworks
      check_libraries
      check_cuda_info
      list_python_packages
      list_system_packages
      ;;
    "quick")
      check_system_tools
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