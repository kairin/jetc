# filepath: /workspaces/jetc/buildx/scripts/env_setup.sh
#!/bin/bash

# =========================================================================
# Environment Setup Script
# Responsibility: Load .env, set initial script variables, define logging.
# =========================================================================

# --- Strict Mode & Globals ---
# set -eo pipefail # Consider enabling this in the main build.sh
SCRIPT_DIR_ENV_SETUP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR_ENV_SETUP/../.." && pwd)" # Assumes scripts/ is under buildx/
ENV_FILE="$PROJECT_ROOT/buildx/.env"

# --- Logging Setup ---
# Define colors (or check for tput)
if command -v tput >/dev/null && tput setaf 1 >/dev/null 2>&1; then
    COLOR_RESET=$(tput sgr0)
    COLOR_RED=$(tput setaf 1)
    COLOR_GREEN=$(tput setaf 2)
    COLOR_YELLOW=$(tput setaf 3)
    COLOR_BLUE=$(tput setaf 4)
    COLOR_MAGENTA=$(tput setaf 5)
    COLOR_CYAN=$(tput setaf 6)
    COLOR_WHITE=$(tput setaf 7)
    COLOR_BOLD=$(tput bold)
else
    COLOR_RESET="\033[0m"
    COLOR_RED="\033[0;31m"
    COLOR_GREEN="\033[0;32m"
    COLOR_YELLOW="\033[0;33m"
    COLOR_BLUE="\033[0;34m"
    COLOR_MAGENTA="\033[0;35m"
    COLOR_CYAN="\033[0;36m"
    COLOR_WHITE="\033[0;37m"
    COLOR_BOLD="\033[1m"
fi

# Logging functions
_log() {
    local color="$1"
    local level="$2"
    local message="$3"
    echo -e "${color}${level}:${COLOR_RESET} ${message}" >&2
}

log_info() { _log "$COLOR_BLUE" "INFO" "$1"; }
log_success() { _log "$COLOR_GREEN" "SUCCESS" "$1"; }
log_warning() { _log "$COLOR_YELLOW" "WARNING" "$1"; }
log_error() { _log "$COLOR_RED" "ERROR" "$1"; }
log_debug() {
    if [[ "${JETC_DEBUG:-0}" == "1" || "${JETC_DEBUG:-false}" == "true" ]]; then
        _log "$COLOR_CYAN" "DEBUG" "$1"
    fi
}

# --- Load .env File ---
# Loads variables from .env file in the buildx directory.
# Exports loaded variables.
load_env_variables() {
    log_debug "Looking for .env file at: $ENV_FILE"
    if [ -f "$ENV_FILE" ]; then
        log_debug "Sourcing environment variables from $ENV_FILE"
        # Read line by line to handle potential issues with `set -a`
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip comments and empty lines
            if [[ "$line" =~ ^\s*# ]] || [[ -z "$line" ]]; then
                continue
            fi
            # Export the variable
            export "$line"
            log_debug " -> Exported: $line"
        done < "$ENV_FILE"
        log_info "Loaded environment variables from $ENV_FILE"
        return 0
    else
        log_warning ".env file not found at $ENV_FILE. Using default values or environment variables."
        return 1
    fi
}

# --- Initial Script Variables ---
# Set default values if not loaded from .env or environment
export PLATFORM="${PLATFORM:-linux/arm64}"
export BUILDER_NAME="${BUILDER_NAME:-jetson-builder}"
export DEFAULT_BASE_IMAGE="${DEFAULT_BASE_IMAGE:-nvcr.io/nvidia/l4t-pytorch:r35.4.1-pth2.1-py3}" # Example default
export JETC_DEBUG="${JETC_DEBUG:-0}" # Default debug to off

# Log initial important variables
log_debug "Initial PLATFORM: $PLATFORM"
log_debug "Initial BUILDER_NAME: $BUILDER_NAME"
log_debug "Initial DEFAULT_BASE_IMAGE: $DEFAULT_BASE_IMAGE"
log_debug "Initial JETC_DEBUG: $JETC_DEBUG"

# --- Main Execution (Load .env) ---
# Always attempt to load .env when this script is sourced
load_env_variables

# --- Footer --- (Add standard footer manually or via hook)

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── env_setup.sh       <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Loads .env, sets initial script variables (PLATFORM, BUILDER_NAME, etc.), defines logging functions and colors.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-100500-ENVSETUP
