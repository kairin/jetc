#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/buildx_setup.sh

# =========================================================================
# Docker Buildx Setup Script
# Responsibility: Ensure the specified Buildx builder instance exists and is used.
# Relies on logging functions sourced by the main script and BUILDER_NAME from env_setup.sh.
# =========================================================================

# --- Dependencies ---\
SCRIPT_DIR_BUILDX_SETUP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source ONLY env_setup.sh for BUILDER_NAME.
# DO NOT source logging.sh here.
if [ -f "$SCRIPT_DIR_BUILDX_SETUP/env_setup.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_BUILDX_SETUP/env_setup.sh"
else
    # Minimal fallbacks if even env_setup is missing
    echo "CRITICAL ERROR: env_setup.sh not found in buildx_setup.sh" >&2
    # Define minimal functions to prevent immediate script failure, although logging is broken.
    log_info() { echo "INFO: $1"; }
    log_warning() { echo "WARNING: $1" >&2; }
    log_error() { echo "ERROR: $1" >&2; }
    log_success() { echo "SUCCESS: $1"; }
    log_debug() { :; }
    BUILDER_NAME="jetson-builder" # Fallback
fi

# --- Functions ---\

# Check if the specified builder instance exists
# Input: $1 = builder_name
# Return: 0 if exists, 1 otherwise
check_builder_exists() {
    local builder_name="$1"
    if [ -z "$builder_name" ]; then log_error "check_builder_exists: No builder name provided."; return 1; fi
    log_debug "Checking if builder '$builder_name' exists..." # Uses global log_debug
    if docker buildx inspect "$builder_name" >/dev/null 2>&1; then
        log_debug " -> Builder '$builder_name' found."
        return 0
    else
        log_debug " -> Builder '$builder_name' not found."
        return 1
    fi
}

# Create the specified builder instance if it doesn't exist
# Input: $1 = builder_name
# Return: 0 on success or if already exists, 1 on failure to create
create_builder_if_not_exists() {
    local builder_name="$1"
    if [ -z "$builder_name" ]; then log_error "create_builder_if_not_exists: No builder name provided."; return 1; fi

    if check_builder_exists "$builder_name"; then
        log_info "Buildx builder '$builder_name' already exists." # Uses global log_info
        return 0
    fi

    log_info "Buildx builder '$builder_name' not found. Attempting to create..."
    if docker buildx create --name "$builder_name" --driver docker-container --use --bootstrap; then
        log_success " -> Successfully created and selected builder '$builder_name'." # Uses global log_success
        # Verify creation just in case
        if check_builder_exists "$builder_name"; then
            return 0
        else
            log_error " -> Builder '$builder_name' creation reported success, but inspection failed." # Uses global log_error
            return 1
        fi
    else
        log_error " -> Failed to create builder '$builder_name'."
        log_error "    Check Docker daemon status and buildx installation."
        return 1
    fi
}

# Ensure the specified builder is the current one being used
# Input: $1 = builder_name
# Return: 0 on success, 1 on failure
use_builder() {
    local builder_name="$1"
    if [ -z "$builder_name" ]; then log_error "use_builder: No builder name provided."; return 1; fi

    log_debug "Ensuring builder '$builder_name' is in use..."
    if docker buildx use "$builder_name"; then
        log_debug " -> Switched to builder '$builder_name'."
        return 0
    else
        log_error " -> Failed to switch to builder '$builder_name'."
        return 1
    fi
}

# --- Main Setup Function ---\

# Orchestrates the setup: create if needed, then ensure it's used.
# Uses BUILDER_NAME from environment (loaded by env_setup.sh)
# Return: 0 on success, 1 on failure
setup_buildx() {
    log_info "--- Setting up Docker Buildx ---"
    # BUILDER_NAME should be available from sourced env_setup.sh
    if [ -z "${BUILDER_NAME:-}" ]; then
        log_error "BUILDER_NAME environment variable is not set. Cannot setup buildx."
        return 1
    fi

    log_info "Target builder instance: '$BUILDER_NAME'"

    if ! create_builder_if_not_exists "$BUILDER_NAME"; then
        log_error "Buildx setup failed: Could not ensure builder '$BUILDER_NAME' exists."
        return 1
    fi

    if ! use_builder "$BUILDER_NAME"; then
        log_error "Buildx setup failed: Could not switch to builder '$BUILDER_NAME'."
        return 1
    fi

    log_success "--- Docker Buildx setup complete. Using builder: '$BUILDER_NAME' ---"
    return 0
}

# --- Main Execution (for testing) ---\
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # If testing directly, source logging.sh first
    if [ -f "$SCRIPT_DIR_BUILDX_SETUP/logging.sh" ]; then source "$SCRIPT_DIR_BUILDX_SETUP/logging.sh"; init_logging; else echo "ERROR: Cannot find logging.sh for test."; exit 1; fi
    log_info "Running buildx_setup.sh directly for testing..."
    # Example: Force creation/check of a test builder
    export BUILDER_NAME="test-builder-$RANDOM" # Use RANDOM for uniqueness
    log_info "Using test builder name: $BUILDER_NAME"
    setup_buildx
    setup_status=$?
    if [ $setup_status -eq 0 ]; then
        log_success "Test setup successful."
        log_info "Cleaning up test builder '$BUILDER_NAME'..."
        docker buildx rm "$BUILDER_NAME" || log_warning "Failed to remove test builder."
    else
        log_error "Test setup failed."
    fi
    log_info "Buildx setup test finished."
    exit $setup_status
fi

# --- Footer ---
# Description: Ensures the specified Docker Buildx builder exists and is used. Relies on logging.sh and env_setup.sh sourced by caller.
# COMMIT-TRACKING: UUID-20250424-205555-LOGGINGREFACTOR
