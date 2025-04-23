#!/bin/bash

# Canonical .env helpers for Jetson Container build system

SCRIPT_DIR_ENV="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_CANONICAL="$(cd "$SCRIPT_DIR_ENV/.." && pwd)/.env"

# =========================================================================
# Function: Update .env file with new values
# Arguments: 1: Username, 2: Registry, 3: Prefix, 4: Base Image Tag
# =========================================================================
update_env_file() {
    local new_username="$1"
    local new_registry="$2"
    local new_prefix="$3"
    local new_base_image="$4"
    local env_file="$ENV_CANONICAL"
    # ...existing code from build_ui.sh update_env_file...
}

# =========================================================================
# Function: Load environment variables from .env file
# Exports: DOCKER_USERNAME, DOCKER_REGISTRY, DOCKER_REPO_PREFIX, DEFAULT_BASE_IMAGE, AVAILABLE_IMAGES etc.
# Returns: 0 (always succeeds, variables might be empty if file not found)
# =========================================================================
load_env_variables() {
    local env_file="$ENV_CANONICAL"
    # ...existing code from build_ui.sh load_env_variables...
}

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── env_helpers.sh     <- THIS FILE
# └── ...                        <- Other project files
#
# Description: .env file helpers for Jetson Container build system (update/load).
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20240805-210500-ENVH
