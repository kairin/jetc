#!/bin/bash
# Main build script for Jetson Container project

# Strict mode
set -euo pipefail

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR # Export for use in sourced scripts

# Source utility scripts
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/logging.sh" || { echo "Error: logging.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/docker_helpers.sh" || { echo "Error: docker_helpers.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/verification.sh" || { echo "Error: verification.sh not found."; exit 1; }
# Source the NEW user interaction handler
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/user_interaction.sh" || { echo "Error: user_interaction.sh not found."; exit 1; }
# Source the NEW build order handler
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/build_order.sh" || { echo "Error: build_order.sh not found."; exit 1; }
# Source the build stages execution script
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/build_stages.sh" || { echo "Error: build_stages.sh not found."; exit 1; }
# Source the post-build menu (optional, might be integrated elsewhere later)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/post_build_menu.sh" || { echo "Error: post_build_menu.sh not found."; exit 1; }


# --- Configuration ---
export BUILD_DIR="$SCRIPT_DIR/build"
export LOG_DIR="$SCRIPT_DIR/logs"
export MAIN_LOG="$LOG_DIR/build-$(get_system_datetime).log"
export ERROR_LOG="$LOG_DIR/errors-$(get_system_datetime).log"
export JETC_DEBUG="${JETC_DEBUG:-false}" # Enable debug logging if JETC_DEBUG=true

# --- Initialization ---
init_logging "$LOG_DIR" "$MAIN_LOG" "$ERROR_LOG"
log_start "$MAIN_LOG"
check_dependencies "docker" "dialog" # Check essential dependencies

# --- Main Build Process ---
main() {
    log_message "Starting Jetson Container Build Process..."

    # 1. Handle User Interaction (Gets prefs, updates .env, exports vars for this run)
    if ! handle_user_interaction; then
        log_error "Build cancelled by user or error during interaction." "$ERROR_LOG"
        exit 1
    fi
    # Variables like DOCKER_USERNAME, SELECTED_BASE_IMAGE, use_cache, etc.,
    # SELECTED_FOLDERS_LIST are now exported by handle_user_interaction sourcing the prefs file.

    # 2. Determine Build Order (Based on SELECTED_FOLDERS_LIST from user interaction)
    # This function exports ORDERED_FOLDERS and SELECTED_FOLDERS_MAP
    if ! determine_build_order "$BUILD_DIR" "${SELECTED_FOLDERS_LIST:-}"; then
        log_error "Failed to determine build order. Check build directory structure and selections." "$ERROR_LOG"
        exit 1
    fi
    # ORDERED_FOLDERS and SELECTED_FOLDERS_MAP are now available

    # 3. Execute Build Stages (Uses exported variables from steps 1 & 2)
    # build_selected_stages uses ORDERED_FOLDERS, SELECTED_FOLDERS_MAP, and other prefs
    if ! build_selected_stages; then
        log_error "Build process completed with errors. Check logs in $LOG_DIR." "$ERROR_LOG"
        # Optionally run post-build menu even on failure?
        run_post_build_menu "${LAST_SUCCESSFUL_TAG:-No image built}"
        exit 1
    fi

    # 4. Post-Build Actions (Verification, Menu)
    log_message "Build process completed successfully."
    log_message "Final Image Tag: ${LAST_SUCCESSFUL_TAG:-No image built}"

    # Optional: Verify the final image
    # verify_final_image "$LAST_SUCCESSFUL_TAG"

    # Run the post-build menu
    run_post_build_menu "${LAST_SUCCESSFUL_TAG:-No image built}"

    log_end "$MAIN_LOG"
    exit 0
}

# --- Script Execution ---
# Ensure cleanup runs on exit
trap cleanup EXIT INT TERM
# Run the main function
main

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Current directory
# │   └── build.sh               <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Main build orchestrator script. Refactored to use user_interaction.sh and build_order.sh.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-095000-BUILDREF