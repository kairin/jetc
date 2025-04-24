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

# Always load .env before calling get_user_preferences
load_env_variables

# Always call get_user_preferences (do not skip if PREFS_FILE exists)
get_user_preferences
if [ $? -ne 0 ]; then
  echo "User cancelled or error in preferences dialog. Exiting build."
  exit 1
fi

# Always source the exported preferences so all variables are available for the build process
if [ -f "$PREFS_FILE" ]; then
  # shellcheck disable=SC1090
  source "$PREFS_FILE"
  # Reload .env to get any updates from update_env_file
  load_env_variables
  # Export lowercase 'platform' for compatibility with build_stages.sh
  if [ -n "$PLATFORM" ]; then
    export platform="$PLATFORM"
  fi
else
  echo "Error: Preferences file $PREFS_FILE not found after get_user_preferences."
  exit 1
fi
