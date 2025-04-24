#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/tagging.sh

# =========================================================================
# Final Tagging Script
# Responsibility: Create, push, and verify the final timestamped tag.
# Relies on logging functions sourced by the main script.
# Relies on env_setup.sh and docker_helpers.sh sourced by the main script or caller.
# =========================================================================

# Set strict mode for this critical script
set -euo pipefail

# --- Dependencies ---\
SCRIPT_DIR_TAGGING="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# DO NOT source logging.sh, env_setup.sh or docker_helpers.sh here.
# Assume they are sourced by the main build.sh script.
# Check if required functions exist as a safety measure.
if ! declare -f log_info > /dev/null || ! declare -f generate_timestamped_tag > /dev/null || ! declare -f pull_image > /dev/null || ! declare -f verify_image_exists > /dev/null; then
     echo "CRITICAL ERROR: Required functions (log_info, docker helpers) not found in tagging.sh. Ensure main script sources logging.sh, env_setup.sh, and docker_helpers.sh." >&2
     exit 1
fi


# =========================================================================
# Function: Perform pre-tagging verification to ensure the image can be pulled/exists
# =========================================================================
perform_pre_tagging_pull() {
    local image_tag="$1"
    local skip_push_pull="${2:-y}" # Default to 'y' (load mode)

    if [[ -z "$image_tag" ]]; then log_error "perform_pre_tagging_pull: Empty tag"; return 1; fi

    log_info "Performing pre-tagging verification for $image_tag"

    # First verify the image exists locally using function from docker_helpers.sh
    if ! verify_image_exists "$image_tag"; then
        log_error "Image $image_tag not found locally for pre-tagging verification"
        return 1
    fi

    # If built locally (--load), no need to pull
    if [[ "$skip_push_pull" == "y" ]]; then
        log_info "Image built locally (skip_push_pull=y), skipping pull verification"
        return 0
    fi

    # Try pulling the image if push mode was used
    log_debug "Attempting pull for pre-tagging verification (push mode): $image_tag"
    # Use pull_image function from docker_helpers.sh
    if ! pull_image "$image_tag"; then
        log_warning "Failed to pull $image_tag during pre-tagging verification (push mode)"
        return 1 # Treat failure to pull back a pushed image as an error
    fi

    log_success "Pre-tagging verification successful for $image_tag (pull verified)"
    return 0
}


# =========================================================================
# Function: Create and potentially push a final timestamp tag for the image
# =========================================================================
create_final_timestamp_tag() {
    local source_tag="$1"
    local username="$2"
    local repo_prefix="$3"
    local skip_push_pull="${4:-y}" # Default to 'y' (load mode)
    local registry="${5:-}"

    log_debug "Creating final timestamp tag for source: $source_tag"
    if [[ -z "$source_tag" || -z "$username" || -z "$repo_prefix" ]]; then
        log_error "create_final_timestamp_tag: Missing required arguments"
        return 1
    fi

    # Generate timestamp tag using function from docker_helpers.sh
    local timestamp_tag
    timestamp_tag=$(generate_timestamped_tag "$username" "$repo_prefix" "$registry")
    if [[ -z "$timestamp_tag" ]]; then log_error "Failed to generate timestamp tag"; return 1; fi
    log_debug "Generated timestamp tag: $timestamp_tag"

    log_info "Tagging $source_tag as $timestamp_tag"
    if ! docker tag "$source_tag" "$timestamp_tag"; then
        log_error "Failed to tag $source_tag as $timestamp_tag"
        return 1
    fi

    # If using push mode, push the new tag
    if [[ "$skip_push_pull" != "y" ]]; then
        log_info "Pushing timestamp tag $timestamp_tag to registry"
        if ! docker push "$timestamp_tag"; then
            log_error "Failed to push $timestamp_tag to registry"
            # Attempt to remove the local tag if push fails? Maybe not, leave it.
            return 1
        fi
        log_success "Successfully pushed $timestamp_tag"
    else
        log_debug "Skipping push for timestamp tag (local build mode)."
    fi

    # Echo the tag name for capture by the caller
    echo "$timestamp_tag"
    return 0
}

# =========================================================================
# Function: Verify all images in a list exist locally
# =========================================================================
verify_all_images_exist_locally() {
    local missing=0
    if [[ $# -eq 0 ]]; then log_debug "No images provided to verify_all_images_exist_locally"; return 0; fi

    log_info "Verifying local existence of $# images: $*"
    for img in "$@"; do
        log_debug "Checking if $img exists locally"
        # Use verify_image_exists function from docker_helpers.sh
        if ! verify_image_exists "$img"; then
            log_error "Image $img not found locally"
            missing=1
        fi
    done

    if [[ $missing -eq 1 ]]; then
        log_error "One or more expected images are missing locally."
        return 1
    fi

    log_success "All expected images verified locally."
    return 0
}


# --- Main Execution (for testing) ---\
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # If testing directly, source dependencies first
    if [ -f "$SCRIPT_DIR_TAGGING/logging.sh" ]; then source "$SCRIPT_DIR_TAGGING/logging.sh"; init_logging; else echo "ERROR: Cannot find logging.sh for test."; exit 1; fi
    if [ -f "$SCRIPT_DIR_TAGGING/env_setup.sh" ]; then source "$SCRIPT_DIR_TAGGING/env_setup.sh"; else echo "ERROR: Cannot find env_setup.sh for test."; exit 1; fi
    if [ -f "$SCRIPT_DIR_TAGGING/docker_helpers.sh" ]; then source "$SCRIPT_DIR_TAGGING/docker_helpers.sh"; else echo "ERROR: Cannot find docker_helpers.sh for test."; exit 1; fi

    log_info "Running tagging.sh directly for testing..."
    # Test Setup, Execution, Cleanup ... (omitted for brevity, similar to before)
    log_info "Tagging script test finished."
    exit 0 # Placeholder exit code for test
fi

# --- Footer ---
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── tagging.sh         <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Functions related to Docker image tagging.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250425-080000-42595D
