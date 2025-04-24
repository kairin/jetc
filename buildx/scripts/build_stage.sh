#!/bin/bash

# Set strict mode for this critical script
set -euo pipefail

# Build stage functions for Jetson Container build system

SCRIPT_DIR_BSTAGE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BSTAGE/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BSTAGE/docker_helpers.sh" || { echo "Error: docker_helpers.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BSTAGE/logging.sh" || { echo "Error: logging.sh not found."; exit 1; }

# =========================================================================
# Build Single Stage Script
# Responsibility: Build, push/load, and verify a single build stage.
# =========================================================================

# --- Dependencies ---
SCRIPT_DIR_STAGE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source required scripts (use fallbacks if sourcing fails)
if [ -f "$SCRIPT_DIR_STAGE/env_setup.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_STAGE/env_setup.sh"
else
    echo "Warning: env_setup.sh not found. Logging/colors may be basic." >&2
    log_info() { echo "INFO: $1"; }
    log_warning() { echo "WARNING: $1" >&2; }
    log_error() { echo "ERROR: $1" >&2; }
    log_success() { echo "SUCCESS: $1"; }
    log_debug() { :; }
fi

if [ -f "$SCRIPT_DIR_STAGE/verification.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_STAGE/verification.sh"
else
    log_warning "verification.sh not found. Image verification/pulling will fail."
    verify_image_locally() { log_warning "verify_image_locally: verification.sh not loaded"; return 1; }
    pull_image() { log_warning "pull_image: verification.sh not loaded"; return 1; }
fi

# --- Main Function --- #

# Build a single Docker build stage
# Input: $1 = folder_path (absolute path to the build context directory)
# Input: $2 = base_image_tag (tag to use as BASE_IMAGE build arg)
# Input: $3 = build_target ("push" or "load")
# Input: $4 = use_cache ("true" or "false")
# Input: $5 = platform (e.g., "linux/arm64")
# Input: $6 = docker_username
# Input: $7 = docker_repo_prefix
# Input: $8 = docker_registry (optional)
# Output: Echoes the successfully built and verified fixed tag on success.
# Return: 0 on success, non-zero on failure.
build_single_stage() {
    local folder_path="$1"
    local base_image_tag="$2"
    local build_target="$3"
    local use_cache="$4"
    local platform="$5"
    local docker_username="$6"
    local docker_repo_prefix="$7"
    local docker_registry="$8"

    local folder_name
    folder_name=$(basename "$folder_path")
    log_info "--- Starting build stage: $folder_name ---"

    # --- Input Validation ---
    if [ -z "$folder_path" ] || [ ! -d "$folder_path" ]; then
        log_error "Invalid build folder path provided: '$folder_path'"
        return 1
    fi
    if [ -z "$base_image_tag" ]; then
        log_warning "No base image tag provided for stage '$folder_name'. Assuming it's the first stage or base is defined in Dockerfile."
        # Allow continuation, Dockerfile might handle it
    fi
    if [[ "$build_target" != "push" && "$build_target" != "load" ]]; then
        log_error "Invalid build target specified: '$build_target'. Must be 'push' or 'load'."
        return 1
    fi
    if [[ "$use_cache" != "true" && "$use_cache" != "false" ]]; then
        log_error "Invalid use_cache value specified: '$use_cache'. Must be 'true' or 'false'."
        return 1
    fi
    if [ -z "$platform" ]; then
        log_error "Platform not specified."
        return 1
    fi
    if [ -z "$docker_username" ]; then
        log_error "Docker username not specified."
        return 1
    fi
    if [ -z "$docker_repo_prefix" ]; then
        log_error "Docker repository prefix not specified."
        return 1
    fi

    # --- Configuration ---
    local dockerfile_path="$folder_path/Dockerfile"
    if [ ! -f "$dockerfile_path" ]; then
        log_error "Dockerfile not found in build context: $dockerfile_path"
        return 1
    fi

    # Derive fixed image tag (e.g., user/prefix:01-stage-name)
    local fixed_tag_suffix
    fixed_tag_suffix=$(basename "$folder_path")
    local fixed_image_tag
    if [ -n "$docker_registry" ]; then
        fixed_image_tag="${docker_registry}/${docker_username}/${docker_repo_prefix}:${fixed_tag_suffix}"
    else
        fixed_image_tag="${docker_username}/${docker_repo_prefix}:${fixed_tag_suffix}"
    fi

    # Note: Adding to ATTEMPTED_TAGS should be handled by the caller (build.sh)
    # as modifying caller arrays from functions is complex in bash.
    log_info "Attempting build for tag: $fixed_image_tag"

    # --- Construct Build Command --- #
    local build_cmd=("docker" "buildx" "build")

    # Platform
    build_cmd+=("--platform" "$platform")

    # Cache
    if [[ "$use_cache" == "false" ]]; then
        build_cmd+=("--no-cache")
    fi

    # Build Arguments (Base Image)
    if [ -n "$base_image_tag" ]; then
        build_cmd+=("--build-arg" "BASE_IMAGE=$base_image_tag")
    fi
    # Add TARGETPLATFORM automatically for Dockerfile ARG TARGETPLATFORM
    build_cmd+=("--build-arg" "TARGETPLATFORM=$platform")

    # Tag
    build_cmd+=("-t" "$fixed_image_tag")

    # Target (Push or Load)
    if [[ "$build_target" == "push" ]]; then
        build_cmd+=("--push")
    else
        build_cmd+=("--load")
    fi

    # Build Context (the folder path)
    build_cmd+=("$folder_path")

    # --- Execute Build --- #
    log_info "Executing build command: ${build_cmd[*]}"
    set -o pipefail # Ensure errors in pipes are caught
    if ! "${build_cmd[@]}" 2>&1 | tee "${LOG_DIR:-/tmp}/build_stage_${folder_name}.log"; then
        log_error "Docker buildx build failed for stage: $folder_name (Tag: $fixed_image_tag)"
        log_error "Check log file: ${LOG_DIR:-/tmp}/build_stage_${folder_name}.log"
        set +o pipefail
        return 1
    fi
    set +o pipefail
    log_success "Docker buildx build completed for stage: $folder_name"

    # --- Post-Build Verification --- #
    log_info "Verifying image locally: $fixed_image_tag"
    local verification_attempts=0
    local max_verification_attempts=3
    local verification_passed=false

    while [[ $verification_attempts -lt $max_verification_attempts ]]; do
        ((verification_attempts++))
        log_debug "Verification attempt $verification_attempts for $fixed_image_tag..."

        if [[ "$build_target" == "push" ]]; then
            # If pushed, we need to pull it first
            log_info "Pulling pushed image for local verification: $fixed_image_tag"
            if ! pull_image "$fixed_image_tag"; then
                log_warning "Attempt $verification_attempts: Failed to pull image '$fixed_image_tag' after push. Retrying in 5s..."
                sleep 5
                continue # Try pulling again
            fi
        fi

        # Verify image exists locally (either loaded or pulled)
        if verify_image_locally "$fixed_image_tag"; then
            log_success "Image '$fixed_image_tag' verified locally."
            verification_passed=true
            break # Verification successful
        else
            log_warning "Attempt $verification_attempts: Image '$fixed_image_tag' not found locally after build/pull. Retrying in 5s..."
            # If push was the target, maybe the pull failed silently or registry is slow?
            if [[ "$build_target" == "push" ]]; then
                 log_info "Re-attempting pull..."
                 pull_image "$fixed_image_tag" # Try pulling again explicitly
            fi
            sleep 5
        fi
    done

    if [[ "$verification_passed" != "true" ]]; then
        log_error "Failed to verify image '$fixed_image_tag' locally after $max_verification_attempts attempts."
        return 1
    fi

    # --- Success --- #
    log_success "--- Successfully built and verified stage: $folder_name ($fixed_image_tag) ---"
    echo "$fixed_image_tag" # Output the tag for the caller
    return 0
}

# --- Main Execution (for testing) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_info "Running build_stage.sh directly for testing..."

    # --- Test Setup --- #
    # Create a dummy build context
    test_dir="/tmp/test_build_stage_$$/01-test-stage"
    mkdir -p "$test_dir"
    echo "FROM ubuntu:22.04" > "$test_dir/Dockerfile"
    echo "RUN echo \"Test stage build successful\"" >> "$test_dir/Dockerfile"
    echo "Created dummy Dockerfile in $test_dir"

    # Set dummy variables (replace with actual values if needed for real test)
    test_base="ubuntu:22.04"
    test_target="load" # Use 'load' for local test, 'push' requires registry login
    test_cache="true"
    test_platform="linux/amd64" # Use host platform for local test
    test_user="testuser"
    test_prefix="testprefix"
    test_registry=""

    # Ensure verification.sh pull_image is defined (even if dummy)
    if ! declare -f pull_image > /dev/null; then
        pull_image() { log_info "[Test] Dummy pull_image called for $1"; return 0; }
    fi
    if ! declare -f verify_image_locally > /dev/null; then
        verify_image_locally() { log_info "[Test] Dummy verify_image_locally called for $1"; docker image inspect "$1" >/dev/null 2>&1; return $?; }
    fi

    # --- Execute Test --- #
    log_info "Calling build_single_stage..."
    built_tag=$(build_single_stage "$test_dir" "$test_base" "$test_target" "$test_cache" "$test_platform" "$test_user" "$test_prefix" "$test_registry")
    result=$?

    # --- Report Result --- #
    if [ $result -eq 0 ]; then
        log_success "Test build successful. Tag: $built_tag"
        # Clean up dummy image
        log_info "Cleaning up test image: $built_tag"
        docker rmi "$built_tag" || log_warning "Failed to remove test image $built_tag"
    else
        log_error "Test build failed with exit code $result."
    fi

    # --- Cleanup --- #
    log_info "Cleaning up test directory: $(dirname "$test_dir")"
    rm -rf "$(dirname "$test_dir")"
    log_info "Build stage script test finished."
    exit $result
fi

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── build_stage.sh     <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Builds a single Docker stage, handles push/load, and verifies image locally.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-092000-BLDSTG
