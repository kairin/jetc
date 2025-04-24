#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/build_stages.sh

# =========================================================================
# Build Stages Execution Script
# Responsibility: Iterate through the determined build order and execute
#                 the build for each stage using docker_helpers.
# =========================================================================

# Set strict mode
set -euo pipefail

# --- Dependencies ---
SCRIPT_DIR_STAGES="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# Source required scripts (use fallbacks if sourcing fails)
# env_setup provides logging and global vars like PLATFORM
if [ -f "$SCRIPT_DIR_STAGES/env_setup.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_STAGES/env_setup.sh"
else
    echo "CRITICAL ERROR: env_setup.sh not found. Cannot proceed." >&2
    exit 1
fi
# docker_helpers provides build_folder_image
if [ -f "$SCRIPT_DIR_STAGES/docker_helpers.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_STAGES/docker_helpers.sh"
else
    log_error "docker_helpers.sh not found. Build stage execution will fail."
    exit 1
fi
# env_update provides update_available_images_in_env
if [ -f "$SCRIPT_DIR_STAGES/env_update.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_STAGES/env_update.sh"
else
    log_error "env_update.sh not found. .env updates will fail."
    # Allow to continue but warn, maybe updates aren't critical
    update_available_images_in_env() { log_warning "update_available_images_in_env: env_update.sh not loaded"; return 0; }
fi


# --- Global Variables ---
# ORDERED_FOLDERS, SELECTED_FOLDERS_MAP, DOCKER_USERNAME, DOCKER_REPO_PREFIX,
# DOCKER_REGISTRY, SELECTED_BASE_IMAGE, use_cache, use_squash,
# skip_intermediate_push_pull, use_builder, PLATFORM

# Declare global map for skipping specific apps within stages (initialize as empty)
declare -gA skip_apps_map=()

# --- Functions ---

# =========================================================================
# Function: Build all selected stages in order
# Relies on global variables: ORDERED_FOLDERS, SELECTED_USE_CACHE, DOCKER_USERNAME,
#                             SELECTED_USE_SQUASH, SELECTED_SKIP_INTERMEDIATE,
#                             LAST_SUCCESSFUL_TAG, DOCKER_REPO_PREFIX, DOCKER_REGISTRY,
#                             SELECTED_USE_BUILDER
# Exports: LAST_SUCCESSFUL_TAG (updated on success)
# Returns: 0 if all selected stages build successfully, 1 otherwise
# =========================================================================
build_selected_stages() {
    log_info "--- Starting Build Stages ---"
    local overall_status=0
    export LAST_SUCCESSFUL_TAG="${LAST_SUCCESSFUL_TAG:-}" # Ensure it's exported and initialized

    if [ ${#ORDERED_FOLDERS[@]} -eq 0 ]; then
        log_warning "No build stages found or selected in ORDERED_FOLDERS. Nothing to build."
        return 0 # Nothing to do, considered success
    fi

    log_info "Found ${#ORDERED_FOLDERS[@]} stages to process."

    for folder_path in "${ORDERED_FOLDERS[@]}"; do
        local folder_name
        folder_name=$(basename "$folder_path")
        log_info "--- Processing Stage: $folder_name ---"
        echo "DEBUG ECHO: Processing $folder_name" # Added for visibility

        # Determine the base image for the current stage
        # Default to the last successful tag, or the initial base if it's the first stage
        local current_base_image="${LAST_SUCCESSFUL_TAG:-$SELECTED_BASE_IMAGE}"
        log_debug "Using base image for '$folder_name': $current_base_image"

        # Call build_folder_image with all required arguments from global scope
        # Ensure the order matches the function definition in docker_helpers.sh
        # build_folder_image "$folder_path" "$use_cache" "$docker_username" "$use_squash" "$skip_intermediate" "$base_image_tag" "$docker_repo_prefix" "$docker_registry" "$use_builder"
        if build_folder_image \
            "$folder_path" \
            "${SELECTED_USE_CACHE:-y}" \
            "${DOCKER_USERNAME}" \
            "${SELECTED_USE_SQUASH:-n}" \
            "${SELECTED_SKIP_INTERMEDIATE:-n}" \
            "$current_base_image" \
            "${DOCKER_REPO_PREFIX}" \
            "${DOCKER_REGISTRY:-}" \
            "${SELECTED_USE_BUILDER:-y}"; then

            # On success, update LAST_SUCCESSFUL_TAG with the tag just built (fixed_tag is exported by build_folder_image)
            if [[ -n "${fixed_tag:-}" ]]; then
                 export LAST_SUCCESSFUL_TAG="$fixed_tag"
                 log_success "Stage '$folder_name' completed successfully."
                 log_info "  Output Image: $LAST_SUCCESSFUL_TAG"
                 # Update AVAILABLE_IMAGES in .env
                 update_available_images_in_env "$LAST_SUCCESSFUL_TAG"
                 log_info "--- Stage Complete: $folder_name ---"
            else
                 log_error "Build succeeded for '$folder_name' but fixed_tag was not exported correctly."
                 overall_status=1
                 break # Stop build on unexpected state
            fi
        else
            log_error "Stage '$folder_name' failed with exit code $?."
            overall_status=1
            break # Stop build process on first failure
        fi
    done

    if [[ $overall_status -eq 0 ]]; then
        log_success "--- All Selected Build Stages Completed Successfully ---"
    else
        log_error "--- Build Process Aborted Due to Failure in Stage '$folder_name' ---"
    fi

    return $overall_status
}

# --- Main Execution (for testing) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Minimal setup for testing if run directly
    export SCRIPT_DIR_STAGES
     if ! command -v build_folder_image &> /dev/null; then
        echo "Warning: Mocking build_folder_image for testing." >&2
        build_folder_image() {
            local folder="$1" username="$3" repo_prefix="$7"
            local base_name
            base_name=$(basename "$folder")
            echo "INFO: Mock build_folder_image called for: $base_name"
            echo "DEBUG: Mock Args: $@"
            if [[ "$base_name" == 01-* ]]; then
                export fixed_tag="${username}/${repo_prefix}:${base_name}-success"
                echo "SUCCESS: -> Mock Success: $fixed_tag"
                return 0
            elif [[ "$base_name" == 02-* ]]; then
                 export fixed_tag="${username}/${repo_prefix}:${base_name}-fail"
                 echo "ERROR: -> Mock Failure" >&2
                 return 1
            else
                 export fixed_tag="${username}/${repo_prefix}:${base_name}-success"
                 echo "SUCCESS: -> Mock Success (default): $fixed_tag"
                 return 0
            fi
        }
    fi
     if ! command -v update_available_images_in_env &> /dev/null; then
        echo "Warning: Mocking update_available_images_in_env for testing." >&2
        update_available_images_in_env() { echo "INFO: Mock update_available_images_in_env called with: $1"; return 0; }
    fi
     if ! command -v log_info &> /dev/null; then
        log_info() { echo "INFO: $1"; }
        log_warning() { echo "WARNING: $1" >&2; }
        log_error() { echo "ERROR: $1" >&2; }
        log_success() { echo "SUCCESS: $1"; }
        log_debug() { echo "[DEBUG] build_stages_test: $1" >&2; } # Make debug visible in test
     fi

    # Set mock global variables
    ORDERED_FOLDERS=( "/tmp/build/01-first" "/tmp/build/02-second-fails" "/tmp/build/03-third" )
    declare -gA SELECTED_FOLDERS_MAP=( ["01-first"]=1 ["02-second-fails"]=1 ["03-third"]=1 )
    SELECTED_BASE_IMAGE="mock/repo:initial-base"
    DOCKER_USERNAME="mockuser"
    DOCKER_REPO_PREFIX="mockrepo"
    DOCKER_REGISTRY=""
    use_cache="n"
    use_squash="n"
    skip_intermediate_push_pull="y"
    use_builder="y"
    PLATFORM="linux/arm64"
    SELECTED_FOLDERS_LIST="01-first 02-second-fails 03-third"

    # --- Test Cases --- #
    log_info ""
    log_info "*** Test 1: Build sequence with one failure ***"
    if build_selected_stages; then
         log_success "Test 1 Result: build_selected_stages reported SUCCESS (unexpected)."
    else
         log_error "Test 1 Result: build_selected_stages reported FAILURE (expected)."
    fi
    log_info "Test 1 LAST_SUCCESSFUL_TAG: ${LAST_SUCCESSFUL_TAG:-<unset>}"
    echo "--------------------"

    # ... (rest of tests omitted for brevity) ...

    # --- Cleanup --- #
    log_info ""
    log_info "Build stages script test finished."
    exit 0
fi


# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── build_stages.sh    <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Manages the execution of build stages. Fixed typo in update_available_images_in_env call.
# Author: Mr K / GitHub Copilot / kairin
# COMMIT-TRACKING: UUID-20250425-071326-ENVUPDFIX
