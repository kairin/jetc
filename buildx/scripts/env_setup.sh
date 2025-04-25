#!/bin/bash
# filepath: /media/kkk/Apps/jetc/buildx/scripts/env_setup.sh

# =========================================================================
# Environment Setup Script
# Responsibility: Load .env, set defaults, validate essential variables,
#                 initialize logging, and determine platform.
# =========================================================================

# Set strict mode
set -euo pipefail

# --- Script Path ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env" # Path to the .env file relative to this script

# --- Source Core Utilities FIRST ---
# Source utils.sh for core functions like validate_variable
UTILS_PATH="$SCRIPT_DIR/utils.sh"
if [ -f "$UTILS_PATH" ]; then
    # shellcheck disable=SC1091
    source "$UTILS_PATH"
    # Explicitly check if the crucial function is now defined
    if ! command -v validate_variable &> /dev/null; then
        # Use echo for critical bootstrap errors before logging is confirmed
        echo "CRITICAL ERROR: Sourced '$UTILS_PATH' but 'validate_variable' function is still not defined. Check '$UTILS_PATH' for errors." >&2
        exit 1
    fi
    # Use internal utils logger for this bootstrap message
    _utils_log_debug "'$UTILS_PATH' sourced successfully, core utils defined."
else
    # If utils.sh is fundamentally missing, exit immediately.
    echo "CRITICAL ERROR: '$UTILS_PATH' not found. Essential functions missing. Cannot continue." >&2
    exit 1
fi

# --- Set JETC_DEBUG Default EARLY ---
# Define and export JETC_DEBUG *before* sourcing logging.sh, which uses it.
# It might be overridden later by .env, but needs a default value now.
export JETC_DEBUG="${JETC_DEBUG:-0}"
_utils_log_debug "Initial JETC_DEBUG set to: $JETC_DEBUG"

# --- Logging Initialization ---
# Now attempt to source logging.sh and initialize the main logging system
LOGGING_PATH="$SCRIPT_DIR/logging.sh"
if [ -f "$LOGGING_PATH" ]; then
    # Use source_script (defined in utils.sh) to safely source logging.sh
    if source_script "$LOGGING_PATH" "Logging System"; then
        # Attempt to initialize logging if sourcing succeeded
        if command -v init_logging &> /dev/null; then
            # Set LOG_DIR default *before* calling init_logging
            export LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/../logs}"
            # Validate LOG_DIR before calling init_logging
            if validate_variable "LOG_DIR (pre-init)" "$LOG_DIR" "LOG_DIR is required for logging initialization."; then
                init_logging # Call the initialization function from logging.sh
                log_info "--- Initializing Environment Setup (using main logger) ---"
            else
                # If LOG_DIR validation fails here, logging cannot be initialized.
                echo "CRITICAL ERROR: LOG_DIR validation failed before logging could be initialized." >&2
                exit 1
            fi
        else
            _utils_log_warning "init_logging function not found after sourcing logging.sh. Logging might be incomplete." # Use fallback logger
            # Define main log functions as fallbacks if they weren't defined by failed source
            if ! command -v log_info &> /dev/null; then log_info() { _utils_log_info "$@"; }; fi
            if ! command -v log_warning &> /dev/null; then log_warning() { _utils_log_warning "$@"; }; fi
            if ! command -v log_error &> /dev/null; then log_error() { _utils_log_error "$@"; }; fi
            if ! command -v log_success &> /dev/null; then log_success() { echo "SUCCESS (env_setup fallback): $1"; }; fi
            if ! command -v log_debug &> /dev/null; then log_debug() { _utils_log_debug "$@"; }; fi
            log_info "--- Initializing Environment Setup (using fallback logger) ---" # Use the (potentially fallback) log_info
        fi
    else
        # Sourcing logging.sh failed, rely on utils fallbacks
         _utils_log_warning "Failed to source '$LOGGING_PATH'. Using basic fallback logging."
         # Define main log functions as fallbacks if they weren't defined by failed source
         if ! command -v log_info &> /dev/null; then log_info() { _utils_log_info "$@"; }; fi
         if ! command -v log_warning &> /dev/null; then log_warning() { _utils_log_warning "$@"; }; fi
         if ! command -v log_error &> /dev/null; then log_error() { _utils_log_error "$@"; }; fi
         if ! command -v log_success &> /dev/null; then log_success() { echo "SUCCESS (env_setup fallback): $1"; }; fi # Add success fallback
         if ! command -v log_debug &> /dev/null; then log_debug() { _utils_log_debug "$@"; }; fi
         log_info "--- Initializing Environment Setup (using fallback logger) ---" # Use the (potentially fallback) log_info
    fi
else
    # logging.sh not found, rely on utils fallbacks
    _utils_log_warning "'$LOGGING_PATH' not found. Using basic fallback logging."
    # Define main log functions as fallbacks
    log_info() { _utils_log_info "$@"; }
    log_warning() { _utils_log_warning "$@"; }
    log_error() { _utils_log_error "$@"; }
    log_success() { echo "SUCCESS (env_setup fallback): $1"; }
    log_debug() { _utils_log_debug "$@"; }
    log_info "--- Initializing Environment Setup (using fallback logger) ---" # Use the fallback log_info
fi


# --- Load .env file ---
# Use a more robust method to read variables without executing
load_dotenv() {
    local dotenv_path="$1"
    if [ -f "$dotenv_path" ]; then
        log_debug "Loading environment variables from $dotenv_path"
        # Read line by line, ignore comments/empty lines, export valid VAR=value pairs
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Remove leading/trailing whitespace
            line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            # Ignore empty lines and comments
            if [[ -z "$line" || "$line" =~ ^# ]]; then
                continue
            fi
            # Check if it looks like a variable assignment
            if [[ "$line" =~ ^[a-zA-Z_][a-zA-Z0-9_]*= ]]; then
                 log_debug "Exporting from .env: $line"
                 export "$line" # Export the valid assignment line
            else
                 log_warning "Ignoring invalid line in $dotenv_path: $line"
            fi
        done < "$dotenv_path"
        log_debug ".env file loaded."
    else
        log_warning "$dotenv_path not found. Using default values."
    fi
}

# --- Default Values ---
# Set defaults BEFORE loading .env, so .env can override them
# JETC_DEBUG default was set earlier
export DOCKER_USERNAME="${DOCKER_USERNAME:-jetson}"
export DOCKER_REPO_PREFIX="${DOCKER_REPO_PREFIX:-jetc}"
export DOCKER_REGISTRY="${DOCKER_REGISTRY:-}" # Default to Docker Hub
export DEFAULT_BASE_IMAGE="${DEFAULT_BASE_IMAGE:-kairin/jetc:nvcr-io-nvidia-pytorch-25.03-py3}"
export BUILDER_NAME="${BUILDER_NAME:-jetson-builder}"
# LOG_DIR default was already set before init_logging
export LOG_LEVEL="${LOG_LEVEL:-INFO}" # Default log level
export AVAILABLE_IMAGES="${AVAILABLE_IMAGES:-}" # Initialize as empty string

# Load the primary .env file using the robust method
load_dotenv "$ENV_FILE"

# --- Final Debug Mode Check ---
# Re-check JETC_DEBUG after loading .env, as it might have changed
if [[ "${JETC_DEBUG:-0}" == "1" || "${JETC_DEBUG,,}" == "true" ]]; then
    export JETC_DEBUG=1
    # Only enable 'set -x' if it wasn't already enabled
    [[ $- != *x* ]] && log_info "Debug mode enabled (set in .env or previously)." && set -x
else
    export JETC_DEBUG=0
    # Disable 'set -x' if it was enabled
    [[ $- == *x* ]] && set +x && log_info "Debug mode disabled (set in .env or default)."
fi


# --- Re-validate LOG_DIR after loading .env ---
# Ensure LOG_DIR has a value before proceeding (in case .env unset it)
export LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/../logs}" # Re-apply default if .env unset it or was empty
validate_variable "LOG_DIR (post-load)" "$LOG_DIR" "LOG_DIR is required but is empty after loading .env." || exit 1

# --- Platform Detection ---
# Determine the host architecture and set the PLATFORM variable
HOST_ARCH=$(uname -m)
if [[ "$HOST_ARCH" == "aarch64" ]]; then
    export PLATFORM="linux/arm64"
elif [[ "$HOST_ARCH" == "x86_64" ]]; then
    export PLATFORM="linux/amd64"
else
    log_warning "Unsupported host architecture: $HOST_ARCH. Defaulting to linux/arm64."
    export PLATFORM="linux/arm64"
fi
log_info "Detected platform: $PLATFORM"

# --- Validate Essential Variables ---
# Now call validate_variable AFTER utils.sh is sourced and verified
log_debug "Validating essential variables..." # This uses the main logger (or fallback)
validate_variable "DOCKER_USERNAME" "$DOCKER_USERNAME" "Docker username is required." || exit 1
validate_variable "DOCKER_REPO_PREFIX" "$DOCKER_REPO_PREFIX" "Docker repository prefix is required." || exit 1
validate_variable "DEFAULT_BASE_IMAGE" "$DEFAULT_BASE_IMAGE" "Default base image is required." || exit 1
validate_variable "BUILDER_NAME" "$BUILDER_NAME" "Buildx builder name is required." || exit 1
validate_variable "PLATFORM" "$PLATFORM" "Target platform is required." || exit 1
# Ensure AVAILABLE_IMAGES is treated as a string, even if empty initially
export AVAILABLE_IMAGES="${AVAILABLE_IMAGES:-}"
log_debug "Final AVAILABLE_IMAGES after load: '${AVAILABLE_IMAGES}'"

# --- Final Checks ---
# Ensure log directory exists (already done in init_logging, but double-check doesn't hurt)
if [ -n "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR" || log_warning "Could not create log directory: $LOG_DIR"
else
    # This case should not be reachable due to the validation above
    log_error "LOG_DIR variable is unexpectedly empty after validation."
    exit 1
fi

log_info "--- Environment Setup Complete ---"

# --- Footer ---
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── env_setup.sh       <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Loads .env, sets defaults, validates variables, initializes logging.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250425-122500-JETCDEBUGFIX # New UUID for this fix
