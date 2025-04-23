#!/bin/bash

# COMMIT-TRACKING: UUID-YYYYMMDD-HHMMSS-PREP # Replace with actual timestamp and suffix
# Description: Restore conditions and use sed to insert Refs line in prepare-commit-msg.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── .github/                   <- GitHub directory
# │   └── prepare-commit-msg-hook.sh <- THIS FILE
# └── ...                        <- Other project files

echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "DEBUG: prepare-commit-msg hook STARTED"
echo "DEBUG: Arg 1 (COMMIT_MSG_FILE): $1"
echo "DEBUG: Arg 2 (COMMIT_SOURCE):   $2"
echo "DEBUG: Arg 3 (COMMIT_SHA1):     $3"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"


COMMIT_MSG_FILE=$1
COMMIT_SOURCE=$2
COMMIT_SHA1=$3

# --- Restore Conditions ---
# Only modify if COMMIT_SOURCE indicates a template is being used (message, template, merge, squash)
# AND if no explicit message is provided (COMMIT_SOURCE is not 'commit' from -F/-C/-c)
# AND if the message file is currently empty or only contains comments.
echo "DEBUG: Checking conditions..."
case "$COMMIT_SOURCE" in
    message|template|merge|squash)
        # Check if message file is effectively empty (ignoring comments)
        if ! grep -q -v -e '^#' "$COMMIT_MSG_FILE"; then
             echo "DEBUG: Conditions met (Source: $COMMIT_SOURCE, File empty/comments only). Proceeding..."
        else
             echo "DEBUG: Exiting hook: Message file already has content."
             exit 0
        fi
        ;;
    commit)
        echo "DEBUG: Exiting hook: Source is 'commit' (likely -F, -c, or -C)."
        exit 0
        ;;
    *)
        echo "DEBUG: Exiting hook: Unknown COMMIT_SOURCE '$COMMIT_SOURCE'."
        exit 0
        ;;
esac
# --- End Conditions ---


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
      echo "DEBUG: Found UUID $updated_uuid in $file" # Debug
  fi
done

if [ ${#unique_uuids[@]} -gt 0 ]; then
    echo "Prepare-commit-msg hook: Found ${#unique_uuids[@]} unique UUID(s)."
    commit_message_prefix="Refs:"
    for uuid_key in "${!unique_uuids[@]}"; do
        commit_message_uuids+=" $uuid_key,"
    done
    commit_message_uuids=${commit_message_uuids%,} # Remove trailing comma

    # Construct the line to insert
    refs_line="$commit_message_prefix$commit_message_uuids"

    # Use sed to insert the Refs line at the beginning of the file ($1)
    echo "DEBUG: Attempting to insert line using sed: '$refs_line'" # Debug
    # The '1i' command inserts before line 1. Need to escape special chars if any in refs_line.
    # Assuming refs_line doesn't contain characters needing special sed escaping for now.
    sed -i "1i\\$refs_line\n" "$COMMIT_MSG_FILE"
    sed_status=$?

    # Debug: Check write status and content
    if [ $sed_status -eq 0 ]; then
        echo "DEBUG: sed insert successful (exit code 0)."
        echo "--- DEBUG: Content in $COMMIT_MSG_FILE after sed ---"
        cat "$COMMIT_MSG_FILE"
        echo "--- DEBUG: End Content ---"
    else
        echo "DEBUG: ⚠️ Error inserting line with sed (exit code $sed_status)."
    fi

    echo "Prepare-commit-msg hook: Added UUID references to $COMMIT_MSG_FILE"
else
    echo "Prepare-commit-msg hook: No UUIDs found in staged files to add."
fi

echo "DEBUG: prepare-commit-msg hook FINISHED"
exit 0
