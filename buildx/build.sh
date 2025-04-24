#!/bin/bash
# Main build script for Jetson Container project

# Strict mode
set -euo pipefail # Re-enable -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export SCRIPT_DIR

# --- Source Core Dependencies (Order Matters!) ---
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/logging.sh" || { echo "Error: logging.sh not found."; exit 1; }
init_logging
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/env_setup.sh" || { echo "Error: env_setup.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/env_update.sh" || { echo "Error: env_update.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/dialog_ui.sh" || { echo "Error: dialog_ui.sh not found."; exit 1; } # Correct UI script
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/docker_helpers.sh" || { echo "Error: docker_helpers.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/verification.sh" || { echo "Error: verification.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/system_checks.sh" || { echo "Error: system_checks.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/buildx_setup.sh" || { echo "Error: buildx_setup.sh not found."; exit 1; }

# --- Source Helper Scripts ---
# Source user interaction script (handles dialog or basic prompts)
source_script "$SCRIPT_DIR/scripts/user_interaction.sh" "User Interaction"
# Source build order determination script
source_script "$SCRIPT_DIR/scripts/build_order.sh" "Build Order"
# Source build stages execution script
source_script "$SCRIPT_DIR/scripts/build_stages.sh" "Build Stages"
# Source post-build menu script
source_script "$SCRIPT_DIR/scripts/post_build_menu.sh" "Post-Build Menu"

# --- Main Build Logic ---
log_info "Starting Jetson Container Build Process..."

# Define the path for the preferences file
PREFS_FILE="/tmp/build_prefs.sh"

# 1. Get User Preferences (using dialog or fallback)
# show_main_menu is defined in user_interaction.sh (which sources dialog_ui.sh)
# It creates PREFS_FILE on success (exit code 0)
if show_main_menu; then
    log_success "User interaction completed successfully."

    # Source the preferences file created by show_main_menu to load SELECTED_* vars
    if [ -f "$PREFS_FILE" ]; then
        log_info "Loading user preferences from $PREFS_FILE..."
        # shellcheck disable=SC1090
        source "$PREFS_FILE"
        log_debug "User preferences loaded."
        # Optional: Log loaded preferences for debugging
        log_debug "SELECTED_BASE_IMAGE=${SELECTED_BASE_IMAGE:-<unset>}"
        log_debug "SELECTED_USE_CACHE=${SELECTED_USE_CACHE:-<unset>}"
        log_debug "SELECTED_SKIP_INTERMEDIATE=${SELECTED_SKIP_INTERMEDIATE:-<unset>}"
        log_debug "SELECTED_USE_BUILDER=${SELECTED_USE_BUILDER:-<unset>}"
        log_debug "SELECTED_FOLDERS_LIST=${SELECTED_FOLDERS_LIST:-<unset>}"
    else
        log_error "Preferences file $PREFS_FILE not found after successful user interaction."
        exit 1
    fi

    # 2. Setup Buildx (ensure builder exists and is used if SELECTED_USE_BUILDER is 'y')
    # Check the SELECTED_USE_BUILDER variable loaded from prefs
    if [[ "${SELECTED_USE_BUILDER:-y}" == "y" ]]; then
        if ! setup_buildx; then
            log_error "Buildx setup failed. Aborting build."
            exit 1
        fi
    else
        log_info "Skipping Buildx setup as user selected not to use the builder."
    fi


    # 3. Determine Build Order based on user selections
    # Pass the build directory and the selected folders list
    BUILD_DIR="$SCRIPT_DIR/build" # Define build directory path
    if ! determine_build_order "$BUILD_DIR" "${SELECTED_FOLDERS_LIST:-}"; then
        log_error "Failed to determine build order. Aborting."
        exit 1
    fi

    # Check if there are any stages to build
    if [ ${#ORDERED_FOLDERS[@]} -eq 0 ]; then
        log_warning "No build stages selected or found to build. Exiting."
        exit 0
    fi

    # 4. Execute Build Stages
    # build_selected_stages uses global ORDERED_FOLDERS and SELECTED_* variables
    if build_selected_stages; then
        log_success "Build process completed successfully."
        # 5. Show Post-Build Menu (optional actions)
        show_post_build_menu "${LAST_SUCCESSFUL_TAG:-}"
    else
        log_error "Build process failed."
        exit 1
    fi

else
    log_error "User cancelled or failed during preference selection. Build aborted."
    # Clean up prefs file if it exists from a partial run
    rm -f "$PREFS_FILE"
    exit 1
fi

log_info "Build script finished."
exit 0

# --- Footer ---
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Current directory
# │   └── build.sh               <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Main build orchestrator script for the Jetson Container project.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250425-080000-42595D
