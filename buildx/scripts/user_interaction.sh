#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/user_interaction.sh

# =========================================================================
# User Interaction Script
# Responsibility: Handle user choices for build configuration via dialog/prompts.
#                 Update .env file and export choices for the current build run.
# Relies on logging functions sourced by the main script.
# Relies on utils.sh, dialog_ui.sh, env_setup.sh, env_update.sh sourced by main script or caller.
# =========================================================================

# --- Dependencies ---\
SCRIPT_DIR_UI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# DO NOT source logging.sh, env_setup.sh, utils.sh, dialog_ui.sh, env_update.sh here.
# Assume they are sourced by the main build.sh script.
# Check if required functions/variables exist as a safety measure.
# --- MODIFICATION START ---
# Check for get_build_preferences instead of show_main_menu
if ! declare -f log_info > /dev/null || ! declare -f get_build_preferences > /dev/null || ! declare -f update_env_var > /dev/null; then
     echo "CRITICAL ERROR: Required functions/variables (log_info, get_build_preferences, update_env_var) not found in user_interaction.sh. Ensure main script sources dependencies." >&2
     exit 1
fi
# --- MODIFICATION END ---

# --- Main Function ---

# Handle user interaction to get build preferences
# Exports:
#   SELECTED_BASE_IMAGE, SELECTED_FOLDERS_LIST, use_cache, use_squash,
#   skip_intermediate_push_pull, use_builder
# Returns: 0 on success, 1 on cancellation or error
handle_user_interaction() {
    log_info "--- Starting User Interaction ---"

    # --- MODIFICATION START ---
    # Use get_build_preferences from interactive_ui.sh
    # It should populate /tmp/build_prefs.sh
    if ! get_build_preferences; then
        log_error "User cancelled or error in build preferences menu."
        return 1
    fi
    # --- MODIFICATION END ---

    # Source the temporary file to get user selections
    local prefs_file="/tmp/build_prefs.sh"
    if [[ -f "$prefs_file" ]]; then
        log_debug "Sourcing user preferences from $prefs_file"
        # shellcheck disable=SC1090
        source "$prefs_file"
        # Optionally remove the temp file now
        # rm "$prefs_file"
    else
        log_error "Build preferences file ($prefs_file) not found after menu."
        return 1
    fi

    # --- Export selections for the current build run ---
    # These variables were set by sourcing $prefs_file
    export SELECTED_BASE_IMAGE="${SELECTED_BASE_IMAGE:-}"
    export SELECTED_FOLDERS_LIST="${SELECTED_FOLDERS_LIST:-}"
    export use_cache="${use_cache:-y}" # Default to use cache
    export use_squash="${use_squash:-n}" # Default to no squash
    export skip_intermediate_push_pull="${skip_intermediate_push_pull:-y}" # Default to local build (load)
    export use_builder="${use_builder:-y}" # Default to use buildx builder
    # DOCKER_USERNAME, DOCKER_REPO_PREFIX, DOCKER_REGISTRY are also set from prefs_file

    # Validate essential selections
    if [[ -z "$SELECTED_BASE_IMAGE" ]]; then
        log_error "No base image selected."
        return 1
    fi
     if [[ -z "$SELECTED_FOLDERS_LIST" ]]; then
        log_warning "No build stages selected by the user."
        # Allow proceeding with no stages? Or return 1? For now, allow.
    fi
     if [[ -z "${DOCKER_USERNAME:-}" || -z "${DOCKER_REPO_PREFIX:-}" ]]; then
         log_error "Docker username or repository prefix not set."
         # These should have been prompted by the dialog UI if empty in .env
         return 1
     fi


    log_success "User interaction completed successfully"
    log_info "Selections:"
    log_info "  Base Image: $SELECTED_BASE_IMAGE"
    log_info "  Selected Stages: $SELECTED_FOLDERS_LIST"
    log_info "  Docker User: ${DOCKER_USERNAME}"
    log_info "  Docker Repo Prefix: ${DOCKER_REPO_PREFIX}"
    [[ -n "${DOCKER_REGISTRY:-}" ]] && log_info "  Docker Registry: ${DOCKER_REGISTRY}"
    log_info "  Use Cache: $use_cache"
    log_info "  Use Squash: $use_squash"
    log_info "  Skip Push/Pull (Build Locally): $skip_intermediate_push_pull"
    log_info "  Use Buildx Builder: $use_builder"

    # --- Update .env file with persistent settings (optional) ---
    # Example: Update the default base image if the user chose a different one
    # log_debug "Updating DEFAULT_BASE_IMAGE in .env to $SELECTED_BASE_IMAGE"
    # update_env_var "DEFAULT_BASE_IMAGE" "$SELECTED_BASE_IMAGE" # Uses function from env_update.sh

    # Update Docker credentials if they were entered/confirmed
    log_debug "Updating Docker credentials in .env"
    update_env_var "DOCKER_USERNAME" "${DOCKER_USERNAME}"
    update_env_var "DOCKER_REPO_PREFIX" "${DOCKER_REPO_PREFIX}"
    update_env_var "DOCKER_REGISTRY" "${DOCKER_REGISTRY:-}" # Save registry even if empty

    return 0
}


# --- Main Execution (for testing) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # If testing directly, source dependencies first
    if [ -f "$SCRIPT_DIR_UI/logging.sh" ]; then source "$SCRIPT_DIR_UI/logging.sh"; init_logging; else echo "ERROR: Cannot find logging.sh for test."; exit 1; fi
    if [ -f "$SCRIPT_DIR_UI/env_setup.sh" ]; then source "$SCRIPT_DIR_UI/env_setup.sh"; else echo "ERROR: Cannot find env_setup.sh for test."; exit 1; fi
    if [ -f "$SCRIPT_DIR_UI/utils.sh" ]; then source "$SCRIPT_DIR_UI/utils.sh"; else echo "ERROR: Cannot find utils.sh for test."; exit 1; fi
    # Need stubs or the real interactive_ui.sh and env_update.sh for testing
    # --- MODIFICATION START ---
    # Source interactive_ui.sh instead of dialog_ui.sh
    if [ -f "$SCRIPT_DIR_UI/interactive_ui.sh" ]; then source "$SCRIPT_DIR_UI/interactive_ui.sh"; else echo "ERROR: Cannot find interactive_ui.sh for test."; exit 1; fi
    # --- MODIFICATION END ---
    if [ -f "$SCRIPT_DIR_UI/env_update.sh" ]; then source "$SCRIPT_DIR_UI/env_update.sh"; else echo "ERROR: Cannot find env_update.sh for test."; exit 1; fi

    log_info "Running user_interaction.sh directly for testing..."
    # Mock AVAILABLE_IMAGES if needed for testing interactive_ui.sh
    export AVAILABLE_IMAGES="image1:tag1;image2:tag2"
    # Mock .env file path for env_update.sh tests
    export ENV_FILE="/tmp/test_ui_env_$$.env"; touch "$ENV_FILE"

    handle_user_interaction
    result=$?
    log_info "handle_user_interaction finished with status: $result"
    # Inspect exported variables if needed
    echo "SELECTED_BASE_IMAGE=${SELECTED_BASE_IMAGE:-<unset>}"
    # Clean up mock .env
    rm "$ENV_FILE"
    log_info "User interaction test finished."
    exit $result
fi

# --- Footer ---
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── user_interaction.sh <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Handles user interaction logic, sourcing UI implementations.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250425-111500-UIFIX # New UUID for this fix
