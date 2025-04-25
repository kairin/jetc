#!/bin/bash
# filepath: /media/kkk/Apps/jetc/buildx/scripts/user_interaction.sh

# =========================================================================
# User Interaction Script
# Responsibility: Handle user choices for build configuration via dialog/prompts.
#                 Update .env file and export choices for the current build run.
# Relies on logging functions sourced by the main script.
# Relies on utils.sh, interactive_ui.sh, env_setup.sh, env_update.sh sourced by main script.
# =========================================================================

# --- Dependencies ---
SCRIPT_DIR_UI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# DO NOT source dependencies here. Assume they are sourced by the main build.sh script.
# Check if required functions/variables exist as a safety measure.
if ! declare -f log_info > /dev/null || ! declare -f get_build_preferences > /dev/null || ! declare -f update_env_var > /dev/null; then
     # Use echo for critical bootstrap errors as logging might not be fully ready
     echo "CRITICAL ERROR: Required functions (log_info, get_build_preferences, update_env_var) not found in user_interaction.sh. Ensure main script sources dependencies correctly." >&2
     exit 1
fi

# --- Main Function ---

# Handle user interaction to get build preferences
# Exports:
#   SELECTED_BASE_IMAGE, SELECTED_FOLDERS_LIST, use_cache, use_squash,
#   skip_intermediate_push_pull, use_builder,
#   DOCKER_USERNAME, DOCKER_REPO_PREFIX, DOCKER_REGISTRY
# Returns: 0 on success, 1 on cancellation or error
handle_user_interaction() {
    log_info "--- Starting User Interaction ---"

    # Use get_build_preferences from interactive_ui.sh
    # It should populate /tmp/build_prefs.sh upon success (exit code 0)
    if ! get_build_preferences; then
        log_error "User cancelled or error in build preferences menu."
        return 1
    fi

    # Source the temporary file to get user selections into the current shell
    local prefs_file="/tmp/build_prefs.sh"
    if [[ -f "$prefs_file" ]]; then
        log_debug "Sourcing user preferences from $prefs_file"
        # shellcheck disable=SC1090
        source "$prefs_file"
        # Optionally remove the temp file now if no longer needed
        # rm "$prefs_file"
    else
        log_error "Build preferences file ($prefs_file) not found after menu success."
        return 1
    fi

    # --- Export selections for the current build run ---
    # These variables were set by sourcing $prefs_file
    export SELECTED_BASE_IMAGE="${SELECTED_BASE_IMAGE:-}"
    export SELECTED_FOLDERS_LIST="${SELECTED_FOLDERS_LIST:-}"
    export use_cache="${use_cache:-y}" # Default to use cache if not set in prefs
    export use_squash="${use_squash:-n}" # Default to no squash if not set in prefs
    export skip_intermediate_push_pull="${skip_intermediate_push_pull:-y}" # Default to local build (load) if not set
    export use_builder="${use_builder:-y}" # Default to use buildx builder if not set
    export DOCKER_USERNAME="${DOCKER_USERNAME:-}"
    export DOCKER_REPO_PREFIX="${DOCKER_REPO_PREFIX:-}"
    export DOCKER_REGISTRY="${DOCKER_REGISTRY:-}"

    # Validate essential selections that should have been set by the UI
    if [[ -z "$SELECTED_BASE_IMAGE" ]]; then
        log_error "No base image selected or retrieved from preferences."
        return 1
    fi
     if [[ -z "$SELECTED_FOLDERS_LIST" ]]; then
        log_warning "No build stages selected by the user."
        # Allow proceeding with no stages, build.sh will handle this.
    fi
     if [[ -z "${DOCKER_USERNAME:-}" || -z "${DOCKER_REPO_PREFIX:-}" ]]; then
         log_error "Docker username or repository prefix not set or retrieved from preferences."
         # These should have been prompted by the dialog UI if empty in .env or prefs
         return 1
     fi

    log_success "User interaction completed successfully"
    log_info "Selections exported:"
    log_info "  Base Image: $SELECTED_BASE_IMAGE"
    log_info "  Selected Stages: $SELECTED_FOLDERS_LIST"
    log_info "  Docker User: ${DOCKER_USERNAME}"
    log_info "  Docker Repo Prefix: ${DOCKER_REPO_PREFIX}"
    [[ -n "${DOCKER_REGISTRY:-}" ]] && log_info "  Docker Registry: ${DOCKER_REGISTRY}"
    log_info "  Use Cache: $use_cache"
    log_info "  Use Squash: $use_squash"
    log_info "  Skip Push/Pull (Build Locally): $skip_intermediate_push_pull"
    log_info "  Use Buildx Builder: $use_builder"

    # --- Update .env file with persistent settings ---
    # Update Docker credentials regardless (in case they were confirmed/changed)
    log_debug "Updating Docker credentials in .env"
    update_env_var "DOCKER_USERNAME" "${DOCKER_USERNAME}"
    update_env_var "DOCKER_REPO_PREFIX" "${DOCKER_REPO_PREFIX}"
    update_env_var "DOCKER_REGISTRY" "${DOCKER_REGISTRY:-}" # Save registry even if empty

    # Optionally update the default base image (consider if this is desired behavior)
    # log_debug "Updating DEFAULT_BASE_IMAGE in .env to $SELECTED_BASE_IMAGE"
    # update_env_var "DEFAULT_BASE_IMAGE" "$SELECTED_BASE_IMAGE"

    return 0
}


# --- Main Execution (for testing) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Running user_interaction.sh directly for testing..."
    # If testing directly, need to manually source ALL dependencies first
    # This requires careful setup and potentially mocking .env and dialog
    echo "ERROR: Direct execution for testing requires manual setup of dependencies."
    echo "       (logging, env_setup, utils, interactive_ui, env_update)"
    # Example minimal setup (adjust paths as needed):
    # export SCRIPT_DIR_UI=$(pwd) # Assuming running from scripts dir
    # source ./logging.sh && init_logging || exit 1
    # source ./utils.sh || exit 1
    # source ./env_setup.sh || exit 1 # This defines ENV_FILE
    # source ./interactive_ui.sh || exit 1
    # source ./env_update.sh || exit 1
    # export ENV_FILE="/tmp/test_ui_env_$$.env"; touch "$ENV_FILE" # Mock .env
    # handle_user_interaction; result=$? ; rm "$ENV_FILE" ; exit $result
    exit 1 # Prevent accidental execution without proper setup
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
