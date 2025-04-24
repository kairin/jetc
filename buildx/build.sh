#!/bin/bash
# Main build script for Jetson Container project

# Strict mode
set -euo pipefail

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR # Export for use in sourced scripts

# --- Source Core Dependencies (Order Matters!) ---

# 1. Logging (Must be first)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/logging.sh" || { echo "Error: logging.sh not found."; exit 1; }
init_logging # Initialize logging AFTER sourcing

# 2. Environment Setup (Loads .env, sets basic ARCH, PLATFORM, AVAILABLE_IMAGES etc.)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/env_setup.sh" || { echo "Error: env_setup.sh not found."; exit 1; }

# 3. Utilities (General helpers, needed by many others)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }

# 4. .env Update Functions (Needed by user_interaction)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/env_update.sh" || { echo "Error: env_update.sh not found."; exit 1; }

# 5. Dialog UI Functions (Needed by user_interaction, post_build_menu)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/dialog_ui.sh" || { echo "Error: dialog_ui.sh not found."; exit 1; }

# 6. Docker Helpers (Needed by build_stages, verification, tagging)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/docker_helpers.sh" || { echo "Error: docker_helpers.sh not found."; exit 1; }

# 7. Verification Functions (Host launchers needed by post_build_menu)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/verification.sh" || { echo "Error: verification.sh not found."; exit 1; }

# 8. System Checks (Needed early for dependency checks)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/system_checks.sh" || { echo "Error: system_checks.sh not found."; exit 1; }

# 9. Buildx Setup (Needed before build stages)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/buildx_setup.sh" || { echo "Error: buildx_setup.sh not found."; exit 1; }

# --- <<< ADD DEBUG BLOCK START >>> ---
log_debug "--- Pre-User Interaction Check ---"
log_debug "Checking existence of dependencies required by user_interaction.sh:"
declare -f log_info > /dev/null && log_debug "  [OK] log_info function exists." || log_error "  [FAIL] log_info function NOT FOUND."
declare -f show_main_menu > /dev/null && log_debug "  [OK] show_main_menu function exists." || log_error "  [FAIL] show_main_menu function NOT FOUND."
declare -f update_env_var > /dev/null && log_debug "  [OK] update_env_var function exists." || log_error "  [FAIL] update_env_var function NOT FOUND."
if [[ -z "${AVAILABLE_IMAGES:-}" ]]; then
    log_error "  [FAIL] AVAILABLE_IMAGES variable is empty or unset."
else
    # Log only a portion if it's very long
    local avail_img_preview="${AVAILABLE_IMAGES:0:100}"
    [[ ${#AVAILABLE_IMAGES} -gt 100 ]] && avail_img_preview+="..."
    log_debug "  [OK] AVAILABLE_IMAGES variable is set (starts with: '${avail_img_preview}')"
fi
log_debug "--- End Pre-User Interaction Check ---"
# --- <<< ADD DEBUG BLOCK END >>> ---

# 10. User Interaction (Needs dialog_ui, env_update, env_setup)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/user_interaction.sh" || { echo "Error: user_interaction.sh not found."; exit 1; }

# 11. Build Order Logic (Needs user_interaction results implicitly)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/build_order.sh" || { echo "Error: build_order.sh not found."; exit 1; }

# 12. Build Stages Execution (Needs docker_helpers, build_order vars)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/build_stages.sh" || { echo "Error: build_stages.sh not found."; exit 1; }

# 13. Tagging Functions (Needs docker_helpers, env_setup)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/tagging.sh" || { echo "Error: tagging.sh not found."; exit 1; }

# 14. Post-Build Menu (Needs dialog_ui, verification, docker_helpers)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/post_build_menu.sh" || { echo "Error: post_build_menu.sh not found."; exit 1; }


# --- Configuration ---\
export BUILD_DIR="$SCRIPT_DIR/build"
# LOG_DIR, MAIN_LOG, ERROR_LOG are set by logging.sh/init_logging
# JETC_DEBUG is loaded/defaulted by env_setup.sh

# --- Initialization ---\
log_start # Log script start

# Check essential dependencies (uses function from system_checks.sh)
# Run this *after* all sourcing is done
check_dependencies "docker" "dialog"

# --- Main Build Process ---
main() {
    # ... (rest of main function remains the same) ...
    log_info "Starting Jetson Container Build Process..."
    log_debug "JETC_DEBUG is set to: ${JETC_DEBUG}"

    # Track overall build status
    BUILD_FAILED=0

    # 1. Handle User Interaction (Gets prefs, updates .env, exports vars for this run)
    log_debug "Step 1: Handling user interaction..."
    # Needs: user_interaction.sh, dialog_ui.sh, env_update.sh
    if ! handle_user_interaction; then
        log_error "Build cancelled by user or error during interaction."
        BUILD_FAILED=1
    fi

    # ... (rest of steps 2-8 and post-build actions) ...

    log_end # Log script end
    return $BUILD_FAILED # Return overall status
}


# --- Script Execution ---\
# Ensure cleanup runs on exit (cleanup function is in system_checks.sh)
trap cleanup EXIT INT TERM

# Run the main function and exit with its status code
main
exit $?

# --- Footer ---
# File location diagram: ... (omitted)
# Description: Main build script orchestrator. Added debug block before sourcing user_interaction.sh.
# Author: kairin / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-210000-SOURCEDEBUG
