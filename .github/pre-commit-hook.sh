#!/bin/bash

# COMMIT-TRACKING: UUID-20240729-004815-A3B1
# Description: Create pre-commit hook to validate headers
# Author: Mr K
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── .github/                   <- GitHub directory
# │   └── pre-commit-hook.sh     <- THIS FILE
# └── ...                        <- Other project files

# This script checks that all modified files have consistent COMMIT-TRACKING headers
# To install:
# 1. Copy this file to .git/hooks/pre-commit
# 2. Make it executable: chmod +x .git/hooks/pre-commit

# Get list of staged files that are being committed
files=$(git diff --cached --name-only --diff-filter=ACMRT)
if [ -z "$files" ]; then
  echo "No files to check."
  exit 0
fi

# Collect all UUIDs from modified files
declare -a uuids
for file in $files; do
  # Skip binary files, JSON files (which don't support comments), and other non-text files
  if [[ "$file" =~ \.(png|jpg|jpeg|gif|pdf|zip|jar)$ ]] || [[ "$file" =~ \.json$ ]]; then
    continue
  fi
  
  # Extract UUID from file if it exists
  uuid=$(grep -E "COMMIT-TRACKING: (UUID-[0-9]{8}-[0-9]{6}-[A-Z0-9]{4})" "$file" | head -1 | sed 's/.*COMMIT-TRACKING: \(UUID-[0-9]\{8\}-[0-9]\{6\}-[A-Z0-9]\{4\}\).*/\1/')
  if [ ! -z "$uuid" ]; then
    uuids+=("$uuid")
  else
    echo "⚠️  Warning: File $file is missing a COMMIT-TRACKING header."
    echo "    Please add a header using the 'header' snippet and try again."
    echo "    (Type 'header' and press Tab in VSCode to insert the header)"
    exit 1
  fi
done

# Check if all UUIDs are the same
first_uuid=""
multiple_uuids=false
for uuid in "${uuids[@]}"; do
  if [ -z "$first_uuid" ]; then
    first_uuid="$uuid"
  elif [ "$uuid" != "$first_uuid" ]; then
    multiple_uuids=true
    break
  fi
done

if [ "$multiple_uuids" = true ]; then
  echo "⚠️  Error: Multiple UUIDs found in the modified files."
  echo "    All files in a single commit should use the same UUID."
  echo "    Either reuse an existing UUID across all files or generate a new one for all files."
  exit 1
fi

# Success
echo "✅ All files have consistent COMMIT-TRACKING headers with UUID: $first_uuid"
exit 0
