#!/bin/bash
# Main build script for Jetson Container project

# Strict mode
set -euo pipefail

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR # Export for use in sourced scripts

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

    # --- <<< MOVED DEBUG BLOCK START >>> ---
    log_debug "--- Pre-User Interaction Check ---"
    log_debug "Checking existence of dependencies required by user_interaction.sh:"
    declare -f log_info > /dev/null && log_debug "  [OK] log_info function exists." || log_error "  [FAIL] log_info function NOT FOUND."
    declare -f show_main_menu > /dev/null && log_debug "  [OK] show_main_menu function exists." || log_error "  [FAIL] show_main_menu function NOT FOUND."
    declare -f update_env_var > /dev/null && log_debug "  [OK] update_env_var function exists." || log_error "  [FAIL] update_env_var function NOT FOUND."
    if [[ -z "${AVAILABLE_IMAGES:-}" ]]; then
        log_error "  [FAIL] AVAILABLE_IMAGES variable is empty or unset."
    else
        # Use local inside the function now
        local avail_img_preview="${AVAILABLE_IMAGES:0:100}"
        [[ ${#AVAILABLE_IMAGES} -gt 100 ]] && avail_img_preview+="..."
        log_debug "  [OK] AVAILABLE_IMAGES variable is set (starts with: '${avail_img_preview}')"
    fi
    log_debug "--- End Pre-User Interaction Check ---"
    # --- <<< MOVED DEBUG BLOCK END >>> ---

    # 1. Handle User Interaction (Gets prefs, updates .env, exports vars for this run)
    log_debug "Step 1: Handling user interaction..."
    if ! handle_user_interaction; then
        log_error "Build cancelled by user or error during interaction."
        BUILD_FAILED=1
    fi

    # ... (rest of steps 2-8 and post-build actions remain the same) ...

    log_end # Log script end
    return $BUILD_FAILED # Return overall status
}


# --- Script Execution ---\
trap cleanup EXIT INT TERM
main
exit $?

# --- Footer ---
# Description: Main build script orchestrator. Moved debug block into main().
# Author: kairin / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-210500-DEBUGMOVE
