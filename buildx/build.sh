#!/bin/bash
# Main build script for Jetson Container project
# filepath: /media/kkk/Apps/jetc/buildx/build.sh

# Strict mode
set -euo pipefail

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
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
_bootstrap_source_script "$SCRIPTS_DIR/env_setup.sh" "Environment Setup"
# Now log_* functions and the potentially redefined source_script from utils.sh should be available.
log_debug "Environment setup bootstrapped. Main logging and utils should be available."

# --- Source Helper Scripts ---
# Use the source_script function provided by utils.sh (sourced via env_setup.sh)
# Ensure source_script is defined before proceeding (check added in env_setup.sh)
if ! command -v source_script &> /dev/null; then
    log_error "Core 'source_script' function not defined after env_setup. Aborting."
    exit 1
fi

# Source dependencies before the scripts that need them
source_script "$SCRIPTS_DIR/env_update.sh" "Env Update Helpers"
source_script "$SCRIPTS_DIR/interactive_ui.sh" "Interactive UI"
source_script "$SCRIPTS_DIR/docker_helpers.sh" "Docker Helpers"
source_script "$SCRIPTS_DIR/buildx_setup.sh" "Buildx Setup"
source_script "$SCRIPTS_DIR/user_interaction.sh" "User Interaction"
source_script "$SCRIPTS_DIR/build_order.sh" "Build Order"
source_script "$SCRIPTS_DIR/build_stages.sh" "Build Stages"
# source_script "$SCRIPTS_DIR/post_build_menu.sh" "Post-Build Menu" # Deprecated, functionality in interactive_ui.sh

# --- Main Build Logic ---
log_info "Starting Jetson Container Build Process..."

# Define the path for the preferences file
PREFS_FILE="/tmp/build_prefs.sh"

# 1. Get User Preferences via handle_user_interaction
if handle_user_interaction; then
    log_success "User interaction completed successfully. Preferences exported."

    # Preferences are now exported directly by handle_user_interaction.
    # We can directly use $use_builder, $SELECTED_FOLDERS_LIST, etc.
    # Sourcing PREFS_FILE again is redundant if handle_user_interaction exports them.
    # However, keeping it for now in case other variables are set in PREFS_FILE.
    if [ -f "$PREFS_FILE" ]; then
        log_debug "Sourcing preferences file $PREFS_FILE for any additional variables..."
        # shellcheck disable=SC1090
        source "$PREFS_FILE"
    else
        # This shouldn't happen if handle_user_interaction succeeded
        log_warning "Preferences file $PREFS_FILE not found after successful user interaction."
    fi

    # Log the final effective settings (using exported variables)
    log_debug "Effective Build Settings:"
    log_debug "  Base Image: ${SELECTED_BASE_IMAGE:-<unset>}"
    log_debug "  Use Cache: ${use_cache:-<unset>}"
    log_debug "  Use Squash: ${use_squash:-<unset>}"
    log_debug "  Skip Push/Pull: ${skip_intermediate_push_pull:-<unset>}"
    log_debug "  Use Builder: ${use_builder:-<unset>}"
    log_debug "  Selected Folders List: ${SELECTED_FOLDERS_LIST:-<unset>}"
    log_debug "  Docker User: ${DOCKER_USERNAME:-<unset>}"
    log_debug "  Docker Repo Prefix: ${DOCKER_REPO_PREFIX:-<unset>}"
    log_debug "  Docker Registry: ${DOCKER_REGISTRY:-<unset>}"


    # 2. Setup Buildx (if selected)
    if [[ "${use_builder:-y}" == "y" ]]; then
        log_info "Setting up Docker Buildx builder..."
        if ! setup_buildx; then
            log_error "Buildx setup failed. Aborting build."
            exit 1
        fi
        log_info "Buildx setup complete."
    else
        log_info "Skipping Buildx setup as user selected not to use the builder."
    fi

    # 3. Determine Build Order
    log_info "Determining build order..."
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
    log_info "Build order determined: ${ORDERED_FOLDERS[*]}"

    # 4. Execute Build Stages
    log_info "Starting build stages execution..."
    # build_selected_stages uses global ORDERED_FOLDERS and exported preference variables
    if build_selected_stages; then
        log_success "Build process completed successfully."
        # 5. Show Post-Build Menu (optional actions)
        if command -v show_post_build_menu &> /dev/null; then
            log_info "Displaying post-build menu..."
            show_post_build_menu "${LAST_SUCCESSFUL_TAG:-}"
        else
             log_warning "Post-build menu function (show_post_build_menu) not found."
        fi
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
# ├── buildx/                    <- Parent directory
# │   ├── build.sh               <- THIS FILE
# │   └── scripts/               <- SCRIPTS_DIR
# └── ...                        <- Other project files
#
# Description: Main build orchestrator script for the Jetson Container project.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250425-120100-BUILDSH-PATHFIX
