#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/build_stages.sh

# =========================================================================
# Build Stages Execution Script
# Responsibility: Iterate through the determined build order and execute
#                 the build for each stage using docker_helpers.
# =========================================================================

# --- Dependencies ---
SCRIPT_DIR_STAGES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source required scripts (use fallbacks if sourcing fails)
# env_setup provides logging
if [ -f "$SCRIPT_DIR_STAGES/env_setup.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_STAGES/env_setup.sh"
else
    echo "Warning: env_setup.sh not found. Logging/colors may be basic." >&2
    log_info() { echo "INFO: $1"; }
    log_warning() { echo "WARNING: $1" >&2; }
    log_error() { echo "ERROR: $1" >&2; }
    log_success() { echo "SUCCESS: $1"; }
    log_debug() { :; }
fi
# docker_helpers provides build_folder_image
if [ -f "$SCRIPT_DIR_STAGES/docker_helpers.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_STAGES/docker_helpers.sh"
else
    log_error "docker_helpers.sh not found. Build stage execution will fail."
    build_folder_image() { log_error "build_folder_image: docker_helpers.sh not loaded"; return 1; }
fi
# env_update provides update_available_images_in_env
if [ -f "$SCRIPT_DIR_STAGES/env_update.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_STAGES/env_update.sh"
else
    log_error "env_update.sh not found. .env updates will fail."
    update_available_images_in_env() { log_error "update_available_images_in_env: env_update.sh not loaded"; return 1; }
fi


# --- Global Variables ---
# (These should be set by the calling script, build.sh, after sourcing build_order.sh)
# ORDERED_FOLDERS (global array of full paths)
# SELECTED_FOLDERS_MAP (global associative array [basename]=1)
# (These should be set by the calling script after sourcing user_interaction results)
# DOCKER_USERNAME, DOCKER_REPO_PREFIX, DOCKER_REGISTRY
# SELECTED_BASE_IMAGE
# use_cache, use_squash, skip_intermediate_push_pull, use_builder, platform

# Declare global map for skipping specific apps within stages (initialize as empty)
declare -gA skip_apps_map=() # <-- FIX: Declare the map globally

# --- Functions ---

# =========================================================================
# Function: Execute the build process for selected stages
# Arguments: None (relies on global variables set by build.sh)
# Exports:   LAST_SUCCESSFUL_TAG (global variable with the tag of the last successfully built image)
# Returns:   0 if all selected stages build successfully, 1 otherwise.
# =========================================================================
build_selected_stages() {
    log_info "=================================================="
    log_info "Starting Build Stages..."
    log_info "=================================================="

    # Ensure required global variables are available
    if [[ ${#ORDERED_FOLDERS[@]} -eq 0 ]]; then
        # This case should ideally be handled by build_order.sh logging a warning,
        # but we add an error here just in case.
        log_error "ORDERED_FOLDERS array is empty or not set. Cannot proceed."
        return 1
    fi
     # Check if SELECTED_FOLDERS_MAP is truly available (paranoid check)
     # Bash 4.3+ check: if ! declare -p SELECTED_FOLDERS_MAP &>/dev/null; then
     # More compatible check:
     if [[ ! $(declare -p SELECTED_FOLDERS_MAP 2>/dev/null) =~ "declare -A" ]]; then
        log_error "SELECTED_FOLDERS_MAP associative array is not declared globally. Check build_order.sh."
        return 1
     fi
     # Add warning if map is empty but list wasn't (indicates potential issue)
     if [[ ${#SELECTED_FOLDERS_MAP[@]} -eq 0 && -n "${SELECTED_FOLDERS_LIST:-}" ]]; then
         log_warning "SELECTED_FOLDERS_MAP is empty, but SELECTED_FOLDERS_LIST was not. Check build_order.sh."
         # Proceeding anyway based on ORDERED_FOLDERS, but this might indicate a logic error upstream.
     fi


    local current_base_image="${SELECTED_BASE_IMAGE}" # Start with the user-selected base image
    local stage_build_failed=0
    unset LAST_SUCCESSFUL_TAG # Ensure it's clear at the start

    log_info "Initial base image for build stages: $current_base_image"

    # Iterate through the globally defined ORDERED_FOLDERS array
    for build_folder_path in "${ORDERED_FOLDERS[@]}"; do
        local build_folder_basename
        build_folder_basename=$(basename "$build_folder_path")

        # Double-check if this folder should be built using the map
        # This check is somewhat redundant if ORDERED_FOLDERS is correctly filtered,
        # but acts as a safeguard.
        # Use compatible check for key existence
        if [[ ${SELECTED_FOLDERS_MAP[$build_folder_basename]+_} ]]; then # <-- Check if key exists in map
             log_info "--- Processing Stage: $build_folder_basename ---"
             log_debug "  Folder Path: $build_folder_path"
             log_debug "  Using Base Image: $current_base_image"

             # Call the build function from docker_helpers.sh
             # Pass all necessary parameters sourced from user interaction / env
             build_folder_image \
                "$build_folder_path" \
                "${use_cache:-n}" \
                "${DOCKER_USERNAME}" \
                "${platform:-linux/arm64}" \
                "${use_squash:-n}" \
                "${skip_intermediate_push_pull:-y}" \
                "$current_base_image" \
                "${DOCKER_REPO_PREFIX}" \
                "${DOCKER_REGISTRY:-}" \
                "${use_builder:-y}" # Pass use_builder preference

            local build_status=$?
            # build_folder_image should export 'fixed_tag' on success
            # shellcheck disable=SC2154 # fixed_tag is exported by build_folder_image
            local current_fixed_tag="${fixed_tag:-}" # Capture the exported tag

            if [[ $build_status -eq 0 && -n "$current_fixed_tag" ]]; then
                log_success "Stage '$build_folder_basename' completed successfully."
                log_info "  Output Image: $current_fixed_tag"
                # Update base image for the next stage
                current_base_image="$current_fixed_tag"
                # Store the last successful tag globally
                export LAST_SUCCESSFUL_TAG="$current_fixed_tag"
                # Update .env with the newly available image
                update_available_images_in_env "$current_fixed_tag"
            else
                log_error "Stage '$build_folder_basename' failed with exit code $build_status."
                log_debug "  Failed Tag (if generated): ${current_fixed_tag:-<none>}"
                stage_build_failed=1
                # Decide whether to continue or break on failure
                # For now, let's break to prevent building dependent stages on a failed base
                log_error "Aborting remaining build stages due to failure in '$build_folder_basename'."
                break
            fi
             log_info "--- Stage Complete: $build_folder_basename ---"
        else
            # This case should not happen if build_order.sh works correctly
            log_warning "Skipping folder '$build_folder_basename' as it wasn't found in SELECTED_FOLDERS_MAP (this might indicate an issue)."
        fi
    done < <(printf '%s\n' "${ORDERED_FOLDERS[@]}") # Feed the loop safely

    log_info "=================================================="
    if [[ $stage_build_failed -eq 0 ]]; then
        log_success "All selected build stages completed."
        return 0
    else
        log_error "One or more build stages failed."
        # LAST_SUCCESSFUL_TAG will hold the tag of the last stage that *did* succeed
        return 1
    fi
}


# --- Main Execution (for testing) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_info "Running build_stages.sh directly for testing..."

    # --- Test Setup --- #
    # Mock necessary functions and variables if not sourced
     if ! command -v build_folder_image &> /dev/null; then
        log_warning "Mocking build_folder_image for testing."
        build_folder_image() {
            local folder="$1"
            local base_name
            base_name=$(basename "$folder")
            log_info "Mock build_folder_image called for: $base_name"
            # Simulate success for '01-*', failure for '02-*'
            if [[ "$base_name" == 01-* ]]; then
                export fixed_tag="mock/repo:${base_name}-success"
                log_success " -> Mock Success: $fixed_tag"
                return 0
            elif [[ "$base_name" == 02-* ]]; then
                 export fixed_tag="mock/repo:${base_name}-fail"
                 log_error " -> Mock Failure"
                 return 1
            else
                 export fixed_tag="mock/repo:${base_name}-success"
                 log_success " -> Mock Success (default): $fixed_tag"
                 return 0
            fi
        }
    fi
     if ! command -v update_available_images_in_env &> /dev/null; then
        log_warning "Mocking update_available_images_in_env for testing."
        update_available_images_in_env() { log_info "Mock update_available_images_in_env called with: $1"; return 0; }
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
    platform="linux/arm64"
    SELECTED_FOLDERS_LIST="01-first 02-second-fails 03-third" # For warning check

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

    log_info ""
    log_info "*** Test 2: Build sequence all success ***"
    ORDERED_FOLDERS=( "/tmp/build/01-first" "/tmp/build/03-third" )
    declare -gA SELECTED_FOLDERS_MAP=( ["01-first"]=1 ["03-third"]=1 )
    SELECTED_FOLDERS_LIST="01-first 03-third"
    unset LAST_SUCCESSFUL_TAG # Clear from previous test
    if build_selected_stages; then
         log_success "Test 2 Result: build_selected_stages reported SUCCESS (expected)."
    else
         log_error "Test 2 Result: build_selected_stages reported FAILURE (unexpected)."
    fi
    log_info "Test 2 LAST_SUCCESSFUL_TAG: ${LAST_SUCCESSFUL_TAG:-<unset>}"
    echo "--------------------"

     log_info ""
    log_info "*** Test 3: ORDERED_FOLDERS is empty ***"
    ORDERED_FOLDERS=()
    SELECTED_FOLDERS_MAP=()
    SELECTED_FOLDERS_LIST=""
    unset LAST_SUCCESSFUL_TAG
     if build_selected_stages; then
         log_error "Test 3 Result: build_selected_stages reported SUCCESS (unexpected)."
    else
         log_error "Test 3 Result: build_selected_stages reported FAILURE (expected)."
    fi
    log_info "Test 3 LAST_SUCCESSFUL_TAG: ${LAST_SUCCESSFUL_TAG:-<unset>}"
    echo "--------------------"


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
# Description: Iterates through build stages determined by build_order.sh
#              and executes the build using docker_helpers.sh functions.
#              Fixed unbound variable 'skip_apps_map'.
# Author: Mr K / GitHub Copilot / kairin
# COMMIT-TRACKING: UUID-20250424-200404-STAGESFIX
