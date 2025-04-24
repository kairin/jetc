#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/user_interaction.sh

# Source necessary utilities and UI functions
SCRIPT_DIR_UI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR_UI/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_UI/dialog_ui.sh" || { echo "Error: dialog_ui.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_UI/env_update.sh" || { echo "Error: env_update.sh not found."; exit 1; }

# =========================================================================
# Function: Handle User Interaction for Build Preferences
# Description: Calls the appropriate UI function (dialog or basic) to get
#              user preferences, sources the resulting temporary file,
#              and updates the main .env file.
# Exports: Variables sourced from the temporary preferences file.
# Returns: 0 on success, 1 on user cancellation or error.
# =========================================================================
handle_user_interaction() {
    echo "Starting user interaction for build preferences..."

    # Call the function from dialog_ui.sh (which handles fallback to basic)
    # This function creates /tmp/build_prefs.sh on success
    if ! get_user_preferences; then
        echo "User cancelled or error during preference selection. Exiting build." >&2
        return 1
    fi

    # Source the temporary file created by get_user_preferences to load selections
    local PREFS_FILE="/tmp/build_prefs.sh"
    if [ -f "$PREFS_FILE" ]; then
        echo "Sourcing build preferences from $PREFS_FILE..."
        # shellcheck disable=SC1090
        source "$PREFS_FILE"
        echo "Build preferences sourced successfully."
        # Optional: Clean up the temp file immediately after sourcing if desired
        # rm -f "$PREFS_FILE"
    else
        echo "Error: Preferences file $PREFS_FILE not found after successful interaction." >&2
        return 1
    fi

    # Update the main .env file with persistent settings (user, registry, prefix, base image)
    # These variables should now be set in the environment from sourcing PREFS_FILE
    echo "Updating .env file with selected persistent settings..."
    if ! update_env_file_from_prefs "${DOCKER_USERNAME:-}" "${DOCKER_REGISTRY:-}" "${DOCKER_REPO_PREFIX:-}" "${SELECTED_BASE_IMAGE:-}"; then
        echo "Warning: Failed to update .env file. Proceeding with current settings for this run only." >&2
        # Continue the build even if .env update fails, as prefs are sourced for this run
    else
        echo ".env file updated successfully."
    fi

    echo "User interaction completed successfully."
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
# Description: Orchestrates user interaction for build preferences using UI helpers and updates .env.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-095000-USERINT
