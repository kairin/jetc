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
UTILS_PATH="$SCRIPT_DIR/utils.sh"
if [ -f "$UTILS_PATH" ]; then
    # shellcheck disable=SC1091
    source "$UTILS_PATH"
    # Explicitly check if the crucial function is now defined
    if ! command -v validate_variable &> /dev/null; then
        echo "CRITICAL ERROR: Sourced '$UTILS_PATH' but 'validate_variable' function is still not defined. Check '$UTILS_PATH' for errors." >&2
        exit 1
    fi
    log_debug "'$UTILS_PATH' sourced successfully, 'validate_variable' is defined." # Use log_debug from utils.sh
else
    # If utils.sh is fundamentally missing, exit immediately. Fallbacks are unreliable.
    echo "CRITICAL ERROR: '$UTILS_PATH' not found. Essential functions missing. Cannot continue." >&2
    exit 1
    # --- Fallback logic removed - exit immediately if utils.sh is missing ---
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
# Now call validate_variable AFTER utils.sh is sourced and verified
log_debug "Validating essential variables..."
validate_variable "DOCKER_USERNAME" "$DOCKER_USERNAME" "Docker username is required." || exit 1
validate_variable "DOCKER_REPO_PREFIX" "$DOCKER_REPO_PREFIX" "Docker repository prefix is required." || exit 1
validate_variable "DEFAULT_BASE_IMAGE" "$DEFAULT_BASE_IMAGE" "Default base image is required." || exit 1
validate_variable "BUILDER_NAME" "$BUILDER_NAME" "Buildx builder name is required." || exit 1
validate_variable "PLATFORM" "$PLATFORM" "Target platform is required." || exit 1
# Ensure AVAILABLE_IMAGES is treated as a string, even if empty initially
export AVAILABLE_IMAGES="${AVAILABLE_IMAGES:-}"
log_debug "Final AVAILABLE_IMAGES after load: '${AVAILABLE_IMAGES}'"

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
# COMMIT-TRACKING: UUID-20250425-093000-ENVFIX4 # New UUID for this more robust fix
