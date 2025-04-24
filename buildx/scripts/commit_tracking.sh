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
# Source logging functions if available
# shellcheck disable=SC1091
source "$SCRIPT_DIR_CT/env_setup.sh" 2>/dev/null || true

# =========================================================================
# Function: Generate new commit tracking UUID based on current system time
# Arguments: $1 = 4-char identifier (optional, defaults to random)
# Returns: Generated UUID string to stdout
# =========================================================================
generate_commit_uuid() {
  local identifier=${1:-$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 4 | head -n 1)}
  local date_time=$(get_system_datetime) # Uses function from utils.sh
  local uuid="UUID-${date_time}-${identifier}"
  log_debug "Generated commit UUID: $uuid"
  echo "$uuid" # Output to stdout
}

# =========================================================================
# Function: Parse commit tracking UUID to extract components
# Arguments: $1 = UUID to parse
# Returns: Space-separated string to stdout: "date time identifier" or echoes error and returns 1
# =========================================================================
parse_commit_uuid() {
  local uuid=$1
  log_debug "Parsing commit UUID: $uuid"
  if [[ "$uuid" =~ UUID-([0-9]{8})-([0-9]{6})-([A-Z0-9]{4}) ]]; then
    local date="${BASH_REMATCH[1]}"
    local time="${BASH_REMATCH[2]}"
    local identifier="${BASH_REMATCH[3]}"
    log_debug "Parsed components: Date=$date, Time=$time, ID=$identifier"
    echo "$date $time $identifier" # Output to stdout
    return 0
  else
    log_error "Invalid UUID format for parsing: $uuid" # Use log_error
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
  log_debug "Validating commit UUID: $uuid"
  if [[ "$uuid" =~ ^UUID-[0-9]{8}-[0-9]{6}-[A-Z0-9]{4}$ ]]; then
    log_debug "UUID is valid."
    return 0
  else
    log_debug "UUID is invalid."
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
  log_debug "Generating footer for file: $file_path"
  log_debug "Desc: $description, Author: $author, UUID: $uuid"

  # Determine comment style based on file extension
  local comment_start="#"
  local comment_end=""
  local ext="${file_path##*.}"
  case "$ext" in
    sh|py|yml|yaml|Dockerfile|.env|.conf|.ini|.cfg) comment_start="#" ;;
    js|ts|tsx|jsonc|c|cpp|java|go|css|scss|less) comment_start="//" ;;
    md|html|xml) comment_start="<!--"; comment_end=" -->" ;;
    *) comment_start="#" ;; # Default to #
  esac
  log_debug "Using comment style: Start='$comment_start', End='$comment_end'"

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
  log_debug "Generated location diagram."

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

# =========================================================================
# Function: Update commit tracking UUID timestamp in a file's footer
# Arguments: $1 = file path
# Returns: 0 on success, 1 on failure
# DEPRECATED in favor of set_commit_tracking_uuid for hook usage
# =========================================================================
update_commit_tracking_footer() {
  log_warning "update_commit_tracking_footer is deprecated for hook usage. Use set_commit_tracking_uuid." # Use log_warning
  local file="$1"
  local now
  now=$(get_system_datetime)
  log_debug "Attempting (deprecated) footer update for $file with time $now"
  # Use sed to find the COMMIT-TRACKING line within the last ~10 lines and update only the date-time part
  # This is complex and less reliable than replacing the whole UUID via hooks.
  sed -i '$s/\(COMMIT-TRACKING: UUID-\)[0-9]\{8\}-[0-9]\{6\}\(-[A-Z0-9]\{4\}\)/\1'${now}'\2/' "$file"
  # A more robust sed might look like:
  # sed -i -E ':a; $!{N; ba}; s/(COMMIT-TRACKING: UUID-)[0-9]{8}-[0-9]{6}(-[A-Z0-9]{4})/\1'${now}'\2/g' "$file"
}

# =========================================================================
# Function: Set the commit tracking UUID in a file's footer (for Git hooks)
# Arguments: $1 = file path, $2 = new UUID string (e.g., UUID-YYYYMMDD-HHMMSS-XXXX)
# Returns: 0 on success, 1 if file not found or footer line missing, 2 if sed fails
# =========================================================================
set_commit_tracking_uuid() {
    local file_path="$1"
    local new_uuid="$2"
    log_debug "Setting commit UUID in $file_path to $new_uuid"

    if [[ ! -f "$file_path" ]]; then
        log_error "File not found: $file_path" # Use log_error
        return 1
    fi

    if ! validate_commit_uuid "$new_uuid"; then
        log_error "Invalid UUID format provided: $new_uuid" # Use log_error
        return 1
    fi

    # Use sed to replace the COMMIT-TRACKING line.
    # This assumes the COMMIT-TRACKING line is one of the last few lines.
    # We target the specific line format for replacement.
    # Using a different delimiter (#) for sed to avoid issues with paths in UUIDs (though unlikely).
    # The command tries to find and replace the line anywhere in the file.
    if grep -q "COMMIT-TRACKING: UUID-" "$file_path"; then
        log_debug "Found existing COMMIT-TRACKING line. Attempting replacement..."
        sed -i "s#^\(.*COMMIT-TRACKING: \).*#\1${new_uuid}#" "$file_path"
        if [[ $? -ne 0 ]]; then
            log_error "sed command failed to update UUID in $file_path" # Use log_error
            return 2
        fi
        # Verify the change (optional but good)
        if ! grep -q "COMMIT-TRACKING: ${new_uuid}" "$file_path"; then
             log_warning "UUID replacement verification failed in $file_path" # Use log_warning
             # Decide if this should be a fatal error (return 1) or just a warning
        else
             log_debug "UUID replacement successful and verified."
        fi
        return 0
    else
        log_warning "COMMIT-TRACKING line not found in $file_path. Cannot set UUID." # Use log_warning
        return 1 # Indicate the line wasn't found
    fi
}

# For backward compatibility, rename and alias the old function
generate_file_header() {
  log_warning "generate_file_header is deprecated. Use generate_file_footer instead." # Use log_warning
  generate_file_footer "$@"
}

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── commit_tracking.sh <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Functions for managing commit tracking UUIDs/footers. Added set_commit_tracking_uuid for hooks. Added logging.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20240806-103000-MODULAR # Updated UUID to match refactor
