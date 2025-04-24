#!/bin/bash

# Environment setup functions for Jetson Container build system

SCRIPT_DIR_ENVSETUP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR_ENVSETUP/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_ENVSETUP/env_helpers.sh" || { echo "Error: env_helpers.sh not found."; exit 1; }

# Define color codes (optional, for terminal output)
C_RESET='\033[0m'
C_INFO='\033[0;32m'    # Green
C_WARN='\033[0;33m'    # Yellow
C_ERROR='\033[0;31m'   # Red
C_DEBUG='\033[0;36m'   # Cyan

# =========================================================================
# Function: Log debug message (only if JETC_DEBUG=true or 1)
# Arguments: $1 = message
# Returns: 0
# =========================================================================
log_debug() {
    if [[ "${JETC_DEBUG}" == "true" || "${JETC_DEBUG}" == "1" ]]; then
        # Log to stderr, include caller function name if available
        echo -e "${C_DEBUG}[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - ${FUNCNAME[1]:-<script>}: $1${C_RESET}" >&2
        # Optionally log to main log file as well, without color codes
        [[ -n "${MAIN_LOG:-}" ]] && echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - ${FUNCNAME[1]:-<script>}: $1" >> "$MAIN_LOG"
    fi
    return 0
}

# =========================================================================
# Function: Setup .env file with defaults if missing
# Arguments: None
# Returns: 0 on success, 1 on failure
# =========================================================================
setup_env_file() {
    local env_file="$ENV_CANONICAL"
    
    log_debug "Setting up .env file at $env_file"
    
    # If .env file doesn't exist, create it with defaults
    if [[ ! -f "$env_file" ]]; then
        log_debug ".env file not found, creating with defaults"
        
        # Create directory if it doesn't exist
        mkdir -p "$(dirname "$env_file")"
        
        # Create the file with default content
        cat > "$env_file" << EOF
# Docker registry URL (optional, leave empty for Docker Hub)
DOCKER_REGISTRY=

# Docker registry username (required)
DOCKER_USERNAME=jetc

# Docker repository prefix (required)
DOCKER_REPO_PREFIX=jetc

# Default base image for builds (last selected)
DEFAULT_BASE_IMAGE=nvcr.io/nvidia/l4t-pytorch:r35.4.1-py3

# Available container images (semicolon-separated, managed by build/run scripts)
AVAILABLE_IMAGES=nvcr.io/nvidia/l4t-pytorch:r35.4.1-py3

# Last used container settings for jetcrun.sh
DEFAULT_IMAGE_NAME=nvcr.io/nvidia/l4t-pytorch:r35.4.1-py3
DEFAULT_ENABLE_X11=on
DEFAULT_ENABLE_GPU=on
DEFAULT_MOUNT_WORKSPACE=on
DEFAULT_USER_ROOT=on
EOF
    
        if [[ $? -ne 0 ]]; then
            log_error "Failed to create default .env file" # Use log_error
            return 1
        fi
        
        log_debug "Created default .env file at $env_file"
    else
        log_debug ".env file already exists at $env_file"
    fi

    # Validate the .env file has required variables
    load_env_variables
    
    if [[ -z "${DOCKER_USERNAME:-}" || -z "${DOCKER_REPO_PREFIX:-}" ]]; then
        log_error ".env file missing required variables (DOCKER_USERNAME, DOCKER_REPO_PREFIX)" # Use log_error
        return 1
    fi
    
    log_debug "Finished setting up environment file."
    return 0
}

# =========================================================================
# Function: Initialize logging system
# Arguments: $1 = log directory, $2 = main log file, $3 = error log file
# Returns: 0 on success, 1 on failure
# =========================================================================
init_logging() {
    local log_dir="${1:-logs}"
    local main_log="${2:-build.log}"
    local error_log="${3:-errors.log}"
    
    # Create log directory if it doesn't exist
    if [[ ! -d "$log_dir" ]]; then
        log_debug "Creating log directory: $log_dir"
        mkdir -p "$log_dir" || {
            echo -e "${C_ERROR}Error: Failed to create log directory: $log_dir${C_RESET}" >&2 # Direct echo before logging is fully setup
            return 1
        }
    
    # Initialize log files
    > "$main_log" || {
        echo -e "${C_ERROR}Error: Failed to create/clear main log file: $main_log${C_RESET}" >&2
        return 1
    }
    
    > "$error_log" || {
        echo -e "${C_ERROR}Error: Failed to create/clear error log file: $error_log${C_RESET}" >&2
        return 1
    }
    
    # Export log file paths for use in other scripts
    export MAIN_LOG="$main_log"
    export ERROR_LOG="$error_log"
    
    log_debug "Logging initialized: MAIN_LOG=$main_log, ERROR_LOG=$error_log"
    return 0
}

# =========================================================================
# Function: Log informational message
# Arguments: $1 = message
# Returns: 0 (always successful)
# =========================================================================
log_message() {
    local message="$1"
    # Log to stderr with color, include caller function name
    echo -e "${C_INFO}[INFO] $(date '+%Y-%m-%d %H:%M:%S') - ${FUNCNAME[1]:-<script>}: $message${C_RESET}" >&2
    # Log to main log file without color
    [[ -n "${MAIN_LOG:-}" ]] && echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - ${FUNCNAME[1]:-<script>}: $message" >> "$MAIN_LOG"
    return 0
}
# Alias for backward compatibility / preference
log_info() { log_message "$@"; }

# =========================================================================
# Function: Log error message
# Arguments: $1 = message
# Returns: 0 (always successful)
# =========================================================================
log_error() {
    local message="$1"
    # Log to stderr with color, include caller function name
    echo -e "${C_ERROR}[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - ${FUNCNAME[1]:-<script>}: $message${C_RESET}" >&2
    # Log to error log file without color
    [[ -n "${ERROR_LOG:-}" ]] && echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - ${FUNCNAME[1]:-<script>}: $message" >> "$ERROR_LOG"
    # Also log to main log file
    [[ -n "${MAIN_LOG:-}" ]] && echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - ${FUNCNAME[1]:-<script>}: $message" >> "$MAIN_LOG"
    return 0
}

# =========================================================================
# Function: Log warning message
# Arguments: $1 = message
# Returns: 0 (always successful)
# =========================================================================
log_warning() {
    local message="$1"
    # Log to stderr with color, include caller function name
    echo -e "${C_WARN}[WARN] $(date '+%Y-%m-%d %H:%M:%S') - ${FUNCNAME[1]:-<script>}: $message${C_RESET}" >&2
    # Log to error log file without color
    [[ -n "${ERROR_LOG:-}" ]] && echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - ${FUNCNAME[1]:-<script>}: $message" >> "$ERROR_LOG"
    # Also log to main log file
    [[ -n "${MAIN_LOG:-}" ]] && echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - ${FUNCNAME[1]:-<script>}: $message" >> "$MAIN_LOG"
    return 0
}

# =========================================================================
# Function: Log success message
# Arguments: $1 = message
# Returns: 0 (always successful)
# =========================================================================
log_success() {
    local message="$1"
    # Log to stderr with color, include caller function name
    echo -e "${C_INFO}[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - ${FUNCNAME[1]:-<script>}: $message${C_RESET}" >&2
    # Log to main log file without color
    [[ -n "${MAIN_LOG:-}" ]] && echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - ${FUNCNAME[1]:-<script>}: $message" >> "$MAIN_LOG"
    return 0
}

# =========================================================================
# Function: Log start of script
# Arguments: None
# Returns: 0 (always successful)
# =========================================================================
log_start() {
    local msg="Script started"
    echo -e "${C_INFO}====================================================${C_RESET}" >&2
    echo -e "${C_INFO}[START] $(date '+%Y-%m-%d %H:%M:%S') - ${FUNCNAME[1]:-<script>}: $msg${C_RESET}" >&2
    echo -e "${C_INFO}====================================================${C_RESET}" >&2
    [[ -n "${MAIN_LOG:-}" ]] && {
        echo "====================================================" >> "$MAIN_LOG"
        echo "[START] $(date '+%Y-%m-%d %H:%M:%S') - ${FUNCNAME[1]:-<script>}: $msg" >> "$MAIN_LOG"
        echo "====================================================" >> "$MAIN_LOG"
    }
    return 0
}

# =========================================================================
# Function: Log end of script
# Arguments: None
# Returns: 0 (always successful)
# =========================================================================
log_end() {
    local msg="Script finished"
    echo -e "${C_INFO}====================================================${C_RESET}" >&2
    echo -e "${C_INFO}[END] $(date '+%Y-%m-%d %H:%M:%S') - ${FUNCNAME[1]:-<script>}: $msg${C_RESET}" >&2
    echo -e "${C_INFO}====================================================${C_RESET}" >&2
     [[ -n "${MAIN_LOG:-}" ]] && {
        echo "====================================================" >> "$MAIN_LOG"
        echo "[END] $(date '+%Y-%m-%d %H:%M:%S') - ${FUNCNAME[1]:-<script>}: $msg" >> "$MAIN_LOG"
        echo "====================================================" >> "$MAIN_LOG"
    }
    return 0
}

# =========================================================================
# Function: Set current build stage for logging context
# Arguments: $1 = stage name
# Returns: 0
# =========================================================================
set_stage() {
    export CURRENT_STAGE="$1"
    log_debug "Entering stage: $CURRENT_STAGE"
}

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── env_setup.sh       <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Environment setup and logging functions. Updated logging for consistency, debug, and origin.
# Author: GitHub Copilot
# COMMIT-TRACKING: UUID-20240806-103000-MODULAR
