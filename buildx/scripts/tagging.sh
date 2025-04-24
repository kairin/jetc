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

# Source docker_helpers for generate_timestamped_tag, pull_image, verify_image_exists
if [ -f "$SCRIPT_DIR_TAGGING/docker_helpers.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_TAGGING/docker_helpers.sh"
else
    log_error "docker_helpers.sh not found. Tagging and verification will fail."
    generate_timestamped_tag() { log_error "generate_timestamped_tag: docker_helpers.sh not loaded"; return 1; }
    pull_image() { log_error "pull_image: docker_helpers.sh not loaded"; return 1; }
    verify_image_exists() { log_error "verify_image_exists: docker_helpers.sh not loaded"; return 1; }
fi

# Source utils.sh (already sourced by env_setup.sh, but good practice for direct execution)
if [ -f "$SCRIPT_DIR_TAGGING/utils.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_TAGGING/utils.sh"
else
     log_error "utils.sh not found."
     # Define fallback if needed, though docker_helpers likely already exited
fi

# =========================================================================
# Function: Perform pre-tagging verification to ensure the image can be pulled
# Arguments: $1 = image tag to verify
#            $2 = skip_intermediate_push_pull ('y'/'n') - from build prefs
# Returns: 0 if successful, 1 if failed
# =========================================================================
perform_pre_tagging_pull() {
    local image_tag="$1"
    local skip_push_pull="${2:-y}" # Default to 'y' (load mode) if not provided

    if [[ -z "$image_tag" ]]; then
        log_error "perform_pre_tagging_pull called with empty tag" # Use log_error
        return 1
    fi # <--- CORRECTED LINE

    log_info "Performing pre-tagging verification for $image_tag" # Use log_info

    # First verify the image exists locally
    if ! verify_image_exists "$image_tag"; then
        log_error "Image $image_tag not found locally for pre-tagging verification" # Use log_error
        return 1
    fi

    # Images built with --load are only available locally
    # No need to try pulling in this case
    if [[ "$skip_push_pull" == "y" ]]; then
        log_info "Image built with --load (skip_push_pull=y), skipping pull verification" # Use log_info
        return 0
    fi # End of skip_push_pull check

    # Try pulling the image as verification if push mode was used
    log_debug "Attempting pull for pre-tagging verification (push mode): $image_tag"
    if ! pull_image "$image_tag"; then
        log_warning "Failed to pull $image_tag during pre-tagging verification (push mode)" # Use log_warning
        # Consider if this should be a fatal error (return 1) or just a warning
        # If the build pushed, but we can't pull it back, something is wrong.
        return 1
    fi

    log_success "Pre-tagging verification successful for $image_tag (pull verified)" # Use log_success
    return 0
}


# =========================================================================
# Function: Create a final timestamp tag for the image
# Arguments: $1 = source image tag
#            $2 = username
#            $3 = repo_prefix
#            $4 = skip_intermediate_push_pull ('y'/'n') - from build prefs
#            $5 = registry (optional)
# Returns: Echo timestamp tag on success, empty on failure. Exit code 0 on success, 1 on failure
# =========================================================================
create_final_timestamp_tag() {
    local source_tag="$1"
    local username="$2"
    local repo_prefix="$3"
    local skip_push_pull="${4:-y}" # Default to 'y' (load mode)
    local registry="${5:-}"

    log_debug "Creating final timestamp tag for source: $source_tag"
    if [[ -z "$source_tag" || -z "$username" || -z "$repo_prefix" ]]; then
        log_error "create_final_timestamp_tag missing required arguments" # Use log_error
        return 1
    fi

    # Generate a timestamp tag using function from docker_helpers.sh
    local timestamp_tag
    # Capture stdout from generate_timestamped_tag
    timestamp_tag=$(generate_timestamped_tag "$username" "$repo_prefix" "$registry")
    if [[ -z "$timestamp_tag" ]]; then
        log_error "Failed to generate timestamp tag" # Use log_error
        return 1
    fi
    log_debug "Generated timestamp tag: $timestamp_tag"

    log_info "Tagging $source_tag as $timestamp_tag" # Use log_info

    # Tag the image
    if ! docker tag "$source_tag" "$timestamp_tag"; then
        log_error "Failed to tag $source_tag as $timestamp_tag" # Use log_error
        return 1
    fi

    # If using push mode, push the new tag to registry
    if [[ "$skip_push_pull" != "y" ]]; then
        log_info "Pushing timestamp tag $timestamp_tag to registry" # Use log_info
        if ! docker push "$timestamp_tag"; then
            log_error "Failed to push $timestamp_tag to registry" # Use log_error
            # Optionally try to remove the local tag? Or leave it? Leave it for now.
            return 1
        fi
        log_success "Successfully pushed $timestamp_tag" # Use log_success
    else
        log_debug "Skipping push for timestamp tag (local build mode)."
    fi

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
        log_debug "No images provided to verify_all_images_exist_locally"
        return 0
    fi # <--- CORRECTED LINE

    log_info "Verifying local existence of $# images: $*" # Use log_info

    for img in "$@"; do
        log_debug "Checking if $img exists locally"
        if ! verify_image_exists "$img"; then # Use function from docker_helpers.sh
            log_error "Image $img not found locally" # Use log_error
            missing=1
        fi # Correct fi for inner if
    done

    if [[ $missing -eq 1 ]]; then
        log_error "One or more expected images are missing locally." # Use log_error
        return 1
    fi

    log_success "All expected images verified locally." # Use log_success
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
    test_skip_push="y" # Use 'y' for local test, 'n' requires registry login
    test_user="testuser"
    test_prefix="testprefix"
    test_registry=""

    # --- Execute Test --- #
    log_info "Test 1: Pre-tagging pull verification (local mode)"
    perform_pre_tagging_pull "$test_source_tag" "$test_skip_push"
    pre_pull_result=$?
    if [ $pre_pull_result -ne 0 ]; then
        log_error "Pre-tagging pull verification failed. Exiting test."
        docker rmi "$test_source_tag" || log_warning "Failed to remove source test image $test_source_tag"
        exit 1
    fi

    log_info "Test 2: Calling create_final_timestamp_tag..."
    final_tag=$(create_final_timestamp_tag "$test_source_tag" "$test_user" "$test_prefix" "$test_skip_push" "$test_registry")
    tag_result=$?

    # --- Report Result --- #
    if [ $tag_result -eq 0 ] && [ -n "$final_tag" ]; then
        log_success "Test tagging successful. Final Tag: $final_tag"
        log_info "Test 3: Verifying final tag exists locally..."
        if verify_all_images_exist_locally "$final_tag"; then
             log_success "Final tag verification successful."
        else
             log_error "Final tag verification failed."
             tag_result=1 # Mark test as failed
        fi
        # Clean up dummy final tag
        log_info "Cleaning up final test tag: $final_tag"
        docker rmi "$final_tag" || log_warning "Failed to remove final test tag $final_tag"
    else
        log_error "Test tagging failed with exit code $tag_result."
    fi

    # --- Cleanup --- #
    log_info "Cleaning up source test image: $test_source_tag"
    docker rmi "$test_source_tag" || log_warning "Failed to remove source test image $test_source_tag"
    log_info "Tagging script test finished."
    exit $tag_result
fi

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── tagging.sh         <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Docker image tagging and verification functions. Relies on docker_helpers.sh. Added logging. Corrected syntax error.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20240806-103000-MODULAR
