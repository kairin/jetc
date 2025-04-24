#!/bin/bash

# Ensure we're running with bash
if [ -z "$BASH_VERSION" ]; then
  echo "Error: This script requires bash. Please run with bash ./jetcrun.sh"
  exit 1
fi

# --- Get Script Dir ---
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")/scripts
export JETC_DEBUG=true # Enable debug logging in helpers

# --- Source Helpers ---
# Source utils first as others might depend on it (e.g., for _log_debug)
source "$SCRIPT_DIR/utils.sh" || { echo "Error sourcing utils.sh"; exit 1; }
source "$SCRIPT_DIR/logging.sh" || { echo "Error sourcing logging.sh"; exit 1; } # Basic logging if needed
source "$SCRIPT_DIR/env_helpers.sh" || { echo "Error sourcing env_helpers.sh"; exit 1; }
source "$SCRIPT_DIR/interactive_ui.sh" || { echo "Error sourcing interactive_ui.sh"; exit 1; }
source "$SCRIPT_DIR/docker_helpers.sh" || { echo "Error sourcing docker_helpers.sh"; exit 1; }
source "$SCRIPT_DIR/commit_tracking.sh" || { echo "Error sourcing commit_tracking.sh"; exit 1; }

# --- Initialize ---
# init_logging "jetcrun" # Optional: Full file logging for run script
_log_debug "jetcrun.sh started."

# --- Generate and Store Runtime UUID ---
RUNTIME_UUID=$(generate_commit_uuid "JRUN")
GIT_DIR_PATH="$(git rev-parse --git-dir 2>/dev/null)"
if [[ -n "$GIT_DIR_PATH" && -d "$GIT_DIR_PATH" ]]; then
    echo "$RUNTIME_UUID" > "$GIT_DIR_PATH/LAST_RUNTIME_UUID"
    _log_debug "Stored runtime UUID ($RUNTIME_UUID) in $GIT_DIR_PATH/LAST_RUNTIME_UUID"
else
    _log_debug "Warning: Could not determine .git directory. Runtime UUID not stored for hooks."
fi

# --- Load Defaults & Available Images ---
_log_debug "Loading configuration from .env..."
load_env_variables # Load all into environment initially
DEFAULT_IMAGE=$(get_env_variable "DEFAULT_IMAGE_NAME")
DEFAULT_X11=$(get_env_variable "DEFAULT_ENABLE_X11")
DEFAULT_GPU=$(get_env_variable "DEFAULT_ENABLE_GPU")
DEFAULT_WS=$(get_env_variable "DEFAULT_MOUNT_WORKSPACE")
DEFAULT_ROOT=$(get_env_variable "DEFAULT_USER_ROOT")
# Get available images as an array
mapfile -t AVAILABLE_IMAGES_ARRAY < <(get_available_images_array)
_log_debug "Defaults loaded: Image=$DEFAULT_IMAGE, X11=$DEFAULT_X11, GPU=$DEFAULT_GPU, WS=$DEFAULT_WS, Root=$DEFAULT_ROOT"
_log_debug "Available images loaded: ${AVAILABLE_IMAGES_ARRAY[*]}"

# --- Get User Preferences via UI ---
_log_debug "Gathering user preferences via UI..."
# This function uses dialog/prompts, takes defaults/available images, and exports selections
# Exports: SELECTED_IMAGE, SELECTED_X11, SELECTED_GPU, SELECTED_WS, SELECTED_ROOT, SAVE_CUSTOM_IMAGE, CUSTOM_IMAGE_NAME
get_run_preferences "$DEFAULT_IMAGE" "$DEFAULT_X11" "$DEFAULT_GPU" "$DEFAULT_WS" "$DEFAULT_ROOT" "${AVAILABLE_IMAGES_ARRAY[@]}"
ui_exit_code=$?

if [[ $ui_exit_code -ne 0 ]]; then
    _log_debug "User cancelled or error during preference selection (code: $ui_exit_code). Exiting."
    # show_message is part of interactive_ui which might have failed if dialog wasn't installable
    echo "Operation cancelled." >&2
    exit 1
fi

# --- Validate Selection ---
if [[ -z "$SELECTED_IMAGE" ]]; then
  _log_debug "Error: No image selected after UI interaction."
  show_message "Error" "No container image was selected."
  exit 1
fi
_log_debug "User selected Image: $SELECTED_IMAGE"
_log_debug "User selected Options: X11=$SELECTED_X11, GPU=$SELECTED_GPU, WS=$SELECTED_WS, ROOT=$SELECTED_ROOT"
_log_debug "Save custom image flag: $SAVE_CUSTOM_IMAGE, Custom name: $CUSTOM_IMAGE_NAME"

# --- Confirm Action ---
_log_debug "Confirming action with user..."
if ! confirm_action "Run container '$SELECTED_IMAGE' with selected options?" true; then
 _log_debug "Operation cancelled by user at confirmation."
 echo "Operation cancelled."
 exit 0
fi

# --- Save Preferences (Post-Confirmation) ---
_log_debug "Saving selected options to .env..."
update_default_run_options "$SELECTED_IMAGE" \
                           "$([[ "$SELECTED_X11" == "true" ]] && echo "on" || echo "off")" \
                           "$([[ "$SELECTED_GPU" == "true" ]] && echo "on" || echo "off")" \
                           "$([[ "$SELECTED_WS" == "true" ]] && echo "on" || echo "off")" \
                           "$([[ "$SELECTED_ROOT" == "true" ]] && echo "on" || echo "off")"

# If a custom image was entered and user agreed to save it:
if [[ "$SAVE_CUSTOM_IMAGE" == "true" ]] && [[ -n "$CUSTOM_IMAGE_NAME" ]]; then
  _log_debug "Adding custom image '$CUSTOM_IMAGE_NAME' to AVAILABLE_IMAGES."
  # Add the custom image to the current array before saving
  # Check if it's already there (shouldn't be if it's new)
  already_present=false
  for img in "${AVAILABLE_IMAGES_ARRAY[@]}"; do
      if [[ "$img" == "$CUSTOM_IMAGE_NAME" ]]; then
          already_present=true
          break
      fi
  done
  if [[ "$already_present" == "false" ]]; then
      AVAILABLE_IMAGES_ARRAY+=("$CUSTOM_IMAGE_NAME")
      update_available_images "${AVAILABLE_IMAGES_ARRAY[@]}"
  else
       _log_debug "Custom image '$CUSTOM_IMAGE_NAME' was already in the list."
  fi
fi

# --- Prepare and Run Container ---
_log_debug "Preparing to run container '$SELECTED_IMAGE'..."
# docker_helpers.sh handles check/pull, command construction, and execution
run_container "$SELECTED_IMAGE" "$SELECTED_X11" "$SELECTED_GPU" "$SELECTED_WS" "$SELECTED_ROOT"
RUN_EXIT_CODE=$?

if [[ $RUN_EXIT_CODE -ne 0 ]]; then
  _log_debug "Container execution failed with exit code $RUN_EXIT_CODE."
  show_message "Error" "Failed to run container '$SELECTED_IMAGE'. Exit code: $RUN_EXIT_CODE"
  exit $RUN_EXIT_CODE
else
  _log_debug "Container finished successfully."
fi

_log_debug "jetcrun.sh finished."
exit 0


# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Current directory
# │   └── jetcrun.sh             <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Interactive script to launch Jetson containers using standard 'docker run'. Refactored for modularity.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20240806-103000-MODULAR
