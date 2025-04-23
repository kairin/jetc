#!/bin/bash

# Post-build menu helpers for Jetson Container build system

SCRIPT_DIR_POST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR_POST/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_POST/docker_helpers.sh" || { echo "Error: docker_helpers.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_POST/verification.sh" || { echo "Error: verification.sh not found."; exit 1; }

show_dialog_menu() {
  # ...existing code for show_dialog_menu from build_ui.sh...
}

show_text_menu() {
  # ...existing code for show_text_menu from build_ui.sh...
}

show_post_build_menu() {
  # ...existing code for show_post_build_menu from build_ui.sh...
}

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── post_build_menu.sh <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Post-build menu logic for Jetson Container build system (run, verify, skip, etc).
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250423-232231-PSTBM
