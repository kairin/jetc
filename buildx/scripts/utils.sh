#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/utils.sh

# =========================================================================
# Utility Functions Script
# Responsibility: Provide common helper functions for validation, datetime, etc.
#                 This script should NOT depend on logging.sh to define core functions.
# =========================================================================

# --- Minimal Internal Logging Fallbacks ---
# These are used ONLY if the main logging system isn't available when these functions are called.
# They do NOT replace the main logging system initialized elsewhere.
_utils_log_info() { echo "INFO (utils): $1"; }
_utils_log_warning() { echo "WARNING (utils): $1" >&2; }
_utils_log_error() { echo "ERROR (utils): $1" >&2; }
_utils_log_debug() { if [[ "${JETC_DEBUG:-0}" == "1" ]]; then echo "[DEBUG] (utils): $1" >&2; fi; }

_utils_log_debug "utils.sh script started execution."

# --- Core Utility Functions ---

# =========================================================================
# Function: Get current system datetime
# Arguments: None
# Returns: YYYYMMDD-HHMMSS string to stdout
# =========================================================================
get_system_datetime() {
    date +"%Y%m%d-%H%M%S"
}
_utils_log_debug "Defined: get_system_datetime"

# =========================================================================
# Function: Validate if a variable is set and not empty
# Arguments: $1 = Variable Name (string for logging), $2 = Variable Value, $3 = Error Message (optional)
# Returns: 0 if valid, 1 if invalid
# =========================================================================
validate_variable() {
    local var_name="$1"
    local var_value="$2"
    local error_message="${3:-Variable '$var_name' is not set or empty.}" # Default error message

    if [[ -z "$var_value" ]]; then
        # Use internal fallback error log in case main logging isn't ready
        _utils_log_error "$error_message"
        # Also try the main logger if it exists
        if command -v log_error &> /dev/null; then log_error "$error_message"; fi
        return 1
    else
        # Use internal fallback debug log
        _utils_log_debug "Variable '$var_name' validated successfully."
        # Also try the main logger if it exists
        if command -v log_debug &> /dev/null; then log_debug "Variable '$var_name' validated successfully."; fi
        return 0
    fi
}
_utils_log_debug "Defined: validate_variable"

# =========================================================================
# Function: Source a script safely, checking for existence first
# Arguments: $1 = Script Path, $2 = Script Name (for logging)
# Returns: 0 on success, 1 on failure
# =========================================================================
source_script() {
    local script_path="$1"
    local script_name="${2:-Script}" # Default name
    local log_func_prefix="_utils_" # Default to internal fallback
    local main_log_prefix=""

    # Check if main logging functions exist
    if command -v log_debug &> /dev/null && command -v log_error &> /dev/null; then
        log_func_prefix="" # Use main logging functions
        main_log_prefix="log_"
    fi

    "${log_func_prefix}log_debug" "Attempting to source $script_name: $script_path"

    if [[ -f "$script_path" ]]; then
        "${log_func_prefix}log_debug" "File check PASSED for path: '$script_path'" # DEBUG ADD
        # shellcheck disable=SC1090
        source "$script_path"
        local source_status=$?
        if [[ $source_status -ne 0 ]]; then
            "${log_func_prefix}log_error" "Error sourcing $script_name from $script_path (exit code $source_status)."
            # Try main logger too
            if [[ -n "$main_log_prefix" ]]; then "${main_log_prefix}log_error" "Error sourcing $script_name from $script_path (exit code $source_status)."; fi
            return 1
        else
             "${log_func_prefix}log_debug" "$script_name sourced successfully."
             if [[ -n "$main_log_prefix" ]]; then "${main_log_prefix}log_debug" "$script_name sourced successfully."; fi
             return 0
        fi
    else
        "${log_func_prefix}log_debug" "File check FAILED for path: '$script_path'" # DEBUG ADD
        # Ensure this line uses log_error, not log_log_error
        "${log_func_prefix}log_error" "$script_name not found at path: '$script_path'" # Added quotes for clarity
        if [[ -n "$main_log_prefix" ]]; then "${main_log_prefix}log_error" "$script_name not found at path: '$script_path'"; fi # Corrected typo here too
        return 1
    fi
}
_utils_log_debug "Defined: source_script"

# =========================================================================
# Function: Capture a screenshot (requires 'scrot')
# Arguments: $1 = base_filename (e.g., "step1_options")
# Returns: 0 on success, 1 on failure or if scrot is not installed
# Saves screenshot to LOG_DIR (if available) or /tmp.
# =========================================================================
capture_screenshot() {
    local base_filename="$1"
    local log_func_prefix="_utils_" # Default to internal fallback
    local main_log_prefix=""

    # Check if main logging functions exist
    if command -v log_debug &> /dev/null && command -v log_error &> /dev/null && command -v log_warning &> /dev/null; then
        log_func_prefix="" # Use main logging functions
        main_log_prefix="log_"
    fi

    if [ -z "$base_filename" ]; then
        "${log_func_prefix}log_warning" "capture_screenshot: No base filename provided."
        if [[ -n "$main_log_prefix" ]]; then "${main_log_prefix}log_warning" "capture_screenshot: No base filename provided."; fi
        return 1
    fi

    # Check if scrot is installed
    if ! command -v scrot &> /dev/null; then
        "${log_func_prefix}log_warning" "scrot command not found. Cannot capture screenshot. Please install scrot (sudo apt-get install scrot)."
        if [[ -n "$main_log_prefix" ]]; then "${main_log_prefix}log_warning" "scrot command not found. Cannot capture screenshot. Please install scrot (sudo apt-get install scrot)."; fi
        return 1
    fi

    # Determine effective log directory (use LOG_DIR if defined and valid, else /tmp)
    local effective_log_dir="/tmp" # Default fallback
    if [ -n "${LOG_DIR:-}" ] && [ -d "$LOG_DIR" ]; then
        effective_log_dir="$LOG_DIR"
    else
        "${log_func_prefix}log_warning" "LOG_DIR ('${LOG_DIR:-}') not set or not a directory. Saving screenshot to /tmp."
         if [[ -n "$main_log_prefix" ]]; then "${main_log_prefix}log_warning" "LOG_DIR ('${LOG_DIR:-}') not set or not a directory. Saving screenshot to /tmp."; fi
    fi

    local timestamp
    timestamp=$(get_system_datetime) # Use existing function
    local screenshot_filename="${base_filename}_${timestamp}.png"
    local screenshot_path="$effective_log_dir/$screenshot_filename"

    "${log_func_prefix}log_debug" "Attempting to capture screenshot to: $screenshot_path"
    if [[ -n "$main_log_prefix" ]]; then "${main_log_prefix}log_debug" "Attempting to capture screenshot to: $screenshot_path"; fi

    # Capture the screenshot using scrot
    sleep 0.5 # Small delay
    if scrot "$screenshot_path"; then
        "${log_func_prefix}log_debug" "Screenshot captured successfully: $screenshot_filename"
        if [[ -n "$main_log_prefix" ]]; then "${main_log_prefix}log_debug" "Screenshot captured successfully: $screenshot_filename"; fi
        return 0
    else
        "${log_func_prefix}log_error" "Failed to capture screenshot using scrot."
        if [[ -n "$main_log_prefix" ]]; then "${main_log_prefix}log_error" "Failed to capture screenshot using scrot."; fi
        return 1
    fi
}
_utils_log_debug "Defined: capture_screenshot"

_utils_log_debug "utils.sh finished execution."

# --- Footer ---
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── utils.sh           <- THIS FILE
# └── ...                        <- Other project files
#
# Description: General utility functions for the build system. Added get_system_datetime.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250425-105000-PATHDEBUG # New UUID for path debugging
