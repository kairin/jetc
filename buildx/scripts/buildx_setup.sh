#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/buildx_setup.sh

# =========================================================================
# Docker Buildx Setup Script
# Responsibility: Ensure the specified Buildx builder instance exists and is used.
# =========================================================================

# --- Dependencies ---
SCRIPT_DIR_BUILDX_SETUP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source required scripts (use fallbacks if sourcing fails)
# Need logging functions and BUILDER_NAME from env_setup.sh
if [ -f "$SCRIPT_DIR_BUILDX_SETUP/env_setup.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_BUILDX_SETUP/env_setup.sh"
else
    # Basic fallbacks if env_setup is missing
    echo "Warning: env_setup.sh not found. Logging/colors may be basic." >&2
    log_info() { echo "INFO: $1"; }
    log_warning() { echo "WARNING: $1" >&2; }
    log_error() { echo "ERROR: $1" >&2; }
    log_success() { echo "SUCCESS: $1"; }
    BUILDER_NAME="jetson-builder" # Fallback builder name
fi

# --- Functions ---

# Check if the specified builder instance exists
# Input: $1 = builder_name
# Return: 0 if exists, 1 otherwise
check_builder_exists() {
    local builder_name="$1"
    if [ -z "$builder_name" ]; then
        log_error "check_builder_exists: No builder name provided."
        return 1
    fi
    log_debug "Checking if builder '$builder_name' exists..."
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
    if [ -z "$builder_name" ]; then
        log_error "create_builder_if_not_exists: No builder name provided."
        return 1
    fi

    if check_builder_exists "$builder_name"; then
        log_info "Buildx builder '$builder_name' already exists."
        return 0
    fi

    log_info "Buildx builder '$builder_name' not found. Attempting to create..."
    # Create the builder, bootstrap it, and set it as the current builder
    if docker buildx create --name "$builder_name" --driver docker-container --use --bootstrap; then
        log_success " -> Successfully created and selected builder '$builder_name'."
        # Verify creation
        if check_builder_exists "$builder_name"; then
            return 0
        else
            log_error " -> Builder '$builder_name' creation reported success, but inspection failed."
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
    if [ -z "$builder_name" ]; then
        log_error "use_builder: No builder name provided."
        return 1
    fi

    log_debug "Ensuring builder '$builder_name' is in use..."
    if docker buildx use "$builder_name"; then
        log_debug " -> Switched to builder '$builder_name'."
        return 0
    else
        log_error " -> Failed to switch to builder '$builder_name'."
        return 1
    fi
}

# --- Main Setup Function ---

# Orchestrates the setup: create if needed, then ensure it's used.
# Uses BUILDER_NAME from environment (loaded by env_setup.sh)
# Return: 0 on success, 1 on failure
setup_buildx() {
    log_info "--- Setting up Docker Buildx ---"
    if [ -z "$BUILDER_NAME" ]; then
        log_error "BUILDER_NAME environment variable is not set. Cannot setup buildx."
        return 1
    fi

    log_info "Target builder instance: '$BUILDER_NAME'"

    # Create the builder if it doesn't exist
    if ! create_builder_if_not_exists "$BUILDER_NAME"; then
        log_error "Buildx setup failed: Could not ensure builder '$BUILDER_NAME' exists."
        return 1
    fi

    # Ensure the builder is selected for use (create might select it, but 'use' is idempotent)
    if ! use_builder "$BUILDER_NAME"; then
        log_error "Buildx setup failed: Could not switch to builder '$BUILDER_NAME'."
        return 1
    fi

    log_success "--- Docker Buildx setup complete. Using builder: '$BUILDER_NAME' ---"
    return 0
}

# --- Main Execution (for testing) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_info "Running buildx_setup.sh directly for testing..."
    # Example: Force creation/check of a test builder
    export BUILDER_NAME="test-builder-$$"
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
    exit $setup_status
fi


# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── buildx_setup.sh    <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Ensures the specified Docker Buildx builder instance exists and is used. Relies on BUILDER_NAME from .env.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-100500-BUILDXSETUP
