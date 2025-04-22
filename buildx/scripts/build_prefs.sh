#!/bin/bash
PREFS_FILE="/tmp/build_prefs.sh"
echo "Launching user preferences dialog..."
get_user_preferences
prefs_exit_code=$?
echo "Preferences dialog finished with exit code: $prefs_exit_code"
if [ -f "$PREFS_FILE" ]; then
    echo "DEBUG: $PREFS_FILE contents after dialog:"
    cat "$PREFS_FILE"
else
    echo "DEBUG: $PREFS_FILE not found after dialog."
fi
if [[ $prefs_exit_code -ne 0 ]]; then
    echo "User cancelled or an error occurred in preferences dialog. Exiting."
    [ -f "$PREFS_FILE" ] && rm -f "$PREFS_FILE"
    exit 1
fi
if [ -f "$PREFS_FILE" ]; then
    echo "Sourcing preferences from $PREFS_FILE..."
    # shellcheck disable=SC1090
    source "$PREFS_FILE"
    rm -f "$PREFS_FILE"
    echo "Preferences sourced."
    echo "DEBUG: Sourced SELECTED_FOLDERS_LIST in build.sh: '$SELECTED_FOLDERS_LIST'"
else
    echo "Error: Preferences file $PREFS_FILE not found. Cannot proceed."
    exit 1
fi
echo "DEBUG: Sourced variables:"
echo "  DOCKER_USERNAME: $DOCKER_USERNAME"
echo "  DOCKER_REPO_PREFIX: $DOCKER_REPO_PREFIX"
echo "  DOCKER_REGISTRY: $DOCKER_REGISTRY"
echo "  use_cache: $use_cache"
echo "  use_squash: $use_squash"
echo "  skip_intermediate_push_pull: $skip_intermediate_push_pull"
echo "  SELECTED_BASE_IMAGE: $SELECTED_BASE_IMAGE"
echo "  PLATFORM: $PLATFORM"
echo "  use_builder: $use_builder"
echo "  SELECTED_FOLDERS_LIST: $SELECTED_FOLDERS_LIST"
