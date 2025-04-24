#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/tagging.sh

# =========================================================================
# Final Tagging Script
# Responsibility: Create, push, and verify the final timestamped tag.
# =========================================================================

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

# --- Main Function --- #

# Create the final timestamped tag based on the last successful build stage
# Input: $1 = last_successful_fixed_tag (The tag of the final image built in the loop)
# Input: $2 = build_target ("push" or "load")
# Input: $3 = docker_username
# Input: $4 = docker_repo_prefix
# Input: $5 = docker_registry (optional)
# Output: Echoes the final timestamped tag on success.
# Return: 0 on success, non-zero on failure.
create_final_timestamp_tag() {
    local last_successful_fixed_tag="$1"
    local build_target="$2"
    local docker_username="$3"
    local docker_repo_prefix="$4"
    local docker_registry="$5"

    log_info "--- Starting Final Tagging Process ---"

    # --- Input Validation ---
    if [ -z "$last_successful_fixed_tag" ]; then
        log_error "Final tagging requires the last successful fixed tag."
        return 1
    fi
    if [[ "$build_target" != "push" && "$build_target" != "load" ]]; then
        log_error "Invalid build target specified for tagging: '$build_target'. Must be 'push' or 'load'."
        return 1
    fi
    if [ -z "$docker_username" ]; then
        log_error "Docker username not specified for tagging."
        return 1
    fi
    if [ -z "$docker_repo_prefix" ]; then
        log_error "Docker repository prefix not specified for tagging."
        return 1
    fi

    # --- Verify Source Image --- #
    log_info "Verifying source image exists locally: $last_successful_fixed_tag"
    if ! verify_image_locally "$last_successful_fixed_tag"; then
        log_error "Source image '$last_successful_fixed_tag' for final tagging not found locally. Cannot proceed."
        return 1
    fi
    log_success "Source image verified."

    # --- Generate Timestamped Tag --- #
    local current_date_time
    current_date_time=$(get_system_datetime)
    local timestamped_latest_tag_base
    if [ -n "$docker_registry" ]; then
        timestamped_latest_tag_base="${docker_registry}/${docker_username}/${docker_repo_prefix}"
    else
        timestamped_latest_tag_base="${docker_username}/${docker_repo_prefix}"
    fi
    local timestamped_latest_tag="${timestamped_latest_tag_base}:latest-${current_date_time}-1"

    log_info "Generated final timestamped tag: $timestamped_latest_tag"

    # --- Tag Image --- #
    log_info "Tagging $last_successful_fixed_tag -> $timestamped_latest_tag"
    if ! docker tag "$last_successful_fixed_tag" "$timestamped_latest_tag"; then
        log_error "Failed to tag image '$last_successful_fixed_tag' as '$timestamped_latest_tag'."
        return 1
    fi
    log_success "Image tagged successfully."

    # --- Push and Verify (if build target was push) --- #
    if [[ "$build_target" == "push" ]]; then
        log_info "Pushing final timestamped tag: $timestamped_latest_tag"
        if ! docker push "$timestamped_latest_tag"; then
            log_error "Failed to push final tag '$timestamped_latest_tag'."
            # Consider attempting to remove the local tag if push fails?
            # docker rmi "$timestamped_latest_tag" || log_warning "Failed to remove local tag $timestamped_latest_tag after push failure."
            return 1
        fi
        log_success "Final tag pushed successfully."

        # Pull back to verify registry consistency
        log_info "Pulling final tag for verification: $timestamped_latest_tag"
        if ! pull_image "$timestamped_latest_tag"; then
            log_error "Failed to pull back final tag '$timestamped_latest_tag' after push. Registry might be inconsistent."
            return 1
        fi
        log_success "Final tag pulled successfully."
    fi

    # --- Final Local Verification --- #
    log_info "Verifying final tag exists locally: $timestamped_latest_tag"
    if ! verify_image_locally "$timestamped_latest_tag"; then
        log_error "Final tag '$timestamped_latest_tag' not found locally after tagging/pulling."
        return 1
    fi
    log_success "Final tag '$timestamped_latest_tag' verified locally."

    # --- Success --- #
    log_success "--- Final Tagging Process Completed Successfully ---"
    echo "$timestamped_latest_tag" # Output the tag for the caller
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
# Description: Handles the creation, pushing, and verification of the final timestamped image tag.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-092500-TAGGING
