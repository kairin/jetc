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
# Function to update AVAILABLE_IMAGES in .env
# =========================================================================
update_available_images_in_env() {
    local new_tag="$1"
    local env_file="$(dirname "$0")/.env"
    # ...existing code...
    echo "  Updated AVAILABLE_IMAGES in $env_file with tag '$new_tag'."
    return 0
}

# =========================================================================
# Main Build Process
# =========================================================================

# Define the temporary file path for preferences
PREFS_FILE="/tmp/build_prefs.sh"

# --- Request user preferences BEFORE any build logic or builder setup ---
source "$SCRIPT_DIR/build_ui.sh" || exit 1

# Setup basic build environment and load initial .env variables
load_env_variables

# Setup builder *after* preferences are set
ensure_buildx_builder_running

# --- Source the exported preferences so all variables are available ---
PREFS_FILE="/tmp/build_prefs.sh"
if [ -f "$PREFS_FILE" ]; then
  # shellcheck disable=SC1090
  source "$PREFS_FILE"
else
  echo "Error: Preferences file $PREFS_FILE not found after get_user_preferences."
  exit 1
fi

# Prepare build order and selected folders from user preferences
ORDERED_FOLDERS=()
declare -A SELECTED_FOLDERS_MAP
if [[ -n "$SELECTED_FOLDERS_LIST" ]]; then
  for folder in $SELECTED_FOLDERS_LIST; do
    ORDERED_FOLDERS+=("$(realpath "$(dirname "$0")/build/$folder")")
    SELECTED_FOLDERS_MAP["$folder"]=1
  done
fi
export ORDERED_FOLDERS
export SELECTED_FOLDERS_MAP

# Build selected numbered and other directories
source "$SCRIPT_DIR/build_stages.sh" || exit 1
build_selected_stages

# Verify contents of the selected base image before building
if [ -n "$SELECTED_BASE_IMAGE" ]; then
  echo "Verifying installed apps in base image: $SELECTED_BASE_IMAGE"
  verify_container_apps "$SELECTED_BASE_IMAGE" "all"
fi

# Tag and push final image
source "$SCRIPT_DIR/build_tagging.sh" || exit 1

# Create Final Timestamped Tag
if [[ -n "$FINAL_FOLDER_TAG" ]] && [[ "$BUILD_FAILED" -eq 0 ]]; then
    generate_timestamped_tag "$DOCKER_USERNAME" "$DOCKER_REPO_PREFIX" "$DOCKER_REGISTRY" "$CURRENT_DATE_TIME"
    TIMESTAMPED_LATEST_TAG="$timestamped_tag"
    # ...existing code...
fi

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

# COMMIT-TRACKING: UUID-20240805-221000-BLDX
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