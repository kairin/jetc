#!/bin/bash

# Source utility functions (needed for get_system_datetime)
SCRIPT_DIR_CT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR_CT/utils.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_CT/utils.sh"
else
    echo "Error: utils.sh not found, cannot generate UUIDs." >&2
    # Define a fallback for get_system_datetime if utils.sh is missing
    get_system_datetime() { date +"%Y%m%d-%H%M%S"; }
fi

# =========================================================================
# Function: Generate new commit tracking UUID based on current system time
# Arguments: $1 = 4-char identifier (optional, defaults to random)
# Returns: Generated UUID string to stdout
# =========================================================================
generate_commit_uuid() {
  local identifier=${1:-$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 4 | head -n 1)}
  local date_time=$(get_system_datetime) # Uses function from utils.sh
  local uuid="UUID-${date_time}-${identifier}"
  echo "$uuid" # Output to stdout
}

# =========================================================================
# Function: Parse commit tracking UUID to extract components
# Arguments: $1 = UUID to parse
# Returns: Space-separated string to stdout: "date time identifier" or echoes error and returns 1
# =========================================================================
parse_commit_uuid() {
  local uuid=$1
  if [[ "$uuid" =~ UUID-([0-9]{8})-([0-9]{6})-([A-Z0-9]{4}) ]]; then
    local date="${BASH_REMATCH[1]}"
    local time="${BASH_REMATCH[2]}"
    local identifier="${BASH_REMATCH[3]}"
    echo "$date $time $identifier" # Output to stdout
    return 0
  else
    echo "Error: Invalid UUID format for parsing: $uuid" >&2
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
# Function: Generate footer for a file with commit tracking
# Arguments: $1 = file path, $2 = description, $3 = author, $4 = identifier (optional)
# Returns: Generated footer string to stdout
# =========================================================================
generate_file_footer() {
  local file_path=$1
  local description=$2
  local author=$3
  local identifier=${4:-$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 4 | head -n 1)}
  # Capture stdout from generate_commit_uuid
  local uuid=$(generate_commit_uuid "$identifier")

  # Determine comment style based on file extension
  local comment_start="#"
  local comment_end=""
  local ext="${file_path##*.}"
  case "$ext" in
    sh|py|yml|yaml|Dockerfile|.env|.conf|.ini|.cfg|.gitignore|.gitattributes|.buildargs) comment_start="#" ;;
    js|ts|tsx|jsonc|c|cpp|java|go|css|scss|less) comment_start="//" ;;
    md|html|xml) comment_start="<!--"; comment_end=" -->" ;;
    *) comment_start="#" ;; # Default to #
  esac

  # Generate the location diagram relative to project root 'jetc/'
  local relative_path="${file_path#*jetc/}" # Assumes path contains 'jetc/'
  local location_diagram=""
  location_diagram+="jetc/                          <- Main project folder\n"
  location_diagram+="${comment_start} ├── README.md                  <- Project documentation\n" # Assume README exists

  local dir_path=$(dirname "$relative_path")
  local base_name=$(basename "$relative_path")
  local indent=""
  local prefix="├── "

  if [[ "$dir_path" != "." ]]; then
      local dir_parts=($(echo "$dir_path" | tr '/' ' '))
      for ((i=0; i<${#dir_parts[@]}; i++)); do
          local part=${dir_parts[$i]}
          local current_indent="${indent}${prefix}"
          local description_text="<- Parent directory"
          if [[ $i -eq $((${#dir_parts[@]}-1)) ]]; then
              description_text="<- Current directory"
          fi
          location_diagram+="${comment_start} ${current_indent}${part}/                    ${description_text}\n"
          indent+="│   " # Add indentation for the next level
      done
      # Add the file itself under the last directory
      location_diagram+="${comment_start} ${indent}└── ${base_name}       <- THIS FILE\n"
  else
      # File is directly under jetc/
      location_diagram+="${comment_start} ${prefix}${base_name}               <- THIS FILE\n"
  fi
  location_diagram+="${comment_start} └── ...                        <- Other project files"

  # Generate the footer
  local footer=""
  footer+="\n\n${comment_start}\n"  # Add extra newlines before footer
  footer+="${comment_start} File location diagram:\n"
  footer+="${location_diagram}\n" # Already includes comment starts
  footer+="${comment_start}\n"
  footer+="${comment_start} Description: ${description}\n"
  footer+="${comment_start} Author: ${author}\n"
  footer+="${comment_start} COMMIT-TRACKING: ${uuid}\n"
  footer+="${comment_start}${comment_end}"

  echo -e "$footer" # Output footer to stdout
}

# --- Footer ---
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── commit_tracking.sh <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Functions for managing commit tracking UUIDs/footers.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250425-080000-42595D
