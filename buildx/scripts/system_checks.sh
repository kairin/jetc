#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/system_checks.sh

# =========================================================================
# System Checks Script
# Responsibility: Check for required system tools.
# =========================================================================

# Source logging functions if available (assuming env_setup.sh was sourced by caller)
if declare -f log_info > /dev/null; then
    : # Functions already loaded
else
    # Basic fallback logging if not sourced
    log_info() { echo "INFO: $1"; }
    log_warning() { echo "WARNING: $1" >&2; }
    log_error() { echo "ERROR: $1" >&2; }
fi

# --- Check Functions ---
check_command() {
    local cmd="$1"
    local critical=${2:-false} # Is this command critical?
    local package_name=${3:-$cmd} # Package name for installation hint

    log_info "Checking for command: $cmd..."
    if command -v "$cmd" &> /dev/null; then
        log_info " -> Found: $(command -v "$cmd")"
        return 0
    else
        if [[ "$critical" == "true" ]]; then
            log_error " -> Command '$cmd' not found. This is required."
            log_error "    Please install '$package_name' (e.g., using 'sudo apt update && sudo apt install $package_name') and try again."
            return 1
        else
            log_warning " -> Command '$cmd' not found. Some features might be unavailable (e.g., interactive UI)."
            log_warning "    Consider installing '$package_name' for the best experience."
            return 0 # Non-critical, allow script to continue
        fi
    fi
}

check_docker_buildx() {
    log_info "Checking for Docker Buildx plugin..."
    if docker buildx version &> /dev/null; then
        log_info " -> Found: $(docker buildx version | head -n 1)"
        return 0
    else
        log_error " -> Docker Buildx plugin not found or not working."
        log_error "    Buildx is required. Ensure Docker is installed correctly and buildx is enabled."
        log_error "    See: https://docs.docker.com/build/buildx/install/"
        return 1
    fi
}

# --- Perform Checks ---
log_info "Performing system checks..."

all_checks_passed=true

check_command "docker" true || all_checks_passed=false
if [[ "$all_checks_passed" == "true" ]]; then
    # Only check buildx if docker command exists
    check_docker_buildx || all_checks_passed=false
fi
check_command "dialog" false "dialog" # Not critical, provides better UI
check_command "git" true || all_checks_passed=false

# --- Final Result ---
if [[ "$all_checks_passed" == "true" ]]; then
    log_info "System checks passed."
    exit 0
else
    log_error "One or more critical system checks failed. Please install the missing tools."
    exit 1
fi

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── system_checks.sh   <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Checks for essential system tools (docker, buildx, dialog, git) required by the build system.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-090500-SYSCHK
