#!/bin/bash
# Main build script for Jetson Container project

# Strict mode - Keep pipefail, temporarily manage errexit (-e)
set -uo pipefail # REMOVED -e temporarily

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export SCRIPT_DIR

# --- Source Core Dependencies (Order Matters!) ---
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/logging.sh" || { echo "Error: logging.sh not found."; exit 1; }
init_logging # Initialize logging AFTER sourcing

# ... (sourcing env_setup, utils, env_update, dialog_ui, docker_helpers, verification) ...
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

# Source system_checks.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/system_checks.sh" || { echo "Error: system_checks.sh not found."; exit 1; }

# <<< --- ADDED DEBUG CHECK --- >>>
if declare -f check_dependencies > /dev/null; then
    log_debug "DEBUG: check_dependencies function IS defined after sourcing system_checks.sh."
else
    log_error "DEBUG: check_dependencies function IS NOT defined after sourcing system_checks.sh."
    # Optionally exit here if it's critical
    # exit 1
fi
# <<< --- END DEBUG CHECK --- >>>

# ... (sourcing buildx_setup, user_interaction, build_order, build_stages, tagging, post_build_menu) ...
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
# Enable errexit after sourcing and basic setup
set -e
# Line 28 where the error occurred:
check_dependencies "docker" "dialog"

# --- Main Build Process ---
main() {
    # ... (main function remains the same) ...
}

# --- Script Execution ---\
trap cleanup EXIT INT TERM # cleanup should be defined in system_checks.sh
main
exit $?

# --- Footer ---
# Description: Main build script orchestrator. Added check after sourcing system_checks.sh.
# Author: kairin / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-213000-CHECKSYSDEBUG
