#!/bin/bash

# Git hook: prepare-commit-msg
# Purpose: Prepend a unique commit UUID (runtime or commit-time) to the commit message.

COMMIT_MSG_FILE="$1"
COMMIT_SOURCE="$2"
# COMMIT_SHA1="$3" # Not typically needed here

# --- Configuration ---
# Relative path from .git/hooks to the scripts directory
SCRIPTS_DIR_REL="buildx/scripts"
# Absolute path to the scripts directory (assuming hook is run from repo root or .git/hooks)
HOOKS_DIR=$(dirname "$0")
REPO_ROOT=$(git rev-parse --show-toplevel)
SCRIPTS_DIR="$REPO_ROOT/$SCRIPTS_DIR_REL"
RUNTIME_UUID_FILE="$REPO_ROOT/.git/LAST_RUNTIME_UUID"

# --- Source Utilities ---
if [ -f "$SCRIPTS_DIR/commit_tracking.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPTS_DIR/commit_tracking.sh"
else
    echo "Error: commit_tracking.sh not found at $SCRIPTS_DIR. Cannot manage UUID." >&2
    exit 1 # Block commit if core script is missing
fi

# --- Logic ---
# Only run if message file is provided and it's a regular commit (not merge, squash, etc.)
if [ -z "$COMMIT_MSG_FILE" ] || [[ "$COMMIT_SOURCE" != "message" && "$COMMIT_SOURCE" != "" ]]; then
    exit 0
fi

# Check if message already starts with a UUID (e.g., during amend)
if grep -qE '^UUID-[0-9]{8}-[0-9]{6}-[A-Z0-9]{4}:' "$COMMIT_MSG_FILE"; then
    echo "Commit message already contains UUID. Skipping prepend." >&2
    exit 0
fi

# Determine the UUID to use
commit_uuid=""
if [ -f "$RUNTIME_UUID_FILE" ]; then
    runtime_uuid=$(cat "$RUNTIME_UUID_FILE")
    if validate_commit_uuid "$runtime_uuid"; then
        commit_uuid="$runtime_uuid"
        echo "Using runtime UUID: $commit_uuid" >&2
        # Clean up the runtime UUID file after using it
        rm -f "$RUNTIME_UUID_FILE"
    else
        echo "Warning: Invalid runtime UUID found in $RUNTIME_UUID_FILE. Generating new commit-time UUID." >&2
        rm -f "$RUNTIME_UUID_FILE" # Remove invalid file
    fi
fi

# If no valid runtime UUID was found, generate a new one
if [ -z "$commit_uuid" ]; then
    commit_uuid=$(generate_commit_uuid "COMM")
    echo "Generated commit-time UUID: $commit_uuid" >&2
fi

# Prepend the UUID to the commit message file
# Read existing content, prepend UUID, write back
{ echo "${commit_uuid}: $(cat "$COMMIT_MSG_FILE")"; } > "$COMMIT_MSG_FILE.tmp" && mv "$COMMIT_MSG_FILE.tmp" "$COMMIT_MSG_FILE"

echo "Prepended UUID to commit message." >&2

exit 0

# File location diagram:
# jetc/                          <- Main project folder
# ├── .github/                   <- Current directory
# │   └── prepare-commit-msg-hook.sh <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Git hook to prepend runtime or commit-time UUID to commit messages.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-220000-HOOKIMPL
