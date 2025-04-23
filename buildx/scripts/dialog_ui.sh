#!/bin/bash

# Dialog UI helpers for Jetson Container build system

SCRIPT_DIR_DLG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR_DLG/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_DLG/env_helpers.sh" || { echo "Error: env_helpers.sh not found."; exit 1; }

get_user_preferences() {
  # ...existing code from build_ui.sh get_user_preferences...
}

get_user_preferences_basic() {
  # ...existing code from build_ui.sh get_user_preferences_basic...
}

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── dialog_ui.sh       <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Dialog UI logic for Jetson Container build system (user preferences, build options, folder selection).
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250423-232231-DLGUI
