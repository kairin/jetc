#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/system_checks.sh

# =========================================================================
# System Checks Script
# Responsibility: Verify essential system tools, define cleanup and error handlers.
# Relies on logging functions sourced by the main script.
# =========================================================================

SCRIPT_DIR_SYS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source ONLY utils.sh if needed for non-logging utilities.
# DO NOT source logging.sh or env_setup.sh here.
# shellcheck disable=SC1091
source "$SCRIPT_DIR_SYS/utils.sh" || { echo "Error: utils.sh not found in system_checks.sh."; exit 1; }

# =========================================================================
# Function: Check if required dependencies are installed
# =========================================================================
check_dependencies() {
    local missing=0
    log_info "Checking dependencies: $*" # Uses global log_info
    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            log_error "Required dependency '$cmd' is not installed." # Uses global log_error
            missing=1
        else
            log_debug "Dependency '$cmd' found: $(command -v "$cmd")" # Uses global log_debug
        fi
    done
    if [[ $missing -eq 1 ]]; then
        log_error "Please install missing dependencies before continuing."
        return 1
    fi
    log_success "All dependencies verified." # Uses global log_success
    return 0
}

# =========================================================================
# Function: Check for required command-line tools
# =========================================================================
check_system_tools() {
    local missing_tools=0
    local tools_to_check=("docker" "git")
    local optional_tools=("dialog")

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

    log_info "Checking Docker daemon status..."
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker daemon is not running or inaccessible. Please start Docker."
        return 1
    else
        log_info " -> Docker daemon is running."
    fi

    log_info "Checking for Docker Buildx plugin..."
    if ! docker buildx version &> /dev/null; then
        log_error "Docker Buildx plugin is not available. Please install or enable it."
        return 1
    else
        log_info " -> Docker Buildx plugin found."
    fi

    log_success "All essential system checks passed."
    return 0
}

# =========================================================================
# Function: Clean up resources on script exit
# =========================================================================
cleanup() {
    log_debug "Running cleanup function"
    # Remove temporary files if they exist
    [[ -f "/tmp/build_prefs.sh" ]] && { log_debug "Removing /tmp/build_prefs.sh"; rm -f "/tmp/build_prefs.sh"; }
    log_debug "Removing potential interactive_ui temp files..."
    rm -f /tmp/dialog_* # Example pattern
    log_debug "Cleanup completed"
    return 0
}

# =========================================================================
# Function: Handle build error
# =========================================================================
handle_build_error() {
    local folder_path="$1"
    local exit_status="$2"
    local folder_name
    folder_name=$(basename "$folder_path")
    log_error "=================================================="
    log_error "ERROR: Build failed for stage: $folder_name"
    log_error "Exit status: $exit_status"
    log_error "=================================================="
    return 0 # Allow build continuation/summary
}

# --- Main Execution (if run directly for testing) ---\
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # If testing directly, source logging.sh first
    if [ -f "$SCRIPT_DIR_SYS/logging.sh" ]; then source "$SCRIPT_DIR_SYS/logging.sh"; init_logging; else echo "ERROR: Cannot find logging.sh for test."; exit 1; fi
    log_info "Running system_checks.sh directly for testing..."
    check_dependencies "docker" "ls" "nonexistentcmd" || log_warning "Dependency check test failed as expected."
    check_system_tools
    log_info "System checks test finished."
    exit $?
fi

# --- Footer ---
# Description: System checks, cleanup, error handling. Relies on logging.sh sourced by caller.
# COMMIT-TRACKING: UUID-20250424-205555-LOGGINGREFACTOR
