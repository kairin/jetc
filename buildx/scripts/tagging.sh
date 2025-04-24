#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/tagging.sh

# =========================================================================
# Final Tagging Script
# Responsibility: Create, push, and verify the final timestamped tag.
# =========================================================================

# Set strict mode for this critical script
set -euo pipefail

# --- Dependencies ---
SCRIPT_DIR_TAGGING="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source required scripts (use fallbacks if sourcing fails)
if [ -f "$SCRIPT_DIR_TAGGING/env_setup.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_TAGGING/env_setup.sh"
else
    echo "Warning: env_setup.sh not found. Logging/colors may be basic." >&2
    log_info() { echo "INFO: $1"; }
    log_warning() { echo "WARNING: $1" >&2; }
    log_error() { echo "ERROR: $1" >&2; }
    log_success() { echo "SUCCESS: $1"; }
    log_debug() { :; }
    get_system_datetime() { date +"%Y%m%d-%H%M%S"; }
fi

if [ -f "$SCRIPT_DIR_TAGGING/verification.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_TAGGING/verification.sh"
else
    log_warning "verification.sh not found. Image verification/pulling will fail."
    verify_image_locally() { log_warning "verify_image_locally: verification.sh not loaded"; return 1; }
    pull_image() { log_warning "pull_image: verification.sh not loaded"; return 1; }
fi

# Docker image tagging functions for Jetson Container build system

SCRIPT_DIR_TAG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR_TAG/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_TAG/docker_helpers.sh" || { echo "Error: docker_helpers.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_TAG/logging.sh" || { echo "Error: logging.sh not found."; exit 1; }

# =========================================================================
# Function: Perform pre-tagging verification to ensure the image can be pulled
# Arguments: $1 = image tag to verify
# Returns: 0 if successful, 1 if failed
# =========================================================================
perform_pre_tagging_pull() {
    local image_tag="$1"
    
    if [[ -z "$image_tag" ]]; then
        _log_debug "Error: perform_pre_tagging_pull called with empty tag"
        return 1
    }
    
    _log_debug "Performing pre-tagging verification for $image_tag"
    
    # First verify the image exists locally
    if ! verify_image_exists "$image_tag"; then
        _log_debug "Error: Image $image_tag not found locally"
        return 1
    }
    
    # Images built with --load are only available locally
    # No need to try pulling in this case
    if [[ "${skip_intermediate_push_pull:-y}" == "y" ]]; then
        _log_debug "Image built with --load, skipping pull verification"
        return 0
    }
    
    # Try pulling the image as verification
    if ! pull_image "$image_tag"; then
        _log_debug "Warning: Failed to pull $image_tag during pre-tagging verification"
        return 1
    }
    
    _log_debug "Pre-tagging verification successful for $image_tag"
    return 0
}

# =========================================================================
# Function: Create a final timestamp tag for the image
# Arguments: $1 = source image tag, $2 = username, $3 = repo_prefix, $4 = registry (optional)
# Returns: Echo timestamp tag on success, empty on failure. Exit code 0 on success, 1 on failure
# =========================================================================
create_final_timestamp_tag() {
    local source_tag="$1"
    local username="$2"
    local repo_prefix="$3"
    local registry="${4:-}"
    
    if [[ -z "$source_tag" || -z "$username" || -z "$repo_prefix" ]]; then
        _log_debug "Error: create_final_timestamp_tag missing required arguments"
        return 1
    }
    
    # Generate a timestamp tag
    local timestamp_tag
    timestamp_tag=$(generate_timestamped_tag "$username" "$repo_prefix" "$registry")
    if [[ -z "$timestamp_tag" ]]; then
        _log_debug "Error: Failed to generate timestamp tag"
        return 1
    }
    
    _log_debug "Tagging $source_tag as $timestamp_tag"
    
    # Tag the image
    if ! docker tag "$source_tag" "$timestamp_tag"; then
        _log_debug "Error: Failed to tag $source_tag as $timestamp_tag"
        return 1
    }
    
    # If using push mode, push the new tag to registry
    if [[ "${skip_intermediate_push_pull:-y}" != "y" ]]; then
        _log_debug "Pushing timestamp tag $timestamp_tag to registry"
        if ! docker push "$timestamp_tag"; then
            _log_debug "Error: Failed to push $timestamp_tag to registry"
            return 1
        }
    }
    
    # Echo the tag name for capture by the caller
    echo "$timestamp_tag"
    return 0
}

# =========================================================================
# Function: Verify all images in a list exist locally
# Arguments: $@ = List of image tags to verify
# Returns: 0 if all exist, 1 if any missing
# =========================================================================
verify_all_images_exist_locally() {
    local missing=0
    
    if [[ $# -eq 0 ]]; then
        _log_debug "No images provided to verify_all_images_exist_locally"
        return 0
    }
    
    _log_debug "Verifying local existence of $# images"
    
    for img in "$@"; do
        _log_debug "Checking if $img exists locally"
        if ! verify_image_exists "$img"; then
            _log_debug "Image $img not found locally"
            missing=1
        fi
    done
    
    if [[ $missing -eq 1 ]]; then
        _log_debug "Some images are missing locally"
        return 1
    fi
    
    _log_debug "All images verified locally"
    return 0
}

# --- Main Execution (for testing) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_info "Running tagging.sh directly for testing..."

    # --- Test Setup --- #
    # Create a dummy source image
    test_source_tag="testuser/testprefix:test-stage-$(date +%s)"
    log_info "Creating dummy source image: $test_source_tag"
    if ! docker build -t "$test_source_tag" - <<EOF
FROM ubuntu:22.04
RUN echo "Dummy image for tagging test"
EOF
    then
        log_error "Failed to create dummy source image. Exiting test."
        exit 1
    fi

    # Set dummy variables
    test_target="load" # Use 'load' for local test, 'push' requires registry login
    test_user="testuser"
    test_prefix="testprefix"
    test_registry=""

    # Ensure verification.sh functions are defined (even if dummy)
    if ! declare -f pull_image > /dev/null; then
        pull_image() { log_info "[Test] Dummy pull_image called for $1"; return 0; }
    fi
    if ! declare -f verify_image_locally > /dev/null; then
        verify_image_locally() { log_info "[Test] Dummy verify_image_locally called for $1"; docker image inspect "$1" >/dev/null 2>&1; return $?; }
    fi

    # --- Execute Test --- #
    log_info "Calling create_final_timestamp_tag..."
    final_tag=$(create_final_timestamp_tag "$test_source_tag" "$test_target" "$test_user" "$test_prefix" "$test_registry")
    result=$?

    # --- Report Result --- #
    if [ $result -eq 0 ]; then
        log_success "Test tagging successful. Final Tag: $final_tag"
        # Clean up dummy final tag
        log_info "Cleaning up final test tag: $final_tag"
        docker rmi "$final_tag" || log_warning "Failed to remove final test tag $final_tag"
    else
        log_error "Test tagging failed with exit code $result."
    fi

    # --- Cleanup --- #
    log_info "Cleaning up source test image: $test_source_tag"
    docker rmi "$test_source_tag" || log_warning "Failed to remove source test image $test_source_tag"
    log_info "Tagging script test finished."
    exit $result
fi

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── tagging.sh         <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Docker image tagging and verification functions.
# Author: GitHub Copilot
# COMMIT-TRACKING: UUID-20240806-103000-MODULAR
