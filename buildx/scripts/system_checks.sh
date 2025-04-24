#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/system_checks.sh

# =========================================================================
# System Checks Script
# Responsibility: Verify essential system tools are installed.
# =========================================================================

# Source logging functions if available (optional, depends on execution context)
if [ -f "$(dirname "${BASH_SOURCE[0]}")/env_setup.sh" ]; then
    # shellcheck disable=SC1091
    source "$(dirname "${BASH_SOURCE[0]}")/env_setup.sh"
else
    # Define basic logging fallbacks if env_setup isn't sourced
    log_info() { echo "INFO: $1" >&2; }
    log_warning() { echo "WARNING: $1" >&2; }
    log_error() { echo "ERROR: $1" >&2; }
fi

# =========================================================================
# Function: Check for required command-line tools
# Arguments: None
# Returns: 0 if all essential tools are found, 1 otherwise
# =========================================================================
check_system_tools() {
    local missing_tools=0
    local tools_to_check=("docker" "git") # Essential tools
    local optional_tools=("dialog") # Optional tools

    log_info "Checking for essential system tools..."
    for tool in "${tools_to_check[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Essential tool '$tool' is not installed or not in PATH."
            missing_tools=1
        else
            log_info " -> Found: $tool"
        fi
    done

    log_info "Checking for optional system tools..."
    for tool in "${optional_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_warning "Optional tool '$tool' is not installed. Some UI features might be disabled."
            # Set an environment variable to indicate dialog is missing
            export DIALOG_MISSING=true
        else
            log_info " -> Found: $tool"
            export DIALOG_MISSING=false
        fi
    done

    if [ $missing_tools -ne 0 ]; then
        log_error "One or more essential tools are missing. Please install them and try again."
        return 1
    fi

    # Check Docker daemon status
    log_info "Checking Docker daemon status..."
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker daemon is not running or inaccessible. Please start Docker."
        # Attempt to start Docker if possible (requires sudo/permissions)
        # if command -v systemctl &> /dev/null; then
        #     log_info "Attempting to start Docker service via systemctl..."
        #     sudo systemctl start docker
        #     sleep 5 # Give it time to start
        #     if ! docker info > /dev/null 2>&1; then
        #         log_error "Failed to start Docker service."
        #         return 1
        #     fi
        # else
             return 1 # Cannot automatically start
        # fi
    else
        log_info " -> Docker daemon is running."
    fi

    # Check for Docker Buildx plugin
    log_info "Checking for Docker Buildx plugin..."
    if ! docker buildx version &> /dev/null; then
        log_error "Docker Buildx plugin is not available. Please install or enable it."
        # Instructions or link to docs could be added here.
        return 1
    else
        log_info " -> Docker Buildx plugin found."
    fi

    log_success "All essential system checks passed."
    return 0
}

# --- Main Execution (if run directly) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_system_tools
    exit $?
fi

# --- Footer ---
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── system_checks.sh   <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Checks for essential system tools (docker, buildx, git) and optional tools (dialog). Verifies Docker daemon status.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-100500-SYSCHECKS
