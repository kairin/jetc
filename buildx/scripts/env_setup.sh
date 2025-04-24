#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/env_setup.sh

# =========================================================================
# Environment Setup and Logging Initialization
# Responsibility: Load .env variables, set up global environment vars,
#                 initialize logging.
# =========================================================================

# --- Basic Setup ---
SCRIPT_DIR_ENV="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR_ENV/.." && pwd)" # Assumes scripts is one level down
ENV_FILE="$PROJECT_ROOT/.env"

# --- Global Variables (Defaults) ---
export ARCH="${ARCH:-linux/arm64}"
export PLATFORM="${PLATFORM:-$ARCH}" # Default PLATFORM to ARCH if not set
export CURRENT_DATE_TIME="" # Will be set by get_system_datetime
export BUILDER_NAME="jetson-builder" # Default builder name
export DEFAULT_BASE_IMAGE="" # Will be loaded from .env
export AVAILABLE_IMAGES="" # Will be loaded from .env
export DOCKER_USERNAME="" # Will be loaded from .env
export DOCKER_REPO_PREFIX="" # Will be loaded from .env
export DOCKER_REGISTRY="" # Will be loaded from .env

# Logging related (Defaults, might be overridden by load_env_variables if present in .env)
export LOG_DIR="$PROJECT_ROOT/logs"
export MAIN_LOG="" # Will be set by init_logging
export ERROR_LOG="" # Will be set by init_logging
export LOG_LEVEL="${LOG_LEVEL:-INFO}" # Default log level (INFO, DEBUG, WARN, ERROR, SUCCESS)
export JETC_DEBUG="${JETC_DEBUG:-false}" # Explicit debug flag

# --- Logging Functions ---
# Define colors (use defaults if utils.sh wasn't sourced/available)
RED="${RED:-\\033[0;31m}"
GREEN="${GREEN:-\\033[0;32m}"
YELLOW="${YELLOW:-\\033[1;33m}"
BLUE="${BLUE:-\\033[0;34m}"
NC="${NC:-\\033[0m}" # No Color

# Function to get current timestamp
get_system_datetime() {
    date -u +'%Y-%m-%d_%H-%M-%S_UTC' # Consistent UTC timestamp
}

# Initialize Logging (creates directory and sets log file paths)
init_logging() {
    local log_dir="$1"
    local main_log_path="$2"
    local error_log_path="$3"

    # Use defaults if arguments are empty
    if [[ -z "$log_dir" ]]; then
        log_dir="$LOG_DIR" # Use global default/loaded value
    fi
     if [[ -z "$main_log_path" || -z "$error_log_path" ]]; then
         local log_timestamp
         log_timestamp=$(get_system_datetime)
         main_log_path="${log_dir}/build-${log_timestamp}.log"
         error_log_path="${log_dir}/errors-${log_timestamp}.log"
     fi


    export LOG_DIR="$log_dir"
    export MAIN_LOG="$main_log_path"
    export ERROR_LOG="$error_log_path"

    mkdir -p "$LOG_DIR" || { echo "Error: Failed to create log directory $LOG_DIR"; exit 1; }
    # Touch files to ensure they exist
    touch "$MAIN_LOG" "$ERROR_LOG" || { echo "Error: Failed to create log files in $LOG_DIR"; exit 1; }
    # Set permissions? Maybe 644?
    chmod 644 "$MAIN_LOG" "$ERROR_LOG"

    # Use log_message to log initialization (avoids duplicate logging function definition issues)
    log_message "INFO" "Logging initialized. Main log: $MAIN_LOG, Error log: $ERROR_LOG"
}

# Core logging function
log_message() {
    local type="$1"
    local message="$2"
    local timestamp
    timestamp=$(date -u +'%Y-%m-%d %H:%M:%S') # Shorter timestamp for logs

    local color=$NC
    local log_prefix="[${type}]"
    local log_to_error_log=false

    case "$type" in
        ERROR) color=$RED; log_to_error_log=true ;;
        WARN) color=$YELLOW; log_to_error_log=true ;; # Also log warnings to error log
        SUCCESS) color=$GREEN ;;
        INFO) color=$BLUE ;;
        DEBUG) color=$YELLOW ;; # Use yellow for debug to stand out
        START) color=$GREEN; log_prefix="[START]" ;;
        END) color=$GREEN; log_prefix="[END]" ;;
        *) log_prefix="[${type}]" ;; # Handle custom types if needed
    esac

    # Determine if message should be logged based on LOG_LEVEL or JETC_DEBUG
    local should_log=false
    if [[ "$JETC_DEBUG" == "true" ]]; then
         should_log=true # Log everything if debug is true
    else
        case "$LOG_LEVEL" in
            DEBUG) should_log=true ;; # Log everything if level is DEBUG
            INFO) [[ "$type" == "INFO" || "$type" == "SUCCESS" || "$type" == "WARN" || "$type" == "ERROR" || "$type" == "START" || "$type" == "END" ]] && should_log=true ;;
            WARN) [[ "$type" == "WARN" || "$type" == "ERROR" || "$type" == "START" || "$type" == "END" ]] && should_log=true ;;
            ERROR) [[ "$type" == "ERROR" || "$type" == "START" || "$type" == "END" ]] && should_log=true ;;
            SUCCESS) [[ "$type" == "SUCCESS" || "$type" == "START" || "$type" == "END" ]] && should_log=true ;;
            *) should_log=true ;; # Default to log if level is unrecognized
        esac
        # Always log START and END regardless of level (except maybe ERROR level?)
         # Let's keep START/END logged unless level is strictly ERROR
         if [[ "$LOG_LEVEL" == "ERROR" && "$type" != "ERROR" && "$type" != "START" && "$type" != "END" ]]; then
             should_log=false
         fi

    fi


    if [[ "$should_log" == "true" ]]; then
         local caller_info=""
         # Get caller info (optional, can be resource intensive)
         # caller_info=" ($(basename "${BASH_SOURCE[1]}"):${BASH_LINENO[0]})" # Basic caller info

         # Log to main log file
         echo "${timestamp} - ${log_prefix}:${caller_info} ${message}" >> "$MAIN_LOG"

         # Log to error log file if applicable
         if [[ "$log_to_error_log" == "true" ]]; then
             echo "${timestamp} - ${log_prefix}:${caller_info} ${message}" >> "$ERROR_LOG"
         fi

         # Log to stdout/stderr
         # Send DEBUG, INFO, SUCCESS, START, END to stdout
         # Send WARN, ERROR to stderr
        local output_stream=1 # stdout
        if [[ "$type" == "WARN" || "$type" == "ERROR" ]]; then
            output_stream=2 # stderr
        fi
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
log_debug() { log_message "DEBUG" "$1"; } # Only logs if LOG_LEVEL=DEBUG or JETC_DEBUG=true


# =========================================================================
# Function: Load variables from .env file
# Arguments: None
# Returns: 0 on success, 1 if file not found
# Exports: Variables found in the .env file
# =========================================================================
load_env_variables() {
    log_debug "Attempting to load environment variables from: $ENV_FILE"
    if [ ! -f "$ENV_FILE" ]; then
        log_warning ".env file not found at $ENV_FILE. Using default values."
        # Ensure required defaults are explicitly set and exported if file missing
        export ARCH="${ARCH:-linux/arm64}"
        export PLATFORM="${PLATFORM:-$ARCH}"
        export BUILDER_NAME="${BUILDER_NAME:-jetson-builder}" # Ensure default is exported
        return 1 # Indicate file not found, but don't exit
    fi

    log_debug "Reading variables from $ENV_FILE"
    # Use set -a to automatically export variables read from the file
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a

    # Explicitly export potentially loaded variables with defaults if they are still empty
    export ARCH="${ARCH:-linux/arm64}"
    export PLATFORM="${PLATFORM:-$ARCH}"
    export BUILDER_NAME="${BUILDER_NAME:-jetson-builder}" # <-- FIX: Ensure export and default
    export DEFAULT_BASE_IMAGE="${DEFAULT_BASE_IMAGE:-}"
    export AVAILABLE_IMAGES="${AVAILABLE_IMAGES:-}"
    export DOCKER_USERNAME="${DOCKER_USERNAME:-}"
    export DOCKER_REPO_PREFIX="${DOCKER_REPO_PREFIX:-}"
    export DOCKER_REGISTRY="${DOCKER_REGISTRY:-}"
    export LOG_LEVEL="${LOG_LEVEL:-INFO}"
    export JETC_DEBUG="${JETC_DEBUG:-false}"

    log_debug "Finished loading variables from $ENV_FILE"
    log_debug "  -> ARCH=$ARCH"
    log_debug "  -> PLATFORM=$PLATFORM"
    log_debug "  -> BUILDER_NAME=$BUILDER_NAME"
    log_debug "  -> DOCKER_USERNAME=$DOCKER_USERNAME"
    log_debug "  -> LOG_LEVEL=$LOG_LEVEL"
    log_debug "  -> JETC_DEBUG=$JETC_DEBUG"
    # Add more debug logs as needed

    return 0
}

# =========================================================================
# Function: Setup basic build environment variables
# Arguments: None
# Returns: 0 (always succeeds for now)
# Exports: ARCH, PLATFORM, CURRENT_DATE_TIME
# =========================================================================
setup_build_environment() {
    log_info "Setting up build environment..."
    # ARCH and PLATFORM are now handled/defaulted during load_env_variables
    # Just ensure they are logged if needed
    log_debug "Using ARCH: ${ARCH}"
    log_debug "Using PLATFORM: ${PLATFORM}"

    # Set current timestamp
    export CURRENT_DATE_TIME
    CURRENT_DATE_TIME=$(get_system_datetime)
    log_debug "Set CURRENT_DATE_TIME: $CURRENT_DATE_TIME"

    log_success "Build environment setup complete."
    return 0
}


# --- Initialization Call ---
# Automatically initialize logging when this script is sourced
# Use default log dir/names initially; they might be updated by load_env_variables
init_logging "$LOG_DIR" "$MAIN_LOG" "$ERROR_LOG"


# --- Main Execution (for testing) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_info "Running env_setup.sh directly for testing..."

    # --- Test Setup --- #
    # Create a dummy .env file
    echo "Creating dummy .env file: $ENV_FILE"
    cat << EOF > "$ENV_FILE"
# Dummy .env for testing
export DOCKER_USERNAME="testuser"
DOCKER_REPO_PREFIX="testprefix"
# BUILDER_NAME is missing to test default
LOG_LEVEL=DEBUG
# ARCH=linux/amd64 # Test overriding default ARCH
EOF

    # --- Test Functions --- #
    log_info "*** Testing load_env_variables ***"
    load_env_variables
    log_info "Resulting Variables:"
    echo "  ARCH=$ARCH"
    echo "  PLATFORM=$PLATFORM"
    echo "  BUILDER_NAME=$BUILDER_NAME"
    echo "  DOCKER_USERNAME=$DOCKER_USERNAME"
    echo "  DOCKER_REPO_PREFIX=$DOCKER_REPO_PREFIX"
    echo "  LOG_LEVEL=$LOG_LEVEL"

    log_info "*** Testing setup_build_environment ***"
    setup_build_environment
    echo "  CURRENT_DATE_TIME=$CURRENT_DATE_TIME"

    log_info "*** Testing Logging Functions ***"
    log_debug "This is a debug message."
    log_info "This is an info message."
    log_success "This is a success message."
    log_warning "This is a warning message."
    log_error "This is an error message."

    # --- Cleanup --- #
    log_info "Cleaning up dummy .env file..."
    rm "$ENV_FILE"
    log_info "env_setup.sh test finished."
    exit 0
fi


# File location diagram:
# jetc/                          <- Main project folder
# ├── .env                       <- Optional environment variables file
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── env_setup.sh       <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Sets up environment variables (ARCH, PLATFORM, etc.), loads .env,
#              and initializes logging functions. Ensures BUILDER_NAME is exported with a default.
# Author: Mr K / GitHub Copilot / kairin
# COMMIT-TRACKING: UUID-20250424-202222-ENVSETUPFIX
