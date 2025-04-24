#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/env_setup.sh

# =========================================================================
# Environment Setup Script
# Responsibility: Load .env, set defaults, define colors & basic logging.
# =========================================================================

# --- Configuration ---
SCRIPT_DIR_ENV_SETUP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE_PATH="${SCRIPT_DIR_ENV_SETUP}/../.env" # Canonical path to .env

# --- Load .env File ---
# Load environment variables from .env file if it exists
if [ -f "$ENV_FILE_PATH" ]; then
    # Use set -a to export all variables defined in the .env file
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE_PATH"
    set +a
    echo "INFO: Loaded environment variables from $ENV_FILE_PATH"
else
    echo "WARNING: Environment file ($ENV_FILE_PATH) not found. Using defaults and potentially prompting for required values."
fi

# --- Set Default Variables (if not already set by .env) ---
export PLATFORM="${PLATFORM:-linux/arm64}"
export ARCH="${ARCH:-arm64}" # Or derive from uname -m if needed
export BUILD_DIR="${BUILD_DIR:-${SCRIPT_DIR_ENV_SETUP}/../build}"
export LOG_DIR="${LOG_DIR:-${SCRIPT_DIR_ENV_SETUP}/../logs}"
export JETC_DEBUG="${JETC_DEBUG:-false}" # Control debug logging

# --- Define Color Codes ---
export COLOR_RESET='[0m'
export COLOR_RED='[0;31m'
export COLOR_GREEN='[0;32m'
export COLOR_YELLOW='[0;33m'
export COLOR_BLUE='[0;34m'
export COLOR_CYAN='[0;36m'

# --- Basic Logging Functions ---
# Usage: log_info "This is an info message"
log_info() {
    echo -e "${COLOR_BLUE}INFO:${COLOR_RESET} $1"
}

# Usage: log_warning "This is a warning message"
log_warning() {
    echo -e "${COLOR_YELLOW}WARNING:${COLOR_RESET} $1" >&2
}

# Usage: log_error "This is an error message"
log_error() {
    echo -e "${COLOR_RED}ERROR:${COLOR_RESET} $1" >&2
}

# Usage: log_success "This is a success message"
log_success() {
    echo -e "${COLOR_GREEN}SUCCESS:${COLOR_RESET} $1"
}

# Usage: log_debug "This is a debug message" (only prints if JETC_DEBUG=true)
log_debug() {
  if [[ "${JETC_DEBUG}" == "true" || "${JETC_DEBUG}" == "1" ]]; then
    echo -e "${COLOR_CYAN}DEBUG:${COLOR_RESET} $1" >&2
  fi
}

# --- Utility Functions ---
# Get current system datetime in YYYYMMDD-HHMMSS format
get_system_datetime() {
  date +"%Y%m%d-%H%M%S"
}

# --- Initial Checks ---
# Check if essential directories exist
if [ ! -d "$BUILD_DIR" ]; then
    log_warning "Build directory ($BUILD_DIR) not found. Build might fail if stages are expected."
    # Consider creating it: mkdir -p "$BUILD_DIR"
fi
if [ ! -d "$LOG_DIR" ]; then
    log_info "Log directory ($LOG_DIR) not found. Creating it."
    mkdir -p "$LOG_DIR" || { log_error "Failed to create log directory: $LOG_DIR"; exit 1; }
fi

log_debug "env_setup.sh completed."

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── env_setup.sh       <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Handles initial environment setup: loads .env, sets defaults, defines colors and basic logging functions.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-090000-ENVSTP
