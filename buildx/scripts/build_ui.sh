#!/bin/bash
#
# Description: UI functions bridge for the build process. DEPRECATED.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250421-020700-REFA

######################################################################
# THIS FILE IS DEPRECATED AND CAN BE DELETED
# Reason: Functionality consolidated into user_interaction.sh which
#         directly sources dialog_ui.sh (or its fallback).
#         build.sh now sources user_interaction.sh directly.
# You do NOT need this file anymore.
######################################################################

# Source necessary utilities (kept for historical reference, but not used by build.sh anymore)
SCRIPT_DIR_BUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
# source "$SCRIPT_DIR_BUI/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# shellcheck disable=SC1091
# source "$SCRIPT_DIR_BUI/docker_helpers.sh" || { echo "Error: docker_helpers.sh not found."; exit 1; }
# shellcheck disable=SC1091
# source "$SCRIPT_DIR_BUI/verification.sh" || { echo "Error: verification.sh not found."; exit 1; }
# shellcheck disable=SC1091
# source "$SCRIPT_DIR_BUI/env_helpers.sh" || { echo "Error: env_helpers.sh not found."; exit 1; }
# Source the consolidated interactive UI script (dialog_ui.sh)
# shellcheck disable=SC1091
# source "$SCRIPT_DIR_BUI/dialog_ui.sh" || { echo "Error: dialog_ui.sh not found."; exit 1; }


# Function for conditional debug logging (copied from original, now unused)
_log_debug() {
  # if [[ "${JETC_DEBUG}" == "true" || "${JETC_DEBUG}" == "1" ]]; then
  #   echo "DEBUG (build_ui.sh - DEPRECATED): $1" >&2
  # fi
  : # No-op
}

_log_debug "build_ui.sh sourced (DEPRECATED)."

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── build_ui.sh        <- THIS FILE (DEPRECATED)
# └── ...                        <- Other project files
#
# Description: UI functions bridge. DEPRECATED - Functionality moved to user_interaction.sh.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-095000-DEPRECATE
