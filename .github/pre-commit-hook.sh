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
declare -a files_to_process # Store files that have a valid header

for file in $files; do
  # Skip binary files, JSON files (which don't support comments), and other non-text files
  if [[ "$file" =~ \.(png|jpg|jpeg|gif|pdf|zip|jar)$ ]] || [[ "$file" =~ \.json$ ]]; then
    echo "Skipping non-text or JSON file: $file"
    continue
  fi
  
  # Extract UUID from file if it exists
  uuid_line=$(grep -E "COMMIT-TRACKING: (UUID-[0-9]{8}-[0-9]{6}-[A-Z0-9]{4})" "$file" | head -1)
  uuid=$(echo "$uuid_line" | sed 's/.*COMMIT-TRACKING: \(UUID-[0-9]\{8\}-[0-9]\{6\}-[A-Z0-9]\{4\}\).*/\1/')
  
  # Extract description from file if it exists
  description=$(grep -E "Description: " "$file" | head -1 | sed 's/.*Description: \(.*\)/\1/')
  
  if [ ! -z "$uuid" ]; then
    uuids+=("$uuid")
    # Store description with the file as the key
    descriptions["$file"]="$description"
    files_to_process+=("$file") # Add to list of files to potentially update
  else
    # Check if the file *should* have a header (e.g., not explicitly excluded)
    # Add more sophisticated checks if needed (e.g., based on file type)
    if [[ "$file" != *"README.md"* ]] && [[ "$file" != *".gitignore"* ]]; then # Example: Allow README/gitignore without header for now
        echo "⚠️  Error: File $file is missing a required COMMIT-TRACKING header."
        echo "    Please add a header using the 'header' snippet and try again."
        echo "    (Type 'header' and press Tab in VSCode to insert the header)"
        exit 1
    else
         echo "Skipping header check for file: $file"
    fi
  fi
done

# Exit if no processable files found
if [ ${#files_to_process[@]} -eq 0 ]; then
  echo "No files with COMMIT-TRACKING headers found to process."
  exit 0
fi

# --- Remove UUID Consistency Check ---
# The following block that checked for multiple_uuid_bases is removed.
# We will now update the timestamp regardless of base UUID consistency.

# --- Start Timestamp Update ---
# Get current timestamp
current_timestamp=$(date +'%Y%m%d-%H%M%S')
echo "Updating COMMIT-TRACKING timestamps to: $current_timestamp for all staged files with headers."

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

# --- Prepare Commit Message ---
echo "Preparing commit message..."
echo "Current directory: $(pwd)" # Debug: Show current directory
declare -A unique_uuids # Use associative array for uniqueness
commit_message_uuids=""
# Use git var GIT_DIR to get the correct path to the .git directory
git_dir=$(git var GIT_DIR)
commit_editmsg_path="$git_dir/COMMIT_EDITMSG" # Define path explicitly using git_dir

for file in "${files_to_process[@]}"; do
    # Extract the updated UUID from the file
    updated_uuid=$(grep -E "COMMIT-TRACKING: (UUID-[0-9]{8}-[0-9]{6}-[A-Z0-9]{4})" "$file" | head -1 | sed 's/.*COMMIT-TRACKING: \(UUID-[0-9]\{8\}-[0-9]\{6\}-[A-Z0-9]\{4\}\).*/\1/')
    if [ ! -z "$updated_uuid" ]; then
        unique_uuids["$updated_uuid"]=1 # Add UUID as key for uniqueness
        echo "Found UUID: $updated_uuid in file $file" # Debug: Show found UUIDs
    fi
done

# Build the commit message string from unique UUIDs
if [ ${#unique_uuids[@]} -gt 0 ]; then
    echo "Found ${#unique_uuids[@]} unique UUID(s)." # Debug: Show count
    commit_message_prefix="Refs:"
    for uuid_key in "${!unique_uuids[@]}"; do
        commit_message_uuids+=" $uuid_key,"
    done
    # Remove trailing comma
    commit_message_uuids=${commit_message_uuids%,}

    # Construct the full message content with newlines for printf
    # Use %s for the string and %b for interpreting \n
    full_message_format="%s%s\n\n# Add commit title/body here\n"

    # Write to COMMIT_EDITMSG using printf
    printf "$full_message_format" "$commit_message_prefix" "$commit_message_uuids" > "$commit_editmsg_path"

    # Debug: Check if file write was successful and show content
    if [ $? -eq 0 ]; then
        echo "Successfully wrote to $commit_editmsg_path"
        echo "--- Content written to $commit_editmsg_path ---"
        cat "$commit_editmsg_path" # Debug: Show content written
        echo "--- End Content ---"
    else
        echo "⚠️ Error writing to $commit_editmsg_path"
    fi
    echo "Commit message template prepared in $commit_editmsg_path"
else
    echo "No UUIDs found to add to commit message."
fi
# --- End Prepare Commit Message ---

# Success - Adjust success message as UUIDs might not be consistent
echo "✅ Timestamps updated for all staged files with COMMIT-TRACKING headers."
echo "   Commit message template prepared with references."
exit 0
