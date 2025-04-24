#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/logging.sh

# =========================================================================
# Logging Functions Script
# Responsibility: Define all logging functions, colors, and initialization.
# To be sourced ONCE by the main script.
# =========================================================================

# --- Basic Setup ---
# Avoid dependency on other scripts here if possible
SCRIPT_DIR_LOGGING="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_LOGGING="$(cd "$SCRIPT_DIR_LOGGING/.." && pwd)"

# --- Global Variables (Logging Specific Defaults) ---
# These can be overridden by environment variables before sourcing this script,
# or by loading .env separately in the main script.
export LOG_DIR="${LOG_DIR:-$PROJECT_ROOT_LOGGING/logs}"
export MAIN_LOG="${MAIN_LOG:-}" # Will be set by init_logging
export ERROR_LOG="${ERROR_LOG:-}" # Will be set by init_logging
export LOG_LEVEL="${LOG_LEVEL:-INFO}" # Default log level
export JETC_DEBUG="${JETC_DEBUG:-false}" # Explicit debug flag

# --- Logging Colors ---
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

# --- Logging Helper Functions ---

# Function to get current timestamp
get_system_datetime() {
    date -u +'%Y-%m-%d_%H-%M-%S_UTC' # Consistent UTC timestamp
}

# Core logging function
log_message() {
    local type="$1"
    # Ensure message ($2) is treated as a single argument even if empty
    local message="${2:-}" # Default to empty string if $2 is unset/null
    local timestamp
    timestamp=$(date -u +'%Y-%m-%d %H:%M:%S') # Shorter timestamp for logs

    # Check if logging has been initialized
    if [[ -z "$MAIN_LOG" || -z "$ERROR_LOG" ]]; then
        echo "ERROR: Logging not initialized. Call init_logging first." >&2
        # Attempt a basic init to prevent script failure if possible
        init_logging
        if [[ -z "$MAIN_LOG" || -z "$ERROR_LOG" ]]; then
             echo "FATAL: Failed to initialize logging even in fallback. Exiting." >&2
             exit 1
        fi
    fi


    local color=$NC
    local log_prefix="[${type}]"
    local log_to_error_log=false

    case "$type" in
        ERROR) color=$RED; log_to_error_log=true ;;
        WARN) color=$YELLOW; log_to_error_log=true ;;
        SUCCESS) color=$GREEN ;;
        INFO) color=$BLUE ;;
        DEBUG) color=$YELLOW ;;
        START) color=$GREEN; log_prefix="[START]" ;;
        END) color=$GREEN; log_prefix="[END]" ;;
        *) log_prefix="[${type}]" ;;
    esac

    # Determine if message should be logged based on LOG_LEVEL or JETC_DEBUG
    local should_log=false
    if [[ "$JETC_DEBUG" == "true" ]]; then
         should_log=true
    else
        case "$LOG_LEVEL" in
            DEBUG) should_log=true ;;
            INFO) [[ "$type" == "INFO" || "$type" == "SUCCESS" || "$type" == "WARN" || "$type" == "ERROR" || "$type" == "START" || "$type" == "END" ]] && should_log=true ;;
            WARN) [[ "$type" == "WARN" || "$type" == "ERROR" || "$type" == "START" || "$type" == "END" ]] && should_log=true ;;
            ERROR) [[ "$type" == "ERROR" || "$type" == "START" || "$type" == "END" ]] && should_log=true ;;
            SUCCESS) [[ "$type" == "SUCCESS" || "$type" == "START" || "$type" == "END" ]] && should_log=true ;;
            *) should_log=true ;; # Default to log if level is unrecognized
        esac
         # Adjust START/END logging based on level if desired (current logic logs them unless level is ERROR)
         if [[ "$LOG_LEVEL" == "ERROR" && "$type" != "ERROR" && "$type" != "START" && "$type" != "END" ]]; then
             should_log=false
         fi
    fi

    if [[ "$should_log" == "true" ]]; then
         local caller_info=""
         # caller_info=" ($(basename "${BASH_SOURCE[1]}"):${BASH_LINENO[0]})" # Optional: Basic caller info

         # Log to main log file
         echo "${timestamp} - ${log_prefix}:${caller_info} ${message}" >> "$MAIN_LOG"

         if [[ "$log_to_error_log" == "true" ]]; then
             echo "${timestamp} - ${log_prefix}:${caller_info} ${message}" >> "$ERROR_LOG"
         fi

         # Log to stdout/stderr
        local output_stream=1 # stdout
        if [[ "$type" == "WARN" || "$type" == "ERROR" ]]; then output_stream=2; fi # stderr
         echo -e "${color}${log_prefix}${NC} ${timestamp} - ${caller_info} ${message}" >&$output_stream
    fi
}

# Convenience logging functions
log_start() { log_message "START" "Script started"; }
log_end() { log_message "END" "Script finished"; }
log_info() { log_message "INFO" "$1"; }
log_success() { log_message "SUCCESS" "$1"; }
log_warning() { log_message "WARN" "$1"; }
log_error() { log_message "ERROR" "$1"; }
log_debug() { log_message "DEBUG" "$1"; }


# Initialize Logging (creates directory and sets log file paths)
init_logging() {
    # Use existing LOG_DIR or default
    local log_dir_to_use="${LOG_DIR:-$PROJECT_ROOT_LOGGING/logs}"

    # Generate timestamped paths if MAIN_LOG/ERROR_LOG aren't already set
    if [[ -z "$MAIN_LOG" || -z "$ERROR_LOG" ]]; then
         local log_timestamp
         log_timestamp=$(get_system_datetime)
         export MAIN_LOG="${log_dir_to_use}/build-${log_timestamp}.log"
         export ERROR_LOG="${log_dir_to_use}/errors-${log_timestamp}.log"
    fi

    export LOG_DIR="$log_dir_to_use" # Ensure LOG_DIR is exported

    mkdir -p "$LOG_DIR" || { echo "Error: Failed to create log directory $LOG_DIR"; exit 1; }
    touch "$MAIN_LOG" "$ERROR_LOG" || { echo "Error: Failed to create log files in $LOG_DIR"; exit 1; }
    chmod 644 "$MAIN_LOG" "$ERROR_LOG"

    # Use log_message to log initialization *after* MAIN_LOG/ERROR_LOG are set
    log_message "INFO" "Logging initialized. Main log: $MAIN_LOG, Error log: $ERROR_LOG"
}

# --- Main Execution (for testing) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Initialize logging when run directly for testing
    init_logging

    log_info "Running logging.sh directly for testing..."
    log_debug "This is a debug message."
    log_info "This is an info message."
    log_success "This is a success message."
    log_warning "This is a warning message."
    log_error "This is an error message."
    log_start
    log_end
    log_info "Logging script test finished."
    exit 0
fi

# --- Footer ---
# File location diagram: ... (omitted)
# Description: Centralized logging functions and initialization.
# Author: Mr K / GitHub Copilot / kairin
# COMMIT-TRACKING: UUID-20250424-204545-LOGGINGSCRIPT
