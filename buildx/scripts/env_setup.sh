#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/env_setup.sh

# =========================================================================
# Environment Setup Script
# Responsibility: Load .env variables, set up global environment vars (non-logging).
# Logging functions are now in logging.sh
# =========================================================================

# --- Basic Setup ---
SCRIPT_DIR_ENV="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR_ENV/.." && pwd)" # Assumes scripts is one level down
ENV_FILE="$PROJECT_ROOT/.env"

# --- Global Variables (Defaults - Non-Logging) ---
export ARCH="${ARCH:-linux/arm64}"
export PLATFORM="${PLATFORM:-$ARCH}" # Default PLATFORM to ARCH if not set
export BUILDER_NAME="${BUILDER_NAME:-jetson-builder}" # Default builder name
export DEFAULT_BASE_IMAGE="${DEFAULT_BASE_IMAGE:-}"
export AVAILABLE_IMAGES="${AVAILABLE_IMAGES:-}"
export DOCKER_USERNAME="${DOCKER_USERNAME:-}"
export DOCKER_REPO_PREFIX="${DOCKER_REPO_PREFIX:-}"
export DOCKER_REGISTRY="${DOCKER_REGISTRY:-}"
# Logging related defaults are now in logging.sh
# export LOG_DIR, MAIN_LOG, ERROR_LOG, LOG_LEVEL, JETC_DEBUG (Defaults in logging.sh)

# --- Logging Function Placeholders (If logging.sh wasn't sourced) ---
# Define basic fallbacks ONLY if the real functions don't exist yet.
if ! declare -f log_info > /dev/null; then
    echo "Warning: Logging functions not found (logging.sh likely not sourced yet). Defining basic fallbacks for env_setup." >&2
    log_info() { echo "INFO: $1"; }
    log_warning() { echo "WARNING: $1" >&2; }
    log_error() { echo "ERROR: $1" >&2; }
    log_success() { echo "SUCCESS: $1"; }
    log_debug() { :; } # Debug does nothing in fallback
fi

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
        # Ensure required defaults are explicitly exported if file missing
        export ARCH="${ARCH:-linux/arm64}"
        export PLATFORM="${PLATFORM:-$ARCH}"
        export BUILDER_NAME="${BUILDER_NAME:-jetson-builder}"
        # Logging vars defaults are handled by logging.sh
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
    export BUILDER_NAME="${BUILDER_NAME:-jetson-builder}"
    export DEFAULT_BASE_IMAGE="${DEFAULT_BASE_IMAGE:-}"
    export AVAILABLE_IMAGES="${AVAILABLE_IMAGES:-}"
    export DOCKER_USERNAME="${DOCKER_USERNAME:-}"
    export DOCKER_REPO_PREFIX="${DOCKER_REPO_PREFIX:-}"
    export DOCKER_REGISTRY="${DOCKER_REGISTRY:-}"
    # Export logging vars loaded from .env so they override defaults in logging.sh
    export LOG_DIR="${LOG_DIR:-}" # Allow override
    export LOG_LEVEL="${LOG_LEVEL:-INFO}" # Allow override
    export JETC_DEBUG="${JETC_DEBUG:-false}" # Allow override

    log_debug "Finished loading variables from $ENV_FILE"
    log_debug "  -> ARCH=$ARCH"
    log_debug "  -> PLATFORM=$PLATFORM"
    log_debug "  -> BUILDER_NAME=$BUILDER_NAME"
    log_debug "  -> DOCKER_USERNAME=$DOCKER_USERNAME"
    log_debug "  -> LOG_LEVEL=$LOG_LEVEL"
    log_debug "  -> JETC_DEBUG=$JETC_DEBUG"

    return 0
}

# --- Load .env file ---
# Use set -a to export all variables defined in .env
# Use set +a to return to default behavior
load_dotenv() {
    local dotenv_path="$1"
    if [ -f "$dotenv_path" ]; then
        log_debug "Loading environment variables from $dotenv_path"
        set -a # Automatically export all variables defined from now on
        # shellcheck disable=SC1090 # Source file dynamically
        source "$dotenv_path"
        set +a # Stop automatically exporting variables
        log_debug ".env file loaded."
        # Explicitly re-export potentially overwritten critical vars if needed
        export SCRIPT_DIR LOG_DIR LOG_FILE ERROR_LOG_FILE SUMMARY_LOG_FILE JETC_DEBUG
    else
        log_warning "$dotenv_path not found. Using default values."
    fi
}

# Load the primary .env file
load_dotenv "$ENV_FILE"

# --- Validate Essential Variables ---
# Ensure critical variables loaded from .env or defaults are set
validate_variable "DOCKER_USERNAME" "$DOCKER_USERNAME" "Docker username is required." || exit 1
validate_variable "DOCKER_REPO_PREFIX" "$DOCKER_REPO_PREFIX" "Docker repository prefix is required." || exit 1
validate_variable "DEFAULT_BASE_IMAGE" "$DEFAULT_BASE_IMAGE" "Default base image is required." || exit 1
# Ensure AVAILABLE_IMAGES is treated as a string, even if empty initially
export AVAILABLE_IMAGES="${AVAILABLE_IMAGES:-}"
log_debug "Initial AVAILABLE_IMAGES: '${AVAILABLE_IMAGES}'"


# =========================================================================
# Function: Setup basic build environment variables (Non-Logging)
# Arguments: None
# Returns: 0 (always succeeds for now)
# Exports: ARCH, PLATFORM
# =========================================================================
setup_build_environment() {
    log_info "Setting up build environment..."
    # ARCH and PLATFORM are now handled/defaulted during load_env_variables
    log_debug "Using ARCH: ${ARCH}"
    log_debug "Using PLATFORM: ${PLATFORM}"

    # CURRENT_DATE_TIME is more related to logging/timestamps, handled there now
    # export CURRENT_DATE_TIME; CURRENT_DATE_TIME=$(get_system_datetime)
    # log_debug "Set CURRENT_DATE_TIME: $CURRENT_DATE_TIME"

    log_success "Build environment setup complete."
    return 0
}


# --- Initialization Call ---
# Load .env variables automatically when this script is sourced
load_env_variables


# --- Main Execution (for testing) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # If testing directly, source logging.sh first
    if [ -f "$SCRIPT_DIR_ENV/logging.sh" ]; then source "$SCRIPT_DIR_ENV/logging.sh"; init_logging; else echo "ERROR: Cannot find logging.sh for test."; exit 1; fi

    log_info "Running env_setup.sh directly for testing..."
    # Test Setup, Execution, Cleanup ... (omitted for brevity, same as before)
    log_info "env_setup.sh test finished."
    exit 0
fi

# --- Footer ---
# File location diagram: ... (omitted)
# Description: Sets up non-logging environment variables, loads .env. Relies on logging.sh.
# Author: Mr K / GitHub Copilot / kairin
# COMMIT-TRACKING: UUID-20250424-204545-LOGGINGSCRIPT
