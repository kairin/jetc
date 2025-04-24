#!/bin/bash

# Git hook: pre-commit
# Purpose: Update COMMIT-TRACKING UUID in staged files based on the commit message UUID.

# --- Configuration ---
# Relative path from .git/hooks to the scripts directory
SCRIPTS_DIR_REL="buildx/scripts"
# Absolute path to the scripts directory (assuming hook is run from repo root or .git/hooks)
HOOKS_DIR=$(dirname "$0")
REPO_ROOT=$(git rev-parse --show-toplevel)
SCRIPTS_DIR="$REPO_ROOT/$SCRIPTS_DIR_REL"

# File extensions to check for footers
FOOTER_EXTENSIONS=("sh" "md" "py" "Dockerfile" "yml" "yaml" "js" "ts" "tsx" "jsonc" "c" "cpp" "java" "go" "css" "scss" "less" "env" "conf" "ini" "cfg" "properties")

# --- Source Utilities ---
if [ -f "$SCRIPTS_DIR/commit_tracking.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPTS_DIR/commit_tracking.sh"
else
    echo "Error: commit_tracking.sh not found at $SCRIPTS_DIR. Cannot update file footers." >&2
    exit 1 # Block commit if core script is missing
fi

# --- Logic ---
echo "Running pre-commit hook for UUID footer update..." >&2

# Get the commit message (using the file prepared by prepare-commit-msg)
COMMIT_MSG_FILE="$REPO_ROOT/.git/COMMIT_EDITMSG"
if [ ! -f "$COMMIT_MSG_FILE" ]; then
    echo "Error: Commit message file ($COMMIT_MSG_FILE) not found." >&2
    # Attempt fallback (less reliable) - might not work correctly with amend/rebase
    # commit_msg=$(git log -1 --pretty=%B)
    echo "Cannot reliably determine commit UUID. Aborting footer update." >&2
    exit 1 # Block commit if message can't be read
fi

commit_msg=$(head -n 1 "$COMMIT_MSG_FILE")

# Extract UUID from the first line
commit_uuid=""
if [[ "$commit_msg" =~ ^(UUID-[0-9]{8}-[0-9]{6}-[A-Z0-9]{4}): ]]; then
    commit_uuid="${BASH_REMATCH[1]}"
else
    echo "Error: Could not find valid UUID pattern (UUID-YYYYMMDD-HHMMSS-XXXX:) at the start of the commit message." >&2
    echo "Message starts with: $commit_msg" >&2
    echo "Please ensure the prepare-commit-msg hook ran correctly or format your commit message manually." >&2
    exit 1 # Block commit if UUID is missing/invalid
fi

echo "Found commit UUID: $commit_uuid" >&2

# Get list of staged files (Added, Copied, Modified)
staged_files=$(git diff --cached --name-only --diff-filter=ACM)

if [ -z "$staged_files" ]; then
    echo "No staged files to process." >&2
    exit 0
fi

update_failed=0
files_updated=0

# Loop through staged files
while IFS= read -r file; do
    # Ensure file path is relative to repo root for processing
    file_rel_path="$file"
    file_abs_path="$REPO_ROOT/$file"

    # Check if the file extension should have a footer
    file_ext="${file##*.}"
    should_check=0
    for ext in "${FOOTER_EXTENSIONS[@]}"; do
        if [[ "$file_ext" == "$ext" ]]; then
            should_check=1
            break
        fi
        # Handle files with no extension like 'Dockerfile'
        if [[ ! "$file" =~ \. ]] && [[ "$(basename "$file")" == "$ext" ]]; then
             should_check=1
             break
        fi
    done

    if [[ $should_check -eq 1 ]] && [[ -f "$file_abs_path" ]]; then
        echo "Checking/Updating footer in: $file_rel_path" >&2
        # Call the function to set the UUID
        set_commit_tracking_uuid "$file_abs_path" "$commit_uuid"
        update_status=$?

        if [[ $update_status -eq 0 ]]; then
            # Success: Re-stage the modified file
            git add "$file_abs_path"
            echo "  -> Updated and re-staged." >&2
            ((files_updated++))
        elif [[ $update_status -eq 1 ]]; then
            # Footer line not found - Warning, but allow commit
            echo "  -> Warning: COMMIT-TRACKING line not found. Skipping footer update." >&2
        else
            # sed command failed - Error, block commit
            echo "  -> Error: Failed to update footer (sed error). Blocking commit." >&2
            update_failed=1
        fi
    # else
        # echo "Skipping file (extension not in list or file not found): $file_rel_path" >&2
    fi
done <<< "$staged_files"

if [[ $update_failed -eq 1 ]]; then
    echo "--------------------------------------------------" >&2
    echo "PRE-COMMIT FAILED: Errors occurred updating file footers." >&2
    echo "Please fix the issues and try committing again." >&2
    echo "--------------------------------------------------" >&2
    exit 1
fi

if [[ $files_updated -gt 0 ]]; then
     echo "--------------------------------------------------" >&2
     echo "PRE-COMMIT SUCCESS: $files_updated file footer(s) updated with UUID $commit_uuid." >&2
     echo "--------------------------------------------------" >&2
fi

exit 0

# File location diagram:
# jetc/                          <- Main project folder
# ├── .github/                   <- Current directory
# │   └── pre-commit-hook.sh     <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Git hook to update COMMIT-TRACKING UUID in staged files before commit.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-220000-HOOKIMPL
