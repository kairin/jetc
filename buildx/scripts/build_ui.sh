#!/bin/bash
#
# Description: UI functions bridge for the build process. Sources interactive_ui.sh.
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
# Source the consolidated interactive UI script
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BUI/interactive_ui.sh" || { echo "Error: interactive_ui.sh not found."; exit 1; }
# post_build_menu.sh is now part of interactive_ui.sh
# dialog_ui.sh is now interactive_ui.sh

# Always resolve .env to canonical location (defined in utils.sh)

# Function for conditional debug logging (copied from original)
_log_debug() {
  if [[ "${JETC_DEBUG}" == "true" || "${JETC_DEBUG}" == "1" ]]; then
    echo "DEBUG (build_ui.sh): $1" >&2
  fi
}

# This script now primarily acts as a source aggregator if needed,
# but build.sh sources interactive_ui.sh directly.
# The logic previously here for calling get_user_preferences is removed
# as build.sh handles it directly.

_log_debug "build_ui.sh sourced."

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── build_ui.sh        <- THIS FILE
# └── ...                        <- Other project files
#
# Description: UI functions bridge. Updated to source interactive_ui.sh. Role reduced.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20240806-103000-MODULAR
