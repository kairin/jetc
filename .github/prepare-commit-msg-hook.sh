#!/bin/bash

# COMMIT-TRACKING: UUID-YYYYMMDD-HHMMSS-PREP # Replace with actual timestamp and suffix
# Description: Prepare commit message with Refs: UUIDs using prepare-commit-msg hook.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── .github/                   <- GitHub directory
# │   └── prepare-commit-msg-hook.sh <- THIS FILE
# └── ...                        <- Other project files

# This hook modifies the commit message file ($1) to add UUID references.
# It's triggered by Git after pre-commit and before the editor opens.

COMMIT_MSG_FILE=$1
COMMIT_SOURCE=$2
COMMIT_SHA1=$3

# Only run for standard commits (message source) and when not amending.
# Also check if the message file is empty or only contains comments.
if [ "$COMMIT_SOURCE" != "message" ] || [ -n "$COMMIT_SHA1" ] || grep -q -v -e '^#' "$COMMIT_MSG_FILE"; then
    # If it's not a standard commit, or amending, or message file already has non-comment content, exit.
    exit 0
fi

echo "Prepare-commit-msg hook: Preparing commit message..."

# Get list of staged files
files=$(git diff --cached --name-only --diff-filter=ACMRT)
if [ -z "$files" ]; then
  echo "Prepare-commit-msg hook: No staged files found."
  exit 0
fi

declare -A unique_uuids
commit_message_uuids=""

for file in $files; do
  # Skip non-text files
  if [[ "$file" =~ \.(png|jpg|jpeg|gif|pdf|zip|jar)$ ]] || [[ "$file" =~ \.json$ ]]; then
    continue
  fi

  # Extract UUID (assuming timestamp was updated by pre-commit)
  updated_uuid=$(grep -E "COMMIT-TRACKING: (UUID-[0-9]{8}-[0-9]{6}-[A-Z0-9]{4})" "$file" | head -1 | sed 's/.*COMMIT-TRACKING: \(UUID-[0-9]\{8\}-[0-9]\{6\}-[A-Z0-9]\{4\}\).*/\1/')
  if [ ! -z "$updated_uuid" ]; then
      unique_uuids["$updated_uuid"]=1
  fi
done

if [ ${#unique_uuids[@]} -gt 0 ]; then
    echo "Prepare-commit-msg hook: Found ${#unique_uuids[@]} unique UUID(s)."
    commit_message_prefix="Refs:"
    for uuid_key in "${!unique_uuids[@]}"; do
        commit_message_uuids+=" $uuid_key,"
    done
    commit_message_uuids=${commit_message_uuids%,} # Remove trailing comma

    # Read existing content (mostly comments from template)
    existing_content=$(cat "$COMMIT_MSG_FILE")

    # Prepend the Refs line using printf for reliability
    printf "%s%s\n\n%s" "$commit_message_prefix" "$commit_message_uuids" "$existing_content" > "$COMMIT_MSG_FILE"

    echo "Prepare-commit-msg hook: Added UUID references to $COMMIT_MSG_FILE"
else
    echo "Prepare-commit-msg hook: No UUIDs found in staged files to add."
fi

exit 0
