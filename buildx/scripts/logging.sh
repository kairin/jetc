#!/bin/bash
# filepath: /media/kkk/Apps/jetc/buildx/scripts/logging.sh

# Guard variable to prevent multiple initializations
declare -g LOGGING_INITIALIZED=0 # Use -g for global scope if needed across sourced scripts

# Define Colors (Example - ensure these are defined somewhere)
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_DIM='\033[2m'

# --- Logging Functions ---
# (Assuming functions like log_info, log_error etc. are defined below or sourced elsewhere before init_logging is called)

# =========================================================================
# Function: Initialize Logging System
# Creates log directory and files, sets up basic logging.
# Arguments: None
# Exports: MAIN_LOG_FILE, ERROR_LOG_FILE
# Returns: 0 on success, 1 on failure
# =========================================================================
init_logging() {
    # Check if already initialized
    if [[ "${LOGGING_INITIALIZED:-0}" -eq 1 ]]; then
        # Optionally log that we are skipping re-initialization (use debug level)
        # log_debug "Logging already initialized. Skipping re-init." # Requires log_debug to be defined
        return 0 # Successfully skipped
    fi

    # Ensure LOG_DIR exists (should be set by env_setup.sh before this is called)
    if [[ -z "${LOG_DIR:-}" ]]; then
        echo "ERROR: LOG_DIR is not set. Cannot initialize logging." >&2
        # Exit because logging is fundamental
        exit 1
    fi
    # Create log directory if it doesn't exist
    mkdir -p "$LOG_DIR" || { echo "ERROR: Failed to create log directory: $LOG_DIR" >&2; exit 1; }

    # Define log file paths using LOG_DIR
    local timestamp
    timestamp=$(date +"%Y-%m-%d_%H-%M-%S_%Z") # Consider using UTC: date -u +"%Y-%m-%d_%H-%M-%S_%Z"
    MAIN_LOG_FILE="${LOG_DIR}/build-${timestamp}.log"
    ERROR_LOG_FILE="${LOG_DIR}/errors-${timestamp}.log"
    # Export them so other scripts might see them if needed (though using log functions is preferred)
    export MAIN_LOG_FILE ERROR_LOG_FILE

    # Initialize log files (create/truncate)
    # Use > to truncate existing files or create new ones
    echo "--- Log Start: $(date) ---" > "$MAIN_LOG_FILE" || { echo "ERROR: Failed to write to main log file: $MAIN_LOG_FILE" >&2; exit 1; }
    echo "--- Error Log Start: $(date) ---" > "$ERROR_LOG_FILE" || { echo "ERROR: Failed to write to error log file: $ERROR_LOG_FILE" >&2; exit 1; }

    # Set permissions (optional, adjust as needed)
    chmod 644 "$MAIN_LOG_FILE" "$ERROR_LOG_FILE" >/dev/null 2>&1 || true # Best effort

    # Mark logging as initialized *before* the first log message
    LOGGING_INITIALIZED=1

    # Log initialization message *after* setting up files and marking as initialized
    # Use the log_info function itself now that files are ready
    # Make sure log_info is defined before this point!
    if command -v log_info &> /dev/null; then
        log_info "Logging initialized. Main log: $MAIN_LOG_FILE, Error log: $ERROR_LOG_FILE"
    else
        # Fallback if log_info isn't defined yet (shouldn't happen if sourced correctly)
        echo "INFO: Logging initialized. Main log: $MAIN_LOG_FILE, Error log: $ERROR_LOG_FILE"
    fi

    return 0 # Indicate success
}

# --- Define Actual Logging Functions ---
# (Ensure these are present and correctly defined)

_log_base() {
    local level_name="$1"
    local color_code="$2"
    local message="$3"
    local log_file="$4"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S") # Consistent timestamp format

    # Console output with color
    echo -e "${color_code}${level_name}:${C_RESET} ${timestamp} - ${message}" >&2

    # File output without color
    echo "${level_name}: ${timestamp} - ${message}" >> "$log_file"
}

log_info() {
    [[ "${LOGGING_INITIALIZED:-0}" -ne 1 ]] && echo "INFO (pre-init): $1" >&2 && return 0
    _log_base "INFO" "$C_BLUE" "$1" "$MAIN_LOG_FILE"
}

log_success() {
     [[ "${LOGGING_INITIALIZED:-0}" -ne 1 ]] && echo "SUCCESS (pre-init): $1" >&2 && return 0
    _log_base "SUCCESS" "$C_GREEN" "$1" "$MAIN_LOG_FILE"
}

log_warning() {
     [[ "${LOGGING_INITIALIZED:-0}" -ne 1 ]] && echo "WARNING (pre-init): $1" >&2 && return 0
    _log_base "WARNING" "$C_YELLOW" "$1" "$MAIN_LOG_FILE"
    # Also log warnings to the error log file
    echo "WARNING: $(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$ERROR_LOG_FILE"
}

log_error() {
     [[ "${LOGGING_INITIALIZED:-0}" -ne 1 ]] && echo "ERROR (pre-init): $1" >&2 && return 0
    _log_base "ERROR" "$C_RED" "$1" "$MAIN_LOG_FILE"
    # Also log errors to the error log file
    echo "ERROR: $(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$ERROR_LOG_FILE"
}

log_debug() {
    # Only log if JETC_DEBUG is set to 1 or true
    if [[ "${JETC_DEBUG:-0}" == "1" || "${JETC_DEBUG,,}" == "true" ]]; then
         [[ "${LOGGING_INITIALIZED:-0}" -ne 1 ]] && echo "[DEBUG] (pre-init): $1" >&2 && return 0
        _log_base "DEBUG" "$C_DIM" "$1" "$MAIN_LOG_FILE"
    fi
}

# --- Footer ---
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── logging.sh         <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Handles logging setup and functions for the build system.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250425-121500-LOGGINGFIX # New UUID for this fix
