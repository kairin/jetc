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
# Note: build_prefs.sh functionality integrated into build_ui.sh
get_user_preferences
if [ $? -ne 0 ]; then
  echo "User cancelled or error in preferences dialog. Exiting build."
  exit 1
fi

# Verify contents of the selected base image before building
if [ -n "$SELECTED_BASE_IMAGE" ]; then
  echo "Verifying installed apps in base image: $SELECTED_BASE_IMAGE"
  if [ -f "$SCRIPT_DIR/verification.sh" ]; then
    bash "$SCRIPT_DIR/verification.sh" verify_container_apps "$SELECTED_BASE_IMAGE" "all"
  else
    echo "verification.sh not found, skipping base image verification."
  fi
fi

# Determine build order and prepare selected folders map
source "$SCRIPT_DIR/build_order.sh" || exit 1

# Build selected numbered and other directories
source "$SCRIPT_DIR/build_stages.sh" || exit 1

# Tag and push final image
source "$SCRIPT_DIR/build_tagging.sh" || exit 1

# Post-build menu/options - now integrated into build_ui.sh
if [[ -n "$FINAL_IMAGE_TAG" ]]; then
  show_post_build_menu "$FINAL_IMAGE_TAG"
fi

# Final verification of built images - now integrated into verification.sh
if [[ -n "$FINAL_IMAGE_TAG" ]]; then
  verify_container_apps "$FINAL_IMAGE_TAG" "quick"
fi

# Automatically update commit tracking UUID timestamp in this file and scripts after build
for f in "$0" "$SCRIPT_DIR"/*.sh; do
  if grep -q "COMMIT-TRACKING: UUID-" "$f"; then
    source "$SCRIPT_DIR/commit_tracking.sh"
    update_commit_tracking_footer "$f"
  fi
done

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