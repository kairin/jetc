#!/bin/bash

# Canonical .env helpers for Jetson Container build system

SCRIPT_DIR_ENV="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_CANONICAL="$(cd "$SCRIPT_DIR_ENV/.." && pwd)/.env"

# =========================================================================
# Function: Update .env file with new values, with backup if no new input
# Arguments: 1: Username, 2: Registry, 3: Prefix, 4: Base Image Tag
# =========================================================================
update_env_file() {
    # Backup .env before making changes
    if [ -f "$ENV_CANONICAL" ]; then
        cp "$ENV_CANONICAL" "$ENV_CANONICAL.bak.$(date +%Y%m%d-%H%M%S)"
    fi

    # Read the current .env file
    if [ -f "$ENV_CANONICAL" ]; then
        # Only export safe lines for update
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
            [[ "$key" =~ ";" ]] && continue
            if [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
                export "$key=$value"
            fi
        done < <(grep -v '^#' "$ENV_CANONICAL" | grep '=')
    fi

    # Update the values if provided, else keep previous
    DOCKER_USERNAME="${1:-$DOCKER_USERNAME}"
    DOCKER_REGISTRY="${2:-$DOCKER_REGISTRY}"
    DOCKER_REPO_PREFIX="${3:-$DOCKER_REPO_PREFIX}"
    DEFAULT_BASE_IMAGE="${4:-$DEFAULT_BASE_IMAGE}"

    # Write the updated values back to the .env file
    temp_file=$(mktemp)
    trap 'rm -f "$temp_file"' EXIT

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
        # Only export lines that are safe VAR=VALUE (no semicolons, no spaces around =, not commented)
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
            # Skip lines with semicolons in key (not a valid var)
            [[ "$key" =~ ";" ]] && continue
            # Only allow safe variable names
            if [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
                export "$key=$value"
            fi
        done < <(grep -v '^#' "$ENV_CANONICAL" | grep '=')
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
# Description: .env file helpers for Jetson Container build system (update/load, safe parsing, backup).
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20240805-220000-ENVSAFE
