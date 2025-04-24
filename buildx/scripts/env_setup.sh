#!/bin/bash

# Environment setup functions for Jetson Container build system

SCRIPT_DIR_ENVSETUP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR_ENVSETUP/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_ENVSETUP/env_helpers.sh" || { echo "Error: env_helpers.sh not found."; exit 1; }

# =========================================================================
# Function: Setup .env file with defaults if missing
# Arguments: None
# Returns: 0 on success, 1 on failure
# =========================================================================
setup_env_file() {
    local env_file="$ENV_CANONICAL"
    
    _log_debug "Setting up .env file at $env_file"
    
    # If .env file doesn't exist, create it with defaults
    if [[ ! -f "$env_file" ]]; then
        _log_debug ".env file not found, creating with defaults"
        
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
            _log_debug "Error: Failed to create default .env file"
            return 1
        fi
        
        _log_debug "Created default .env file at $env_file"
    else
        _log_debug ".env file already exists at $env_file"
    }
    
    # Validate the .env file has required variables
    load_env_variables
    
    if [[ -z "${DOCKER_USERNAME:-}" || -z "${DOCKER_REPO_PREFIX:-}" ]]; then
        _log_debug "Error: .env file missing required variables"
        return 1
    }
    
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
        _log_debug "Creating log directory: $log_dir"
        mkdir -p "$log_dir" || {
            echo "Error: Failed to create log directory: $log_dir" >&2
            return 1
        }
    }
    
    # Initialize log files
    > "$main_log" || {
        echo "Error: Failed to create/clear main log file: $main_log" >&2
        return 1
    }
    
    > "$error_log" || {
        echo "Error: Failed to create/clear error log file: $error_log" >&2
        return 1
    }
    
    # Export log file paths for use in other scripts
    export MAIN_LOG="$main_log"
    export ERROR_LOG="$error_log"
    
    _log_debug "Logging initialized: MAIN_LOG=$main_log, ERROR_LOG=$error_log"
    return 0
}

# =========================================================================
# Function: Log message
# Arguments: $1 = message, $2 = log file (optional, defaults to MAIN_LOG)
# Returns: 0 (always successful)
# =========================================================================
log_message() {
    local message="$1"
    local log_file="${2:-$MAIN_LOG}"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO: $message" | tee -a "$log_file"
    return 0
}

# =========================================================================
# Function: Log error message
# Arguments: $1 = message, $2 = log file (optional, defaults to ERROR_LOG)
# Returns: 0 (always successful)
# =========================================================================
log_error() {
    local message="$1"
    local log_file="${2:-$ERROR_LOG}"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $message" | tee -a "$log_file" >&2
    return 0
}

# =========================================================================
# Function: Log warning message
# Arguments: $1 = message, $2 = log file (optional, defaults to both logs)
# Returns: 0 (always successful)
# =========================================================================
log_warning() {
    local message="$1"
    local log_file="${2:-}"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: $message" | tee -a "$MAIN_LOG" >&2
    [[ -n "$log_file" ]] && echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: $message" >> "$log_file"
    return 0
}

# =========================================================================
# Function: Log success message
# Arguments: $1 = message, $2 = log file (optional, defaults to MAIN_LOG)
# Returns: 0 (always successful)
# =========================================================================
log_success() {
    local message="$1"
    local log_file="${2:-$MAIN_LOG}"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: $message" | tee -a "$log_file"
    return 0
}

# =========================================================================
# Function: Log start of script
# Arguments: $1 = log file (optional, defaults to MAIN_LOG)
# Returns: 0 (always successful)
# =========================================================================
log_start() {
    local log_file="${1:-$MAIN_LOG}"
    
    echo "====================================================" | tee -a "$log_file"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Script started" | tee -a "$log_file"
    echo "====================================================" | tee -a "$log_file"
    return 0
}

# =========================================================================
# Function: Log end of script
# Arguments: $1 = log file (optional, defaults to MAIN_LOG)
# Returns: 0 (always successful)
# =========================================================================
log_end() {
    local log_file="${1:-$MAIN_LOG}"
    
    echo "====================================================" | tee -a "$log_file"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Script completed" | tee -a "$log_file"
    echo "====================================================" | tee -a "$log_file"
    return 0
}

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── env_setup.sh       <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Environment setup and logging functions.
# Author: GitHub Copilot
# COMMIT-TRACKING: UUID-20240806-103000-MODULAR
