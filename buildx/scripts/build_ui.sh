#!/bin/bash
#
# Description: UI functions for the build process (dialogs, prompts, .env handling).
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250421-020700-REFA

# Source necessary utilities
SCRIPT_DIR_BUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BUI/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BUI/docker_helpers.sh" || { echo "Error: docker_helpers.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BUI/verification.sh" || { echo "Error: verification.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BUI/env_helpers.sh" || { echo "Error: env_helpers.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BUI/dialog_ui.sh" || { echo "Error: dialog_ui.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BUI/post_build_menu.sh" || { echo "Error: post_build_menu.sh not found."; exit 1; }

# Always resolve .env to canonical location (same as build.sh and jetcrun.sh)
ENV_CANONICAL="$(cd "$SCRIPT_DIR_BUI/.." && pwd)/.env"

# COMMIT-TRACKING: UUID-20250423-232231-BUIU
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── build_ui.sh        <- THIS FILE
# └── ...                        <- Other project files
#
# Description: UI functions for interactive build process, dialog and prompt handling, .env management, and post-build menu.
# Author: Mr K / GitHub Copilot

# Function for conditional debug logging
_log_debug() {
  if [[ "${JETC_DEBUG}" == "true" || "${JETC_DEBUG}" == "1" ]]; then
    echo "DEBUG: $1" >&2
  fi
}

# Set PREFS_FILE before calling get_user_preferences
PREFS_FILE="/tmp/build_prefs.sh"
_log_debug "PREFS_FILE set to $PREFS_FILE"

# Always load .env before calling get_user_preferences
_log_debug "Loading .env variables before preference check..."
load_env_variables

# Only call get_user_preferences if PREFS_FILE does not exist or is empty
if [ ! -s "$PREFS_FILE" ]; then
  _log_debug "$PREFS_FILE does not exist or is empty. Calling get_user_preferences..."
  get_user_preferences
  prefs_exit_code=$?
  _log_debug "get_user_preferences exited with code $prefs_exit_code"
  if [ $prefs_exit_code -ne 0 ]; then
    echo "User cancelled or error in preferences dialog/prompts. Exiting build." >&2
    exit 1
  fi
else
  _log_debug "$PREFS_FILE exists and is not empty. Skipping get_user_preferences."
fi

# Always source the exported preferences so all variables are available for the build process
_log_debug "Sourcing preferences from $PREFS_FILE..."
if [ -f "$PREFS_FILE" ]; then
  # shellcheck disable=SC1090
  source "$PREFS_FILE"
  # Reload .env to get any updates from update_env_file
  _log_debug "Reloading .env variables after sourcing preferences..."
  load_env_variables
  # Export lowercase 'platform' for compatibility with build_stages.sh
  if [ -n "$PLATFORM" ]; then
    export platform="$PLATFORM"
    _log_debug "Exported lowercase platform=$platform"
  fi
else
  echo "Error: Preferences file $PREFS_FILE not found after get_user_preferences check. Cannot proceed." >&2
  exit 1
fi
_log_debug "Finished build_ui.sh execution."

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── build_ui.sh        <- THIS FILE
# └── ...                        <- Other project files
#
# Description: UI functions for build process. Added conditional debug logging via JETC_DEBUG=true.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-121500-DBGVAR
