#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/env_setup.sh

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
# Source utils.sh for core functions like validate_variable and logging helpers
if [ -f "$SCRIPT_DIR/utils.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/utils.sh"
else
    # Minimal fallbacks ONLY if utils.sh is missing
    echo "CRITICAL ERROR: utils.sh not found. Essential functions missing." >&2
    validate_variable() { echo "WARNING: validate_variable (fallback): Checking $1" >&2; [[ -n "$2" ]]; }
    get_system_datetime() { date +"%Y%m%d-%H%M%S"; }
    # Minimal logging fallbacks if utils.sh (and thus logging) is missing
    log_info() { echo "INFO: $1"; }
    log_warning() { echo "WARNING: $1" >&2; }
    log_error() { echo "ERROR: $1" >&2; }
    log_success() { echo "SUCCESS: $1"; }
    log_debug() { if [[ "${JETC_DEBUG:-0}" == "1" ]]; then echo "[DEBUG] $1" >&2; fi; }
    # Define capture_screenshot fallback if utils.sh is missing
    capture_screenshot() { log_warning "capture_screenshot: utils.sh not loaded, cannot capture."; return 1; }
fi

# --- Logging Initialization ---
# Initialize logging using functions potentially defined in utils.sh
# If utils.sh was missing, minimal fallbacks are used.
# init_logging function should be defined in logging.sh (sourced by utils.sh or main script)
if command -v init_logging &> /dev/null; then
    init_logging # Call the initialization function
else
    log_warning "init_logging function not found. Logging might be basic or uninitialized."
fi
log_info "--- Initializing Environment Setup ---"

# --- Debug Mode ---
# Check JETC_DEBUG environment variable (set externally or in .env)
if [[ "${JETC_DEBUG:-0}" == "1" || "${JETC_DEBUG,,}" == "true" ]]; then
    export JETC_DEBUG=1
    log_info "Debug mode enabled."
    set -x # Enable command tracing
else
    export JETC_DEBUG=0
    log_debug "Debug mode disabled." # This won't show unless JETC_DEBUG was already 1
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
export DOCKER_USERNAME="${DOCKER_USERNAME:-jetson}"
export DOCKER_REPO_PREFIX="${DOCKER_REPO_PREFIX:-jetc}"
export DOCKER_REGISTRY="${DOCKER_REGISTRY:-}" # Default to Docker Hub
export DEFAULT_BASE_IMAGE="${DEFAULT_BASE_IMAGE:-kairin/jetc:nvcr-io-nvidia-pytorch-25.03-py3}"
export BUILDER_NAME="${BUILDER_NAME:-jetson-builder}"
export LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/../logs}"
export LOG_LEVEL="${LOG_LEVEL:-INFO}" # Default log level
export AVAILABLE_IMAGES="${AVAILABLE_IMAGES:-}" # Initialize as empty string

# Load the primary .env file using the robust method
load_dotenv "$ENV_FILE"

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
# Now call validate_variable AFTER utils.sh is sourced and .env is loaded
log_debug "Validating essential variables..."
validate_variable "DOCKER_USERNAME" "$DOCKER_USERNAME" "Docker username is required." || exit 1
validate_variable "DOCKER_REPO_PREFIX" "$DOCKER_REPO_PREFIX" "Docker repository prefix is required." || exit 1
validate_variable "DEFAULT_BASE_IMAGE" "$DEFAULT_BASE_IMAGE" "Default base image is required." || exit 1
validate_variable "BUILDER_NAME" "$BUILDER_NAME" "Buildx builder name is required." || exit 1
validate_variable "PLATFORM" "$PLATFORM" "Target platform is required." || exit 1
# Ensure AVAILABLE_IMAGES is treated as a string, even if empty initially
export AVAILABLE_IMAGES="${AVAILABLE_IMAGES:-}"
log_debug "Final AVAILABLE_IMAGES after load: '${AVAILABLE_IMAGES}'"

# --- Source Core Utilities --- # REMOVED - Moved to top

# --- Final Checks ---
# Ensure log directory exists
if [ -n "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR" || log_warning "Could not create log directory: $LOG_DIR"
else
    log_warning "LOG_DIR variable is not set. Logs might not be saved correctly."
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
# COMMIT-TRACKING: UUID-20250425-083500-ENVFIX3 # Keeping previous fix UUID
