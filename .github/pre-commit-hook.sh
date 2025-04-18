#!/bin/bash

# COMMIT-TRACKING: UUID-20240729-004815-A3B1
# Description: Add check for unique file descriptions in commit hook
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

# Collect all UUIDs and descriptions from modified files
declare -a uuids
declare -A descriptions

for file in $files; do
  # Skip binary files, JSON files (which don't support comments), and other non-text files
  if [[ "$file" =~ \.(png|jpg|jpeg|gif|pdf|zip|jar)$ ]] || [[ "$file" =~ \.json$ ]]; then
    continue
  fi
  
  # Extract UUID from file if it exists
  uuid=$(grep -E "COMMIT-TRACKING: (UUID-[0-9]{8}-[0-9]{6}-[A-Z0-9]{4})" "$file" | head -1 | sed 's/.*COMMIT-TRACKING: \(UUID-[0-9]\{8\}-[0-9]\{6\}-[A-Z0-9]\{4\}\).*/\1/')
  
  # Extract description from file if it exists
  description=$(grep -E "Description: " "$file" | head -1 | sed 's/.*Description: \(.*\)/\1/')
  
  if [ ! -z "$uuid" ]; then
    uuids+=("$uuid")
    # Store description with the file as the key
    descriptions["$file"]="$description"
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

# Check if descriptions are unique per file
generic_descriptions=false
duplicate_descriptions=()

# Check for overly generic descriptions
for file in "${!descriptions[@]}"; do
  desc="${descriptions[$file]}"
  
  # Skip if description is empty (already reported as error)
  if [ -z "$desc" ]; then
    continue
  fi
  
  # Check for generic terms that don't describe specific changes
  if [[ "$desc" == "Update"* ]] || 
     [[ "$desc" == "Fix"* ]] || 
     [[ "$desc" == "Change"* ]] || 
     [[ "$desc" == "Modify"* ]] ||
     [[ "$desc" == "Edit"* ]] || 
     [ ${#desc} -lt 10 ]; then
    echo "⚠️  Warning: Generic description in $file: '$desc'"
    echo "    Please provide a more specific description of what changed in this file."
    generic_descriptions=true
  fi
  
  # Check for duplicate descriptions
  for other_file in "${!descriptions[@]}"; do
    if [ "$file" != "$other_file" ] && [ "${descriptions[$file]}" == "${descriptions[$other_file]}" ]; then
      duplicate_descriptions+=("$file and $other_file have identical descriptions: '${descriptions[$file]}'")
    fi
  done
done

if [ ${#duplicate_descriptions[@]} -gt 0 ]; then
  echo "⚠️  Warning: Some files have identical descriptions:"
  for duplicate in "${duplicate_descriptions[@]}"; do
    echo "    $duplicate"
  done
  echo "    While using the same UUID across files, each file should have a unique description."
  echo "    Do you want to continue anyway? (y/n)"
  read -r response
  if [[ "$response" != "y" ]]; then
    exit 1
  fi
fi

if [ "$generic_descriptions" = true ]; then
  echo "⚠️  Warning: Some files have generic descriptions."
  echo "    Do you want to continue anyway? (y/n)"
  read -r response
  if [[ "$response" != "y" ]]; then
    exit 1
  fi
fi

# Success
echo "✅ All files have consistent COMMIT-TRACKING headers with UUID: $first_uuid"
exit 0
