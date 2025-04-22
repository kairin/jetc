#!/bin/bash

# Import utility scripts
SCRIPT_DIR="$(dirname "$0")/scripts"
# Source scripts individually with error checking
source "$SCRIPT_DIR/utils.sh" || { echo "Error sourcing utils.sh"; exit 1; }
source "$SCRIPT_DIR/docker_helpers.sh" || { echo "Error sourcing docker_helpers.sh"; exit 1; }
source "$SCRIPT_DIR/build_ui.sh" || { echo "Error sourcing build_ui.sh"; exit 1; }
source "$SCRIPT_DIR/verification.sh" || { echo "Error sourcing verification.sh"; exit 1; }
source "$SCRIPT_DIR/logging.sh" || { echo "Error sourcing logging.sh"; exit 1; }

set -e # Exit immediately if a command exits with a non-zero status (temporarily disabled during builds)

# Initialize logging
BUILD_ID=$(date +"%Y%m%d-%H%M%S")
LOGS_DIR="$(dirname "$0")/logs"
init_logging "$LOGS_DIR" "$BUILD_ID"

# =========================================================================
# Function to handle build errors but continue with other builds
# =========================================================================
handle_build_error() {
  local folder=$1
  # shellcheck disable=SC2034
  local error_code=$2
  echo "Build process for $folder exited with code $error_code" | tee -a "${ERROR_LOG}"
  echo "Continuing with next build..." | tee -a "${MAIN_LOG}"
}

# =========================================================================
# Main Build Process
# =========================================================================

# Define the temporary file path for preferences
PREFS_FILE="/tmp/build_prefs.sh"

# Setup basic build environment and load initial .env variables
source "$SCRIPT_DIR/build_env_setup.sh" || exit 1

# Setup builder *before* getting preferences that might depend on it
source "$SCRIPT_DIR/build_builder.sh" || exit 1

# Call the function that shows the dialogs and gets user preferences
source "$SCRIPT_DIR/build_prefs.sh" || exit 1

# Determine build order and prepare selected folders map
source "$SCRIPT_DIR/build_order.sh" || exit 1

# Build selected numbered and other directories
source "$SCRIPT_DIR/build_stages.sh" || exit 1

# Tag and push final image
source "$SCRIPT_DIR/build_tagging.sh" || exit 1

# Post-build menu/options
source "$SCRIPT_DIR/build_post.sh" || exit 1

# Final verification of built images
source "$SCRIPT_DIR/build_verify.sh" || exit 1

# COMMIT-TRACKING: UUID-20250421-020700-REFA
generate_error_summary

# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Current directory
# │   └── build.sh               <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Main build orchestrator for Jetson container buildx system. Modular, interactive, and tracks all build stages and tags.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250422-083100-BLDX