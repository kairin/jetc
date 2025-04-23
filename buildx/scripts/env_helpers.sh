#!/bin/bash

# Canonical .env helpers for Jetson Container build system

SCRIPT_DIR_ENV="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_CANONICAL="$(cd "$SCRIPT_DIR_ENV/.." && pwd)/.env"

# =========================================================================
# Function: Update .env file with new values
# Arguments: 1: Username, 2: Registry, 3: Prefix, 4: Base Image Tag
# =========================================================================
update_env_file() {
    # Read the current .env file
    if [ -f "$ENV_CANONICAL" ]; then
        source "$ENV_CANONICAL"
    fi

    # Update the values
    DOCKER_USERNAME="$1"
    DOCKER_REGISTRY="$2"
    DOCKER_REPO_PREFIX="$3"
    DEFAULT_BASE_IMAGE="$4"

    # Write the updated values back to the .env file
    temp_file=$(mktemp)
    trap 'rm -f "$temp_file"' EXIT

    # Preserve comments and update values
    while IFS= read -r line; do
        case "$line" in
            DOCKER_USERNAME=*) echo "DOCKER_USERNAME=$DOCKER_USERNAME" ;;
            DOCKER_REGISTRY=*) echo "DOCKER_REGISTRY=$DOCKER_REGISTRY" ;;
            DOCKER_REPO_PREFIX=*) echo "DOCKER_REPO_PREFIX=$DOCKER_REPO_PREFIX" ;;
            DEFAULT_BASE_IMAGE=*) echo "DEFAULT_BASE_IMAGE=$DEFAULT_BASE_IMAGE" ;;
            *) echo "$line" ;;
        esac
    done < "$ENV_CANONICAL" > "$temp_file"

    mv "$temp_file" "$ENV_CANONICAL"
}

# =========================================================================
# Function: Load environment variables from .env file
# Exports: DOCKER_USERNAME, DOCKER_REGISTRY, DOCKER_REPO_PREFIX, DEFAULT_BASE_IMAGE, AVAILABLE_IMAGES etc.
# Returns: 0 (always succeeds, variables might be empty if file not found)
# =========================================================================
load_env_variables() {
    if [ -f "$ENV_CANONICAL" ]; then
        export $(grep -v '^#' "$ENV_CANONICAL" | xargs)
    fi
    # Always set defaults if missing
    DOCKER_USERNAME=${DOCKER_USERNAME:-}
    DOCKER_REGISTRY=${DOCKER_REGISTRY:-}
    DOCKER_REPO_PREFIX=${DOCKER_REPO_PREFIX:-}
    DEFAULT_BASE_IMAGE=${DEFAULT_BASE_IMAGE:-"nvcr.io/nvidia/l4t-pytorch:r35.4.1-py3"}
    export DOCKER_USERNAME DOCKER_REGISTRY DOCKER_REPO_PREFIX DEFAULT_BASE_IMAGE
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
# COMMIT-TRACKING: UUID-20250423-232231-ENVH
