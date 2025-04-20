#!/bin/bash

# COMMIT-TRACKING: UUID-20240802-174500-CTID
# Description: Consolidated script for commit tracking and UUID generation
# Author: GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── UUID-commit-tracking.sh <- THIS FILE
# └── ...                        <- Other project files

# =========================================================================
# Function: Get system datetime from Ubuntu 22.04+ or WSL
# Returns: Formatted datetime string as YYYYMMDD-HHMMSS
# =========================================================================
get_system_datetime() {
  # Check if timedatectl is available (systemd-based systems like Ubuntu 22.04+)
  if command -v timedatectl &> /dev/null; then
    # Use timedatectl to get synchronized system time
    local datetime=$(timedatectl show --property=TimeUSec --value 2>/dev/null | cut -d' ' -f1)
    if [ -n "$datetime" ]; then
      # Convert to desired format
      echo $(date -d "@$(echo $datetime | cut -d. -f1)" +"%Y%m%d-%H%M%S")
      return 0
    fi
  fi
  
  # Fallback to standard date command (works on both WSL and native Ubuntu)
  echo $(date +"%Y%m%d-%H%M%S")
  return 0
}

# =========================================================================
# Function: Generate new commit tracking UUID based on current system time
# Arguments: $1 = 4-char identifier (optional, defaults to random)
# Returns: Generated UUID string
# =========================================================================
generate_commit_uuid() {
  local identifier=${1:-$(cat /dev/urandom | tr -dc 'A-Z' | fold -w 4 | head -n 1)}
  local date_time=$(get_system_datetime)
  echo "UUID-${date_time}-${identifier}"
}

# =========================================================================
# Function: Parse commit tracking UUID to extract components
# Arguments: $1 = UUID to parse
# Returns: Array with components: [date, time, identifier]
# =========================================================================
parse_commit_uuid() {
  local uuid=$1
  if [[ "$uuid" =~ UUID-([0-9]{8})-([0-9]{6})-([A-Z0-9]{4}) ]]; then
    local date="${BASH_REMATCH[1]}"
    local time="${BASH_REMATCH[2]}"
    local identifier="${BASH_REMATCH[3]}"
    echo "$date $time $identifier"
  else
    echo "Invalid UUID format"
    return 1
  fi
}

# =========================================================================
# Function: Validate a commit tracking UUID
# Arguments: $1 = UUID to validate
# Returns: 0 if valid, 1 if not
# =========================================================================
validate_commit_uuid() {
  local uuid=$1
  if [[ "$uuid" =~ ^UUID-[0-9]{8}-[0-9]{6}-[A-Z0-9]{4}$ ]]; then
    return 0
  else
    return 1
  fi
}

# =========================================================================
# Function: Generate header for a file with commit tracking
# Arguments: $1 = file path, $2 = description, $3 = author, $4 = identifier (optional)
# Returns: Generated header string
# =========================================================================
generate_file_header() {
  local file_path=$1
  local description=$2
  local author=$3
  local identifier=${4:-$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 4 | head -n 1)}
  local uuid=$(generate_commit_uuid "$identifier")
  
  # Determine comment style based on file extension
  local comment_start=""
  local comment_end=""
  
  local ext="${file_path##*.}"
  case "$ext" in
    sh|py|yml|yaml|Dockerfile)
      comment_start="#"
      ;;
    js|ts|tsx|jsonc|c|cpp|java|go)
      comment_start="//"
      ;;
    md|html|xml)
      comment_start="<!--"
      comment_end=" -->"
      ;;
    *)
      # Default to # style
      comment_start="#"
      ;;
  esac
  
  # Generate the location diagram
  local location_diagram=""
  location_diagram+="jetc/                          <- Main project folder\n"
  location_diagram+="├── README.md                  <- Project documentation\n"
  
  # Extract directory parts for the diagram
  local dir_path=$(dirname "$file_path")
  local dir_parts=($(echo "$dir_path" | tr '/' ' '))
  local prev_indent=""
  local last_idx=$((${#dir_parts[@]}-1))
  
  for ((i=1; i<${#dir_parts[@]}; i++)); do
    local part=${dir_parts[$i]}
    if [[ $i -eq $last_idx ]]; then
      location_diagram+="${prev_indent}├── ${part}/               <- Current directory\n"
      location_diagram+="${prev_indent}│   └── $(basename "$file_path")       <- THIS FILE\n"
    else
      location_diagram+="${prev_indent}├── ${part}/                    <- Parent directory\n"
    fi
    prev_indent="${prev_indent}│   "
  done
  
  location_diagram+="└── ...                        <- Other project files"
  
  # Generate the header
  local header=""
  header+="${comment_start}\n"
  header+="${comment_start} COMMIT-TRACKING: ${uuid}\n"
  header+="${comment_start} Description: ${description}\n"
  header+="${comment_start} Author: ${author}\n"
  header+="${comment_start}\n"
  header+="${comment_start} File location diagram:\n"
  header+="${comment_start} ${location_diagram}\n"
  header+="${comment_start}${comment_end}"
  
  echo -e "$header"
}

# Usage examples:
# uuid=$(generate_commit_uuid "TEST")
# echo "Generated UUID: $uuid"
#
# header=$(generate_file_header "/home/ks/apps/jetc/buildx/scripts/test.sh" "Test script" "GitHub Copilot")
# echo "$header"
