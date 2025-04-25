#!/bin/bash
# filepath: /media/kkk/Apps/jetc/buildx/scripts/utils.sh

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

    # Check if main logging functions exist and use them if available
    if command -v log_debug &> /dev/null && command -v log_error &> /dev/null; then
        log_func_prefix="" # Use main logging functions (e.g., log_debug)
        main_log_prefix="log_" # Prefix for calling main loggers
    fi

    # Use the determined logging function (either main or fallback)
    # --- FIX START ---
    # Corrected the function call from log_log_debug to log_debug
    "${main_log_prefix}${log_func_prefix}debug" "Attempting to source $script_name: $script_path"
    # --- FIX END ---

    if [[ -f "$script_path" ]]; then
        # shellcheck disable=SC1090
        source "$script_path"
        local source_status=$?
        if [[ $source_status -ne 0 ]]; then
            # Use the determined logging function for error
            "${main_log_prefix}${log_func_prefix}error" "Error sourcing $script_name from $script_path (exit code $source_status)."
            return 1
        else
             # Use the determined logging function for debug
             # --- FIX START ---
             # Corrected the function call from log_log_debug to log_debug
             "${main_log_prefix}${log_func_prefix}debug" "$script_name sourced successfully."
             # --- FIX END ---
             return 0
        fi
    else
        # Use the determined logging function for error
        "${main_log_prefix}${log_func_prefix}error" "$script_name not found at path: '$script_path'"
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
        "${main_log_prefix}${log_func_prefix}warning" "capture_screenshot: No base filename provided."
        return 1
    fi

    # Check if scrot is installed
    if ! command -v scrot &> /dev/null; then
        "${main_log_prefix}${log_func_prefix}warning" "scrot command not found. Cannot capture screenshot. Please install scrot (sudo apt-get install scrot)."
        return 1
    fi

    # Determine effective log directory (use LOG_DIR if defined and valid, else /tmp)
    local effective_log_dir="/tmp" # Default fallback
    if [ -n "${LOG_DIR:-}" ] && [ -d "$LOG_DIR" ]; then
        effective_log_dir="$LOG_DIR"
    else
        "${main_log_prefix}${log_func_prefix}warning" "LOG_DIR ('${LOG_DIR:-}') not set or not a directory. Saving screenshot to /tmp."
    fi

    local timestamp
    timestamp=$(get_system_datetime) # Use existing function
    local screenshot_filename="${base_filename}_${timestamp}.png"
    local screenshot_path="$effective_log_dir/$screenshot_filename"

    # --- FIX START ---
    # Corrected the function call from log_log_debug to log_debug
    "${main_log_prefix}${log_func_prefix}debug" "Attempting to capture screenshot to: $screenshot_path"
    # --- FIX END ---

    # Capture the screenshot using scrot
    sleep 0.5 # Small delay before capture might help
    if scrot "$screenshot_path"; then
        # --- FIX START ---
        # Corrected the function call from log_log_debug to log_debug
        "${main_log_prefix}${log_func_prefix}debug" "Screenshot captured successfully: $screenshot_filename"
        # --- FIX END ---
        return 0
    else
        "${main_log_prefix}${log_func_prefix}error" "Failed to capture screenshot using scrot."
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
# COMMIT-TRACKING: UUID-20250425-123000-UTILSTYPOFIX # New UUID for this fix
