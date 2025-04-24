#!/bin/bash
# Main build script for Jetson Container project

# Strict mode
set -euo pipefail

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR # Export for use in sourced scripts

# --- Source Core Dependencies (Order Matters!) ---
# (Sourcing commands remain the same)
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
source "$SCRIPT_DIR/scripts/dialog_ui.sh" || { echo "Error: dialog_ui.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/docker_helpers.sh" || { echo "Error: docker_helpers.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/verification.sh" || { echo "Error: verification.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/system_checks.sh" || { echo "Error: system_checks.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/buildx_setup.sh" || { echo "Error: buildx_setup.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/user_interaction.sh" || { echo "Error: user_interaction.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/build_order.sh" || { echo "Error: build_order.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/build_stages.sh" || { echo "Error: build_stages.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/tagging.sh" || { echo "Error: tagging.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/post_build_menu.sh" || { echo "Error: post_build_menu.sh not found."; exit 1; }


# --- Configuration ---\
export BUILD_DIR="$SCRIPT_DIR/build"

# --- Initialization ---\
log_start
check_dependencies "docker" "dialog"

# --- Main Build Process ---\
main() {
    log_info "Starting Jetson Container Build Process..."
    log_debug "JETC_DEBUG is set to: ${JETC_DEBUG}"

    # Track overall build status
    BUILD_FAILED=0

    # (Debug block moved here previously is fine, can be removed if desired)

    # 1. Handle User Interaction (Gets prefs, updates .env, exports vars for this run)
    log_debug "Step 1: Handling user interaction..."
    local interaction_status=0
    if ! handle_user_interaction; then
        interaction_status=$? # Capture the actual return code
        log_error "Build cancelled by user or error during interaction (Exit Code: $interaction_status)."
        BUILD_FAILED=1
    else
        interaction_status=$? # Capture success code (should be 0)
        log_debug "handle_user_interaction finished successfully (Exit Code: $interaction_status)."
    fi

    # <<< --- ADDED DEBUGGING --- >>>
    log_debug "After handle_user_interaction: interaction_status=$interaction_status, BUILD_FAILED=$BUILD_FAILED"
    log_debug "Checking condition to proceed to Step 2 (BUILD_FAILED == 0)..."
    # <<< --- END ADDED DEBUGGING --- >>>

    # 2. Setup Buildx Builder (Only if Step 1 succeeded)
    if [[ $BUILD_FAILED -eq 0 ]]; then
        log_debug "Step 2: Setting up Docker buildx builder..." # Check if this log appears
        if ! setup_buildx; then
            log_error "Failed to setup Docker buildx builder. Cannot proceed."
            BUILD_FAILED=1
        else
            log_success "Docker buildx builder setup complete."
        fi
    else
        log_warning "Skipping Step 2 (Buildx Setup) because BUILD_FAILED is $BUILD_FAILED."
    fi

    # 3. Determine Build Order (Only if previous steps succeeded)
    if [[ $BUILD_FAILED -eq 0 ]]; then
        log_debug "Step 3: Determining build order..." # Check if this log appears
        if ! determine_build_order "$BUILD_DIR" "${SELECTED_FOLDERS_LIST:-}"; then
            log_error "Failed to determine build order."
            BUILD_FAILED=1
        else
            log_success "Build order determined."
        fi
    else
        log_warning "Skipping Step 3 (Build Order) because BUILD_FAILED is $BUILD_FAILED."
    fi

    # ... (rest of steps 4-8 with similar checks) ...
    # Add log_debug at the start of each step's block
    # Add log_warning in the 'else' part of each `if [[ $BUILD_FAILED -eq 0 ]]`

    log_end # Log script end
    log_info "Returning overall build status: $BUILD_FAILED" # Log final status
    return $BUILD_FAILED # Return overall status
}


# --- Script Execution ---\
trap cleanup EXIT INT TERM
main
exit $?

# --- Footer ---
# Description: Main build script orchestrator. Added debugging after user interaction.
# Author: kairin / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-211500-POSTUIDEBUG
