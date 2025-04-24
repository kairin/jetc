#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/user_interaction.sh

# Source necessary utilities and UI functions
SCRIPT_DIR_UI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR_UI/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_UI/logging.sh" || { echo "Error: logging.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_UI/interactive_ui.sh" || { echo "Error: interactive_ui.sh not found."; exit 1; }

# =========================================================================
# Function: Handle user interaction for build preferences
# Exports: Variables defined in get_build_preferences via prefs file
# Returns: 0 on success, 1 on failure or user cancellation
# =========================================================================
handle_user_interaction() {
    local PREFS_FILE="/tmp/build_prefs.sh"
    
    _log_debug "Starting user interaction to gather build preferences..."
    
    # Call get_build_preferences from interactive_ui.sh
    if ! get_build_preferences; then
        _log_debug "User cancelled or error during preference selection"
        return 1
    fi
    
    # Check if the prefs file was created successfully
    if [[ ! -f "$PREFS_FILE" ]]; then
        _log_debug "Error: Preferences file not created at $PREFS_FILE"
        return 1
    fi
    
    # Source the prefs file to export variables back to the caller's environment
    _log_debug "Sourcing preferences from $PREFS_FILE"
    # shellcheck disable=SC1090
    source "$PREFS_FILE" || {
        _log_debug "Error: Failed to source preferences file $PREFS_FILE"
        return 1
    }
    
    # Verify key variables were set
    if [[ -z "${DOCKER_USERNAME:-}" || -z "${DOCKER_REPO_PREFIX:-}" || -z "${SELECTED_BASE_IMAGE:-}" ]]; then
        _log_debug "Error: Required variables not set after sourcing preferences"
        return 1
    }
    
    _log_debug "User interaction completed successfully"
    return 0
}

# Execute the function if the script is run directly (for testing)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Running user_interaction.sh directly for testing..."
    handle_user_interaction
    exit $?
fi

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── user_interaction.sh <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Handles user interaction for gathering build preferences.
# Author: GitHub Copilot
# COMMIT-TRACKING: UUID-20240806-103000-MODULAR
