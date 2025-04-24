#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/env_setup.sh

# =========================================================================
# Environment Setup Script
# Responsibility: Initialize logging, load .env, set global variables,
#                 and provide basic utility functions if others fail.
# =========================================================================

# Set strict mode early
set -euo pipefail

# --- Basic Setup ---
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)" # Assuming scripts is one level down from buildx
export BUILD_DIR="$PROJECT_ROOT/build"
export LOG_DIR="$PROJECT_ROOT/logs"
export ENV_FILE="$PROJECT_ROOT/.env"

# --- Source Core Utilities FIRST ---
# Source utils.sh for core functions like validate_variable
if [ -f "$SCRIPT_DIR/utils.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/utils.sh"
else
    echo "CRITICAL ERROR: utils.sh not found. Essential functions missing." >&2
    # Define minimal fallbacks ONLY if utils.sh is missing
    validate_variable() { echo "WARNING: validate_variable (fallback): Checking $1" >&2; [[ -n "$2" ]]; }
    get_system_datetime() { date +"%Y%m%d-%H%M%S"; }
    # Minimal logging fallbacks if utils.sh (and thus logging) is missing
    log_info() { echo "INFO: $1"; }
    log_warning() { echo "WARNING: $1" >&2; }
    log_error() { echo "ERROR: $1" >&2; }
    log_success() { echo "SUCCESS: $1"; }
    log_debug() { if [[ "${JETC_DEBUG:-0}" == "1" ]]; then echo "[DEBUG] $1" >&2; fi; }
fi

# --- Logging Initialization ---
# Source logging.sh (which might be part of utils.sh or separate)
# If logging.sh is separate and needed:
# if [ -f "$SCRIPT_DIR/logging.sh" ]; then
#     # shellcheck disable=SC1091
#     source "$SCRIPT_DIR/logging.sh"
# else
#     echo "WARNING: logging.sh not found. Using basic logging." >&2
# fi
# Initialize logging (assuming init_logging is defined in utils.sh or logging.sh)
if command -v init_logging &> /dev/null; then
    init_logging # Call the initialization function
else
    log_warning "init_logging function not found. Logging might be incomplete."
fi

# --- Debug Mode ---
export JETC_DEBUG="${JETC_DEBUG:-0}" # Default to 0 (off) if not set
if [[ "$JETC_DEBUG" == "1" || "$JETC_DEBUG" == "true" ]]; then
    log_debug "Debug mode enabled."
    set -x # Enable command tracing in debug mode
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
export DOCKER_USERNAME="${DOCKER_USERNAME:-default_user}"
export DOCKER_REPO_PREFIX="${DOCKER_REPO_PREFIX:-jetson-container}"
export DOCKER_REGISTRY="${DOCKER_REGISTRY:-}" # Default empty (Docker Hub)
export DEFAULT_BASE_IMAGE="${DEFAULT_BASE_IMAGE:-nvcr.io/nvidia/l4t-base:r35.4.1}" # Example default
export BUILDER_NAME="${BUILDER_NAME:-jetson-builder}"
export PLATFORM="${PLATFORM:-linux/arm64}"
export AVAILABLE_IMAGES="${AVAILABLE_IMAGES:-}" # Initialize as empty string

# Load the primary .env file using the robust method
load_dotenv "$ENV_FILE"

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

# --- Final Checks ---
log_debug "Environment setup script completed."

# --- Footer ---
# File location diagram: ... (omitted for brevity)
# Description: Initializes environment, loads .env safely, sets globals. Sourced utils.sh earlier.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250425-073000-ENVFIX2
