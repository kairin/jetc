#!/bin/bash
# Main build script for Jetson Container project

# Strict mode
set -euo pipefail # Re-enable -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[DEBUG build.sh] Initial SCRIPT_DIR: $SCRIPT_DIR" >&2

# Define source_script locally ONLY for bootstrapping env_setup.sh
# This avoids conflicts if utils.sh redefines it later.
_bootstrap_source_script() {
    local script_path="$1"
    local script_name="${2:-Script}"
    echo "[DEBUG build.sh] Bootstrapping $script_name: $script_path" >&2
    if [[ -f "$script_path" ]]; then
        # shellcheck disable=SC1090
        source "$script_path"
        local source_status=$?
        if [[ $source_status -ne 0 ]]; then
            echo "ERROR: Failed to bootstrap $script_name from $script_path (exit code $source_status)." >&2
            exit 1 # Exit early if bootstrap fails
        else
             echo "[DEBUG build.sh] $script_name bootstrapped successfully." >&2
             return 0
        fi
    else
        echo "ERROR: Bootstrap $script_name not found at: $script_path" >&2
        exit 1 # Exit early if bootstrap fails
    fi
}

# --- Bootstrap Environment ---
# Source env_setup.sh using the bootstrap function.
# env_setup.sh will source utils.sh and logging.sh, making their functions globally available.
_bootstrap_source_script "$SCRIPT_DIR/scripts/env_setup.sh" "Environment Setup"
# Now log_* functions and the potentially redefined source_script from utils.sh should be available.
log_debug "Environment setup bootstrapped. Main logging and utils should be available."

# --- Source Helper Scripts ---
# Use the source_script function provided by utils.sh (sourced via env_setup.sh)
# Ensure source_script is defined before proceeding (check added in env_setup.sh)
if ! command -v source_script &> /dev/null; then
    log_error "Core 'source_script' function not defined after env_setup. Aborting."
    exit 1
fi

# Add debugging before sourcing buildx_setup.sh
log_debug "Current SCRIPT_DIR before sourcing buildx_setup: $SCRIPT_DIR"
log_debug "Path to be sourced for Buildx Setup: $SCRIPT_DIR/scripts/buildx_setup.sh"
# Source buildx setup script
source_script "$SCRIPT_DIR/scripts/buildx_setup.sh" "Buildx Setup"
# Source docker helpers script
log_debug "Path to be sourced for Docker Helpers: $SCRIPT_DIR/scripts/docker_helpers.sh"
source_script "$SCRIPT_DIR/scripts/docker_helpers.sh" "Docker Helpers"
# Source user interaction script (handles dialog or basic prompts)
log_debug "Path to be sourced for User Interaction: $SCRIPT_DIR/scripts/user_interaction.sh"
source_script "$SCRIPT_DIR/scripts/user_interaction.sh" "User Interaction"
# Source build order determination script
log_debug "Path to be sourced for Build Order: $SCRIPT_DIR/scripts/build_order.sh"
source_script "$SCRIPT_DIR/scripts/build_order.sh" "Build Order"
# Source build stages execution script
log_debug "Path to be sourced for Build Stages: $SCRIPT_DIR/scripts/build_stages.sh"
source_script "$SCRIPT_DIR/scripts/build_stages.sh" "Build Stages"
# Source post-build menu script
log_debug "Path to be sourced for Post-Build Menu: $SCRIPT_DIR/scripts/post_build_menu.sh"
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
# COMMIT-TRACKING: UUID-20250425-104500-TYPOFIX3 # Use same UUID
