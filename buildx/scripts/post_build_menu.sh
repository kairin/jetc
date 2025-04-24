######################################################################
# THIS FILE CAN BE DELETED
# All content consolidated in scripts/interactive_ui.sh (show_post_build_menu function)
# You do NOT need this file anymore.
######################################################################

#!/bin/bash

# Post-build menu functions for Jetson Container build system

SCRIPT_DIR_POST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR_POST/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_POST/interactive_ui.sh" || { echo "Error: interactive_ui.sh not found."; exit 1; } # Contains show_post_build_menu
# Source logging functions if available
# shellcheck disable=SC1091
source "$SCRIPT_DIR_POST/env_setup.sh" 2>/dev/null || true

# =========================================================================
# Function: Run the post-build menu
# Arguments: $1 = Last successful image tag, $2 = Final timestamp tag (optional)
# Returns: Exit status of the chosen action or 0 if skipped/cancelled
# =========================================================================
run_post_build_menu() {
    local last_successful_tag="${1:-}"
    local final_timestamp_tag="${2:-}"
    local tag_to_use=""

    log_debug "Entering run_post_build_menu."
    log_debug "Last Successful Tag: $last_successful_tag"
    log_debug "Final Timestamp Tag: $final_timestamp_tag"

    if [[ -n "$final_timestamp_tag" ]]; then
        tag_to_use="$final_timestamp_tag"
        log_debug "Using final timestamp tag for menu: $tag_to_use"
    elif [[ -n "$last_successful_tag" ]]; then
        tag_to_use="$last_successful_tag"
        log_debug "Using last successful tag for menu: $tag_to_use"
    else
        log_error "No valid image tag provided to post-build menu. Cannot proceed." # Use log_error
        return 1
    fi

    # Call the UI function from interactive_ui.sh
    log_info "Displaying post-build menu for image: $tag_to_use" # Use log_info
    show_post_build_menu "$tag_to_use"
    local menu_exit_status=$?
    log_debug "Post-build menu action exited with status: $menu_exit_status"

    return $menu_exit_status
}

# --- Footer ---
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── post_build_menu.sh <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Displays a menu after the build process completes.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250425-080000-42595D
