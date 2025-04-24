#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/buildx_setup.sh

# =========================================================================
# Docker Buildx Setup Script
# Responsibility: Ensure the Docker buildx builder instance is set up and ready.
# =========================================================================

# Source logging functions if available (assuming env_setup.sh was sourced by caller)
if declare -f log_info > /dev/null; then
    :
else
    # Basic fallback logging if not sourced
    log_info() { echo "INFO: $1"; }
    log_warning() { echo "WARNING: $1" >&2; }
    log_error() { echo "ERROR: $1" >&2; }
    log_success() { echo "SUCCESS: $1"; }
fi

# --- Configuration ---
# Default builder name, can be overridden by environment variable
DEFAULT_BUILDER_NAME="jetson-builder"
BUILDER_NAME="${BUILDER_NAME:-$DEFAULT_BUILDER_NAME}"

# --- Functions ---

# Check if the specified builder instance exists
check_builder_exists() {
    local builder_to_check="$1"
    log_info "Checking if buildx builder '$builder_to_check' exists..."
    if docker buildx inspect "$builder_to_check" >/dev/null 2>&1; then
        log_info " -> Builder '$builder_to_check' found."
        return 0 # Exists
    else
        log_info " -> Builder '$builder_to_check' not found."
        return 1 # Does not exist
    fi
}

# Create the buildx builder instance
create_builder() {
    local builder_to_create="$1"
    log_info "Creating buildx builder '$builder_to_create'..."
    # Use --driver docker-container for better isolation and features
    # Use --platform linux/arm64,linux/amd64 to support cross-building if needed, adjust as necessary
    # For Jetson-specific builds, linux/arm64 might be sufficient
    if docker buildx create --name "$builder_to_create" --driver docker-container --use --platform linux/arm64; then
        log_success " -> Successfully created and selected builder '$builder_to_create'."
        return 0
    else
        log_error " -> Failed to create buildx builder '$builder_to_create'."
        log_error "    Check Docker daemon status and permissions."
        return 1
    fi
}

# Ensure the specified builder is the one being used
use_builder() {
    local builder_to_use="$1"
    log_info "Ensuring buildx builder '$builder_to_use' is selected..."
    if docker buildx use "$builder_to_use"; then
        log_info " -> Builder '$builder_to_use' is now the current builder."
        return 0
    else
        log_error " -> Failed to select builder '$builder_to_use'."
        return 1
    fi
}

# Main setup function
setup_buildx_builder() {
    log_info "Setting up Docker Buildx builder: $BUILDER_NAME"

    if ! check_builder_exists "$BUILDER_NAME"; then
        # Builder doesn't exist, try to create it
        if ! create_builder "$BUILDER_NAME"; then
            log_error "Buildx setup failed: Could not create builder."
            return 1
        fi
        # create_builder already selects it, so we are done
    else
        # Builder exists, ensure it's selected
        if ! use_builder "$BUILDER_NAME"; then
            log_error "Buildx setup failed: Could not select existing builder."
            return 1
        fi
    fi

    log_success "Buildx setup complete. Using builder: $BUILDER_NAME"
    return 0
}

# --- Main Execution (if script is run directly) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_buildx_builder
    exit $?
fi

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── buildx_setup.sh    <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Checks for, creates (if needed), and selects the Docker Buildx builder instance.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-091000-BLDXSTP
