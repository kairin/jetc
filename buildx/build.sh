#!/bin/bash

# Import utility scripts
SCRIPT_DIR="$(dirname "$0")/scripts"
export JETC_DEBUG=true # Enable debug logging in helpers

# Source utils first
source "$SCRIPT_DIR/utils.sh" || { echo "Error sourcing utils.sh"; exit 1; }
# Source other helpers
source "$SCRIPT_DIR/docker_helpers.sh" || { echo "Error sourcing docker_helpers.sh"; exit 1; }
# source "$SCRIPT_DIR/build_ui.sh" || { echo "Error sourcing build_ui.sh"; exit 1; } # Replaced by interactive_ui.sh
source "$SCRIPT_DIR/interactive_ui.sh" || { echo "Error sourcing interactive_ui.sh"; exit 1; } # Source directly
source "$SCRIPT_DIR/verification.sh" || { echo "Error sourcing verification.sh"; exit 1; }
source "$SCRIPT_DIR/logging.sh" || { echo "Error sourcing logging.sh"; exit 1; }
source "$SCRIPT_DIR/commit_tracking.sh" || { echo "Error sourcing commit_tracking.sh"; exit 1; }
source "$SCRIPT_DIR/env_helpers.sh" || { echo "Error sourcing env_helpers.sh"; exit 1; } # Needed early
source "$SCRIPT_DIR/build_stages.sh" || { echo "Error sourcing build_stages.sh"; exit 1; }
# build_tagging.sh seems less used now, tagging happens within build_stages/docker_helpers? Review if needed.
# source "$SCRIPT_DIR/build_tagging.sh" || { echo "Error sourcing build_tagging.sh"; exit 1; }

set -e # Exit immediately if a command exits with a non-zero status

# --- Generate and Store Runtime UUID ---
RUNTIME_UUID=$(generate_commit_uuid "BLDX")
GIT_DIR_PATH="$(git rev-parse --git-dir 2>/dev/null)"
if [[ -n "$GIT_DIR_PATH" && -d "$GIT_DIR_PATH" ]]; then
    echo "$RUNTIME_UUID" > "$GIT_DIR_PATH/LAST_RUNTIME_UUID"
    _log_debug "Stored runtime UUID ($RUNTIME_UUID) in $GIT_DIR_PATH/LAST_RUNTIME_UUID"
else
    _log_debug "Warning: Could not determine .git directory. Runtime UUID not stored for hooks."
fi

# Initialize logging
BUILD_ID=$(date +"%Y%m%d-%H%M%S")
LOGS_DIR="$(dirname "$0")/logs"
init_logging "$LOGS_DIR" "$BUILD_ID"
_log_debug "Logging initialized."

# =========================================================================
# Function to handle build errors (used by build_stages.sh)
# =========================================================================
handle_build_error() {
  local folder=$1
  local error_code=$2
  echo "Build process for $folder exited with code $error_code" | tee -a "${ERROR_LOG}"
  echo "Continuing with next build..." | tee -a "${MAIN_LOG}"
}

# =========================================================================
# Main Build Process
# =========================================================================
_log_debug "Starting main build process."

# Define the temporary file path for preferences (used by interactive_ui.sh)
PREFS_FILE="/tmp/build_prefs.sh"

# --- Request user preferences BEFORE any build logic or builder setup ---
_log_debug "Getting user build preferences..."
get_build_preferences # From interactive_ui.sh
prefs_exit_code=$?
if [ $prefs_exit_code -ne 0 ]; then
  echo "User cancelled or error in preferences dialog/prompts. Exiting build." >&2
  exit 1
fi
_log_debug "User preferences obtained."

# --- Source the exported preferences so all variables are available ---
if [ -f "$PREFS_FILE" ]; then
  _log_debug "Sourcing preferences from $PREFS_FILE..."
  # shellcheck disable=SC1090
  source "$PREFS_FILE"
  # Reload .env to get any updates made during preference selection (e.g., default base image)
  load_env_variables
  # Ensure lowercase platform is exported if PLATFORM is set
  [[ -n "$PLATFORM" ]] && export platform="$PLATFORM"
  _log_debug "Preferences sourced: User=$DOCKER_USERNAME, Prefix=$DOCKER_REPO_PREFIX, Base=$SELECTED_BASE_IMAGE, Cache=$use_cache, Squash=$use_squash, Local=$skip_intermediate_push_pull, Builder=$use_builder"
  _log_debug "Selected Folders: $SELECTED_FOLDERS_LIST"
else
  echo "Error: Preferences file $PREFS_FILE not found after get_build_preferences. Cannot proceed." >&2
  exit 1
fi

# Setup basic build environment (ARCH, PLATFORM already sourced from prefs)
setup_build_environment # Sets CURRENT_DATE_TIME

# Setup builder *after* preferences are set (uses use_builder variable)
if [[ "$use_builder" == "y" ]]; then
    _log_debug "Ensuring buildx builder is running..."
    ensure_buildx_builder_running # From docker_helpers.sh
else
    _log_debug "Skipping buildx builder setup as per user preference."
fi

# Prepare build order and selected folders from user preferences
ORDERED_FOLDERS=()
declare -A SELECTED_FOLDERS_MAP
if [[ -n "$SELECTED_FOLDERS_LIST" ]]; then
  _log_debug "Processing selected folders: $SELECTED_FOLDERS_LIST"
  # Convert space-separated list to array and map
  IFS=' ' read -r -a selected_folder_names <<< "$SELECTED_FOLDERS_LIST"
  for folder_name in "${selected_folder_names[@]}"; do
    local full_path
    full_path=$(realpath "$(dirname "$0")/build/$folder_name")
    if [[ -d "$full_path" ]]; then
        ORDERED_FOLDERS+=("$full_path")
        SELECTED_FOLDERS_MAP["$folder_name"]=1
        _log_debug "Added to build order: $full_path"
    else
        _log_debug "Warning: Selected folder '$folder_name' not found at expected path. Skipping."
    fi
  done
else
    _log_debug "No build stages selected by user."
fi
export ORDERED_FOLDERS # Export for build_stages.sh
export SELECTED_FOLDERS_MAP # Export for build_stages.sh

# Build selected numbered and other directories
_log_debug "Calling build_selected_stages..."
# build_selected_stages is defined in build_stages.sh
# It uses exported variables like ORDERED_FOLDERS, SELECTED_FOLDERS_MAP,
# use_cache, platform, SELECTED_BASE_IMAGE, etc.
# It exports LAST_SUCCESSFUL_TAG
build_selected_stages
BUILD_FAILED=$? # Capture the exit status
_log_debug "build_selected_stages finished with status: $BUILD_FAILED. Last successful tag: $LAST_SUCCESSFUL_TAG"

# Verify contents of the base image *before* build (optional, maybe remove?)
# if [ -n "$SELECTED_BASE_IMAGE" ]; then
#   echo "Verifying installed apps in initial base image: $SELECTED_BASE_IMAGE"
#   verify_container_apps "$SELECTED_BASE_IMAGE" "quick"
# fi

# Tag and push final image (This logic might be redundant if build_stages handles it)
# source "$SCRIPT_DIR/build_tagging.sh" || exit 1 # Re-evaluate if build_tagging.sh is needed

# Create Final Timestamped Tag (Example - adapt if tagging logic changes)
FINAL_IMAGE_TAG="$LAST_SUCCESSFUL_TAG" # Use the last successfully built tag
if [[ -n "$FINAL_IMAGE_TAG" ]] && [[ "$BUILD_FAILED" -eq 0 ]]; then
    _log_debug "Build successful. Final image tag: $FINAL_IMAGE_TAG"
    # generate_timestamped_tag "$DOCKER_USERNAME" "$DOCKER_REPO_PREFIX" "$DOCKER_REGISTRY" "$CURRENT_DATE_TIME"
    # TIMESTAMPED_LATEST_TAG="$timestamped_tag"
    # Tagging logic might be better placed within build_stages or docker_helpers
    # For now, just report the final tag.
else
    _log_debug "Build failed or no stages built. Last successful tag (if any): $LAST_SUCCESSFUL_TAG"
fi

# Post-build menu/options
if [[ -n "$FINAL_IMAGE_TAG" ]]; then
  _log_debug "Showing post-build menu for image: $FINAL_IMAGE_TAG"
  show_post_build_menu "$FINAL_IMAGE_TAG" # From interactive_ui.sh
else
   _log_debug "Skipping post-build menu as no final image tag is available."
fi

# Final verification of built images (optional, can be done via post-build menu)
# if [[ -n "$FINAL_IMAGE_TAG" ]]; then
#   verify_container_apps "$FINAL_IMAGE_TAG" "quick"
# fi

# Generate error summary log
generate_error_summary

_log_debug "Build script finished."
exit $BUILD_FAILED


# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Current directory
# │   └── build.sh               <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Main build orchestrator. Refactored for modularity. Stores runtime UUID.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20240806-103000-MODULAR