#!/bin/bash

# COMMIT-TRACKING: UUID-20240729-004815-A3B1
# Description: Refactor script into a host-side Dockerfile analysis tool.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── generate_app_checks.sh <- THIS FILE
# └── ...                        <- Other project files

set -e

# Use absolute paths or make paths relative to script location for reliability
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/../build" # Go up one level to buildx/build

# Define colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}===================================================${NC}"
echo -e "${BLUE}🔍 Dockerfile Package Analysis Report${NC}"
echo -e "${BLUE}===================================================${NC}"
echo "Scanning Dockerfiles in: $BUILD_DIR"

# Process each build folder
find "$BUILD_DIR" -mindepth 1 -maxdepth 1 -type d | sort | while read -r folder; do
  folder_name=$(basename "$folder")
  dockerfile_path="$folder/Dockerfile"

  # Skip if no Dockerfile exists
  if [ ! -f "$dockerfile_path" ]; then
    continue
  fi

  echo -e "\n${YELLOW}--- Analyzing: $folder_name ($dockerfile_path) ---${NC}"

  # --- APT Package Extraction ---
  apt_packages=$(awk '
    /apt-get install|apt install/ { in_block=1 }
    in_block {
      # Remove comments and line continuation characters
      line = $0
      sub(/#.*/, "", line)
      gsub(/\\$/, "", line)
      # Print words after install, ignoring options
      for (i=1; i<=NF; i++) {
        if ($i == "install") {
          start_printing=1
          continue
        }
        if (start_printing && $i !~ /^-/ && $i !~ /=/ && $i != "&&" && $i != "\\") {
          print $i
        }
      }
      # Check if block ends (no line continuation)
      if ($0 !~ /\\$/) {
        in_block=0
        start_printing=0
      }
    }
  ' "$dockerfile_path" | grep -vE '^(apt-get|apt|install|update|clean|remove|purge|dist-upgrade|autoremove|upgrade|y|no-install-recommends)$' | sort | uniq)

  if [ -n "$apt_packages" ]; then
    echo -e "  ${GREEN}APT Packages Detected:${NC}"
    echo "$apt_packages" | while read -r pkg; do
      # Skip common non-command packages for cleaner report
      if [[ "$pkg" == *"-dev" ]] || [[ "$pkg" == "locales"* ]] || [[ "$pkg" == "tzdata" ]] || [[ "$pkg" == "ca-certificates" ]] || [[ "$pkg" == "software-properties-common" ]] || [[ "$pkg" == "apt-transport-https" ]] || [[ "$pkg" == "gnupg" ]] || [[ "$pkg" == "lsb-release" ]]; then
        echo "    - $pkg (utility/dev)"
      else
        echo "    - $pkg"
      fi
    done
  else
    echo "  No apt packages detected."
  fi

  # --- PIP Package Extraction ---
  pip_packages=$(awk '
    /pip install|pip3 install/ { in_block=1 }
    in_block {
      # Remove comments and line continuation characters
      line = $0
      sub(/#.*/, "", line)
      gsub(/\\$/, "", line)
      # Print words after install, ignoring options/paths/versions
      for (i=1; i<=NF; i++) {
        if ($i == "install") {
          start_printing=1
          continue
        }
        # Ignore options, requirements files, paths, version specs
        if (start_printing && $i !~ /^-/ && $i !~ /\.txt$/ && $i !~ /\// && $i !~ /[=<>]/ && $i != "&&" && $i != "\\") {
          print $i
        }
      }
      # Check if block ends (no line continuation)
      if ($0 !~ /\\$/) {
        in_block=0
        start_printing=0
      }
    }
  ' "$dockerfile_path" | grep -vE '^(pip|pip3|install|upgrade|no-cache-dir)$' | sort | uniq)

  if [ -n "$pip_packages" ]; then
    echo -e "  ${GREEN}PIP Packages Detected:${NC}"
    echo "$pip_packages" | while read -r pkg; do
       echo "    - $pkg"
    done
  else
    echo "  No pip packages detected."
  fi

done

echo -e "\n${BLUE}===================================================${NC}"
echo -e "${BLUE}🏁 Analysis complete${NC}"
echo -e "${BLUE}===================================================${NC}"

# Note: This script now only prints the analysis.
# The actual verification checks are embedded in the Dockerfiles
# and executed by list_installed_apps.sh inside the container.