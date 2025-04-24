#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/system_checks.sh

# =========================================================================
# System Checks Script
# Responsibility: Verify essential system tools are installed.
# =========================================================================

SCRIPT_DIR_SYS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR_SYS/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# shellcheck disable=SC1091
# SOURCE THE CORRECT LOGGING SCRIPT
source "$SCRIPT_DIR_SYS/env_setup.sh" || { echo "Error: env_setup.sh not found."; exit 1; }

# =========================================================================
# Function: Check if required dependencies are installed
# Arguments: $@ = List of command names to check
# Returns: 0 if all commands exist, 1 if any are missing
# =========================================================================
check_dependencies() {
    local missing=0

    # Use log_info from env_setup.sh
    log_info "Checking dependencies: $*"

    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            # Use log_error from env_setup.sh
            log_error "Required dependency '$cmd' is not installed."
            missing=1
        else
            log_debug "Dependency '$cmd' found: $(command -v "$cmd")"
        fi
    done

    if [[ $missing -eq 1 ]]; then
        # Use log_error from env_setup.sh
        log_error "Please install missing dependencies before continuing."
        return 1
    fi

    # Use log_success from env_setup.sh
    log_success "All dependencies verified."
    return 0
}

# =========================================================================
# Function: Check for required command-line tools (uses internal logging names for clarity)
# Arguments: None
# Returns: 0 if all essential tools are found, 1 otherwise
# =========================================================================
check_system_tools() {
    local missing_tools=0
    local tools_to_check=("docker" "git") # Essential tools
    local optional_tools=("dialog") # Optional tools

    log_info "Checking for essential system tools..." # Use log_info
    for tool in "${tools_to_check[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Essential tool '$tool' is not installed or not in PATH." # Use log_error
            missing_tools=1
        else
            log_info " -> Found: $tool" # Use log_info
        fi
    done

    log_info "Checking for optional system tools..." # Use log_info
    for tool in "${optional_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_warning "Optional tool '$tool' is not installed. Some UI features might be disabled." # Use log_warning
            # Set an environment variable to indicate dialog is missing
            export DIALOG_MISSING=true
        else
            log_info " -> Found: $tool" # Use log_info
            export DIALOG_MISSING=false
        fi
    done

    if [ $missing_tools -ne 0 ]; then
        log_error "One or more essential tools are missing. Please install them and try again." # Use log_error
        return 1
    fi

    # Check Docker daemon status
    log_info "Checking Docker daemon status..." # Use log_info
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker daemon is not running or inaccessible. Please start Docker." # Use log_error
        # Attempt to start Docker if possible (requires sudo/permissions)
        # ... (commented auto-start logic remains the same) ...
             return 1 # Cannot automatically start
    else
        log_info " -> Docker daemon is running." # Use log_info
    fi

    # Check for Docker Buildx plugin
    log_info "Checking for Docker Buildx plugin..." # Use log_info
    if ! docker buildx version &> /dev/null; then
        log_error "Docker Buildx plugin is not available. Please install or enable it." # Use log_error
        # Instructions or link to docs could be added here.
        return 1
    else
        log_info " -> Docker Buildx plugin found." # Use log_info
    fi

    log_success "All essential system checks passed." # Use log_success
    return 0
}

# =========================================================================
# Function: Clean up resources on script exit
# Arguments: None
# Returns: 0 (always successful)
# =========================================================================
cleanup() {
    log_debug "Running cleanup function"

    # Remove temporary files if they exist
    if [[ -f "/tmp/build_prefs.sh" ]]; then
        log_debug "Removing temporary build preferences file /tmp/build_prefs.sh"
        rm -f "/tmp/build_prefs.sh"
    fi

    # Add cleanup for other potential temp files created by dialog/interactive_ui
    log_debug "Removing potential interactive_ui temp files..."
    rm -f /tmp/dialog_* # Example pattern, adjust if needed

    # Additional cleanup tasks can be added here

    log_debug "Cleanup completed"
    return 0
}

# =========================================================================
# Function: Handle build error
# Arguments: $1 = folder path, $2 = exit status
# Returns: 0 (always successful to allow build continuation)
# =========================================================================
handle_build_error() {
    local folder_path="$1"
    local exit_status="$2"

    local folder_name=$(basename "$folder_path")

    log_error "==================================================" # Use log_error
    log_error "ERROR: Build failed for stage: $folder_name" # Use log_error
    log_error "Exit status: $exit_status" # Use log_error
    log_error "==================================================" # Use log_error

    # Log the error (already done by log_error)
    # log_error "Build failed for $folder_name with exit code $exit_status" "$ERROR_LOG"

    return 0
}

# --- Main Execution (if run directly) ---\
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Need to initialize logging if run directly
    init_logging # Call with defaults
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
# Description: Performs system checks required for the build process.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250425-080000-42595D
