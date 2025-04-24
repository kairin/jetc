#!/bin/bash

# Set strict mode for this critical script
set -euo pipefail

# Build stage functions for Jetson Container build system

SCRIPT_DIR_BSTAGE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BSTAGE/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BSTAGE/docker_helpers.sh" || { echo "Error: docker_helpers.sh not found."; exit 1; }
# Source logging functions if available
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BSTAGE/env_setup.sh" 2>/dev/null || true

# =========================================================================
# Function: Build a single stage
# Arguments: 
#   $1: folder_path - Path to build folder
#   $2: base_image - Base image tag to use
#   $3: use_cache - Whether to use build cache (y/n)
#   $4: platform - Target platform (e.g., linux/arm64)
#   $5: use_squash - Whether to squash layers (y/n)
#   $6: skip_push_pull - Whether to skip push/pull (y/n)
#   $7: docker_username - Docker username
#   $8: docker_repo_prefix - Docker repo prefix
#   $9: docker_registry - Docker registry (optional)
# Returns: 0 on success, 1 on failure
# Exports: STAGE_OUTPUT_TAG - The tag of the built image (DEPRECATED - use fixed_tag from docker_helpers)
# =========================================================================
build_single_stage() {
    local folder_path="$1"
    local base_image="$2"
    local use_cache="${3:-n}"
    local platform="${4:-linux/arm64}"
    local use_squash="${5:-n}"
    local skip_push_pull="${6:-y}"
    local docker_username="$7"
    local docker_repo_prefix="$8"
    local docker_registry="${9:-}"
    
    local folder_name
    folder_name=$(basename "$folder_path")
    
    log_info "Building stage: $folder_name" # Use log_info
    log_debug "Base image: $base_image"
    log_debug "Build options: cache=$use_cache, platform=$platform, squash=$use_squash, skip_push=$skip_push_pull"
    log_debug "Docker creds: User=$docker_username, Prefix=$docker_repo_prefix, Registry=$docker_registry"
    
    # Set the current stage for logging context
    # Check if function exists before calling
    if command -v set_stage &> /dev/null; then
        set_stage "$folder_name"
    else
        log_debug "set_stage function not found (likely running directly)."
    fi
    
    # Check folder exists
    if [[ ! -d "$folder_path" ]]; then
        log_error "Build folder does not exist: $folder_path" # Use log_error
        return 1
    }
    
    # Check Dockerfile exists
    if [[ ! -f "$folder_path/Dockerfile" ]]; then
        log_error "Dockerfile not found in $folder_path" # Use log_error
        return 1
    }
    
    # Call build_folder_image from docker_helpers.sh
    # Disable error propagation for build_folder_image to check status manually
    set +e
    log_debug "Calling build_folder_image..."
    # build_folder_image exports 'fixed_tag' on success
    build_folder_image "$folder_path" "$use_cache" "$platform" "$use_squash" "$skip_push_pull" \
                      "$base_image" "$docker_username" "$docker_repo_prefix" "$docker_registry"
    local build_status=$?
    set -e # Re-enable exit on error
    log_debug "build_folder_image exited with status: $build_status"
    
    if [[ $build_status -ne 0 ]]; then
        log_error "Build failed for stage $folder_name" # Use log_error
        return 1
    }
    
    # fixed_tag is exported by build_folder_image
    if [[ -z "${fixed_tag:-}" ]]; then
        log_error "No output tag (fixed_tag) exported from build_folder_image for stage $folder_name" # Use log_error
        return 1
    }
    
    # Export the stage output tag (DEPRECATED - caller should use fixed_tag directly)
    # export STAGE_OUTPUT_TAG="$fixed_tag"
    log_success "Stage $folder_name built successfully: $fixed_tag" # Use log_success
    
    return 0
}

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── build_stage.sh     <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Functions for building individual Docker stages. Added logging. Relies on docker_helpers for buildx command.
# Author: GitHub Copilot
# COMMIT-TRACKING: UUID-20240806-103000-MODULAR
