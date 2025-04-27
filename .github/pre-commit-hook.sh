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

# This script checks that all modified files have consistent COMMIT-TRACKING footers
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
declare -a files_to_process # Store files that have a valid footer

for file in $files; do
  # Skip binary files, JSON files (which don't support comments), and other non-text files
  if [[ "$file" =~ \.(png|jpg|jpeg|gif|pdf|zip|jar)$ ]] || [[ "$file" =~ \.json$ ]]; then
    echo "Skipping non-text or JSON file: $file"
    continue
  fi
  
  # Extract UUID from file if it exists (search in the last 30 lines for footer)
  uuid_line=$(tail -n 30 "$file" | grep -E "COMMIT-TRACKING: (UUID-[0-9]{8}-[0-9]{6}-[A-Z0-9]{4})" | head -n 1)
  uuid=$(echo "$uuid_line" | sed 's/.*COMMIT-TRACKING: \(UUID-[0-9]\{8\}-[0-9]\{6\}-[A-Z0-9]\{4\}\).*/\1/')
  
  # Extract description from file if it exists (look near the COMMIT-TRACKING line)
  description=$(tail -n 30 "$file" | grep -E "Description: " | head -n 1 | sed 's/.*Description: \(.*\)/\1/')
  
  if [ ! -z "$uuid" ]; then
    uuids+=("$uuid")
    # Store description with the file as the key
    descriptions["$file"]="$description"
    files_to_process+=("$file") # Add to list of files to potentially update
  else
    # Check if the file *should* have a footer (e.g., not explicitly excluded)
    # Add more sophisticated checks if needed (e.g., based on file type)
    if [[ "$file" != *"README.md"* ]] && [[ "$file" != *".gitignore"* ]]; then # Example: Allow README/gitignore without footer for now
        echo "⚠️  Error: File $file is missing a required COMMIT-TRACKING footer."
        echo "    Please add a footer using the 'footer' snippet and try again."
        echo "    (Type 'footer' and press Tab in VSCode to insert the footer)"
        exit 1
    else
         echo "Skipping footer check for file: $file"
    fi
  fi
done

# Exit if no processable files found
if [ ${#files_to_process[@]} -eq 0 ]; then
  echo "No files with COMMIT-TRACKING footers found to process."
  exit 0
fi

# --- Remove UUID Consistency Check ---
# The following block that checked for multiple_uuid_bases is removed.
# We will now update the timestamp regardless of base UUID consistency.

# --- Start Timestamp Update ---
# Get current timestamp
current_timestamp=$(date +'%Y%m%d-%H%M%S')
echo "Updating COMMIT-TRACKING timestamps to: $current_timestamp for all staged files with footers."

for file in "${files_to_process[@]}"; do
    # Use sed to replace the timestamp part of the UUID
    # This assumes the UUID format is strictly followed.
    sed -i -E "s/(COMMIT-TRACKING: UUID-)[0-9]{8}-[0-9]{6}(-{1}[A-Z0-9]{4})/\1$current_timestamp\2/" "$file"
    if [ $? -ne 0 ]; then
        echo "⚠️ Error updating timestamp in $file"
        # Decide if this should be a fatal error
        # exit 1
    fi
    # Re-stage the file to include the timestamp update in the commit
    git add "$file"
done
echo "Timestamps updated and files re-staged."
# --- End Timestamp Update ---

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

# --- Prepare Commit Message --- Section Removed ---
# The logic previously here has been moved to prepare-commit-msg-hook.sh

# Success - Adjust success message
echo "✅ Timestamps updated for all staged files with COMMIT-TRACKING footers."
echo "   Commit message will be prepared by the prepare-commit-msg hook."
exit 0

# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── .github/                   <- GitHub directory
# │   └── pre-commit-hook.sh     <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Updated to search for COMMIT-TRACKING in the last 30 lines (footer check)
# Author: Mr K
# COMMIT-TRACKING: UUID-20250421-022100-A3B1
