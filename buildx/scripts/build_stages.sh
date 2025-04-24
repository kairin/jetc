#!/bin/bash

# Set strict mode for this critical script
set -euo pipefail

# Source necessary utilities and helpers
SCRIPT_DIR_BSTAGES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BSTAGES/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BSTAGES/docker_helpers.sh" || { echo "Error: docker_helpers.sh not found."; exit 1; }
# Source logging functions if available
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BSTAGES/env_setup.sh" 2>/dev/null || true
# Source env_update to update AVAILABLE_IMAGES
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BSTAGES/env_update.sh" || { echo "Error: env_update.sh not found."; exit 1; }
# Source system checks for handle_build_error
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BSTAGES/system_checks.sh" || { echo "Error: system_checks.sh not found."; exit 1; }


# =========================================================================
# Function: Build selected numbered and other directories
# Relies on: Variables exported by build_prefs.sh (use_cache, platform, etc.)
#            ORDERED_FOLDERS (array exported by build_order.sh)
#            SELECTED_FOLDERS_MAP (associative array exported by build_order.sh)
#            SKIP_APPS_LIST (space-separated list from build_prefs.sh, optional)
# Exports:   LAST_SUCCESSFUL_TAG (tag of the final successfully built image)
# Returns: 0 if all selected stages build successfully, 1 otherwise
# =========================================================================
build_selected_stages() {
    log_info "==================================================" # Use log_info
    log_info "Starting Build Stages..." # Use log_info
    log_info "==================================================" # Use log_info

    # Ensure required variables are set (should be sourced from PREFS_FILE by build.sh/user_interaction.sh)
    log_debug "Checking required build variables..."
    : "${use_cache?Variable use_cache not set}"
    : "${platform?Variable platform not set}"
    : "${use_squash?Variable use_squash not set}"
    : "${skip_intermediate_push_pull?Variable skip_intermediate_push_pull not set}"
    : "${SELECTED_BASE_IMAGE?Variable SELECTED_BASE_IMAGE not set}"
    : "${DOCKER_USERNAME?Variable DOCKER_USERNAME not set}"
    : "${DOCKER_REPO_PREFIX?Variable DOCKER_REPO_PREFIX not set}"
    # DOCKER_REGISTRY is optional
    # ORDERED_FOLDERS and SELECTED_FOLDERS_MAP must be exported by build_order.sh
    if [[ -z "${ORDERED_FOLDERS[*]}" ]]; then
        log_error "ORDERED_FOLDERS array is empty or not set. Cannot proceed." # Use log_error
        return 1
    fi
     if [[ -z "${!SELECTED_FOLDERS_MAP[@]}" && -n "${SELECTED_FOLDERS_LIST:-}" ]]; then
        # If the map is empty but the list wasn't, it indicates an issue in build_order.sh
        log_warning "SELECTED_FOLDERS_MAP is empty, but SELECTED_FOLDERS_LIST was not. Check build_order.sh." # Use log_warning
        # Depending on desired behavior, could return 1 here or try to rebuild map from list.
        # For now, proceed, but builds might be skipped unexpectedly.
    fi
    log_debug "Required variables checked."

    # SKIP_APPS_LIST is optional, default to empty if not set
    SKIP_APPS_LIST="${SKIP_APPS_LIST:-}"
    log_debug "SKIP_APPS_LIST: '$SKIP_APPS_LIST'"

    # Convert SKIP_APPS_LIST to an associative array for faster lookups
    declare -A skip_apps_map
    if [[ -n "$SKIP_APPS_LIST" ]]; then
        log_info "Apps selected to SKIP installation (if already present): $SKIP_APPS_LIST" # Use log_info
        for app_to_skip in $SKIP_APPS_LIST; do
            skip_apps_map["$app_to_skip"]=1
            log_debug "Added '$app_to_skip' to skip_apps_map."
        done
    fi

    local current_base_image="$SELECTED_BASE_IMAGE" # Start with the base image selected by the user
    export LAST_SUCCESSFUL_TAG="$current_base_image" # Initialize with the starting base image
    local build_failed=0
    local build_dir_path # Define outside loop for use in update_available_images_in_env
    log_debug "Initial base image: $current_base_image"
    log_debug "Initial LAST_SUCCESSFUL_TAG: $LAST_SUCCESSFUL_TAG"

    # Iterate through the ordered list of folders provided by build_order.sh
    log_debug "Iterating through ORDERED_FOLDERS..."
    for folder_path in "${ORDERED_FOLDERS[@]}"; do
        local folder_name
        folder_name=$(basename "$folder_path")
        build_dir_path=$(dirname "$folder_path") # Store the parent build dir path
        log_debug "Processing folder: $folder_name ($folder_path)"

        # Check if this folder was selected for building using the map from build_order.sh
        if [[ -z "${SELECTED_FOLDERS_MAP[$folder_name]}" ]]; then
            log_debug "Skipping folder (not selected): $folder_name"
            continue
        fi
        log_debug "Folder '$folder_name' is selected for build."

        # --- Check if app should be skipped ---
        local app_name="${folder_name#*-}" # Heuristic: app name is after first dash
        # Refine heuristic: handle multi-part prefixes like 01-01-00-
        if [[ "$folder_name" =~ ^[0-9]+(-[0-9]+)*-(.*) ]]; then
            app_name="${BASH_REMATCH[2]}" # Capture everything after the last numbered prefix dash
        else
             app_name="${folder_name#*-}" # Fallback
        fi
        log_debug "Derived app name for skip check: '$app_name'"

        if [[ -n "${skip_apps_map[$app_name]}" ]]; then
            log_warning "==================================================" # Use log_warning for skipped section
            log_warning "SKIPPING build stage for '$app_name' ($folder_name) as requested (already present in base)." # Use log_warning
            log_warning "Using previous stage's image as input for next stage: $LAST_SUCCESSFUL_TAG" # Use log_warning
            log_warning "==================================================" # Use log_warning
            # The LAST_SUCCESSFUL_TAG remains unchanged, acting as the base for the next stage
            continue # Move to the next folder
        fi
        # --- End skip check ---

        # Set current stage for logging context
        # Check if function exists before calling
        if command -v set_stage &> /dev/null; then
            set_stage "$folder_name"
        else
            log_debug "set_stage function not found."
        fi

        # Disable exit on error temporarily for build_folder_image
        set +e
        log_debug "Calling build_folder_image for $folder_name..."
        # Call build_folder_image from docker_helpers.sh
        # It exports 'fixed_tag' on success
        build_folder_image "$folder_path" "$use_cache" "$platform" "$use_squash" "$skip_intermediate_push_pull" "$current_base_image" "$DOCKER_USERNAME" "$DOCKER_REPO_PREFIX" "${DOCKER_REGISTRY:-}"
        local build_status=$?
        set -e # Re-enable exit on error
        log_debug "build_folder_image for $folder_name exited with status: $build_status"

        if [ $build_status -eq 0 ]; then
            # Build succeeded, update the base image for the next stage
            # 'fixed_tag' is exported by build_folder_image
            if [[ -z "${fixed_tag:-}" ]]; then
                log_error "fixed_tag not set after successful build of folder $folder_name" # Use log_error
                build_failed=1
                # Decide whether to continue or break based on FAIL_FAST
                if [[ "${FAIL_FAST:-false}" == "true" ]]; then break; else continue; fi
            fi
            
            current_base_image="$fixed_tag"
            export LAST_SUCCESSFUL_TAG="$fixed_tag" # Update the last known good tag
            log_success "Successfully built stage: $folder_name. Output image: $LAST_SUCCESSFUL_TAG" # Use log_success

            # Update AVAILABLE_IMAGES in .env immediately after successful build
            # Use the dedicated function from env_update.sh
            if [[ -n "$build_dir_path" ]]; then # Ensure path is valid
                 # Assumes .env is one level above build/
                 local env_file_path="$(dirname "$build_dir_path")/.env"
                 log_debug "Attempting to update AVAILABLE_IMAGES in $env_file_path with tag $LAST_SUCCESSFUL_TAG"
                 if ! update_available_images_in_env "$env_file_path" "$LAST_SUCCESSFUL_TAG"; then
                     log_warning "Failed to update AVAILABLE_IMAGES in .env with new tag." # Use log_warning
                 else
                     log_debug "Successfully updated AVAILABLE_IMAGES in .env."
                 fi
            else
                 log_warning "Could not determine .env file path to update AVAILABLE_IMAGES." # Use log_warning
            fi

        else
            # Build failed
            handle_build_error "$folder_path" "$build_status" # Log error using function from system_checks.sh
            build_failed=1
            # Do NOT update LAST_SUCCESSFUL_TAG or current_base_image
            log_warning "Build failed for stage: $folder_name. Last successful image remains: $LAST_SUCCESSFUL_TAG" # Use log_warning
        fi
        
        # Check if we should stop the build after a failure
        if [[ $build_failed -eq 1 && "${FAIL_FAST:-false}" == "true" ]]; then
            log_error "Exiting build early due to failure (FAIL_FAST=true)" # Use log_error
            break
        fi
    done
    log_debug "Finished iterating through ORDERED_FOLDERS."

    log_info "==================================================" # Use log_info
    log_info "Finished Building Selected Stages." # Use log_info
    if [ $build_failed -eq 1 ]; then
        log_error "One or more build stages failed. Final image is the last successful one: $LAST_SUCCESSFUL_TAG" # Use log_error
        return 1 # Indicate failure
    else
        log_success "All selected build stages completed successfully. Final image: $LAST_SUCCESSFUL_TAG" # Use log_success
        return 0 # Indicate success
    fi
}

# Execute the function if the script is run directly (for testing or modular use)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_info "Running build_stages.sh directly..." # Use log_info
    # Load prefs from temp file if it exists (for testing)
    PREFS_FILE="/tmp/build_prefs.sh"
    if [ -f "$PREFS_FILE" ]; then
        log_info "Sourcing preferences from $PREFS_FILE" # Use log_info
        # shellcheck disable=SC1090
        source "$PREFS_FILE"
    else
        log_warning "$PREFS_FILE not found. Using potentially unset variables." # Use log_warning
    fi

    # Need to manually set up ORDERED_FOLDERS and SELECTED_FOLDERS_MAP for direct execution
    log_warning "Note: Direct execution requires ORDERED_FOLDERS and SELECTED_FOLDERS_MAP to be set manually." # Use log_warning
    # Example setup for testing:
    # BUILDX_DIR=$(dirname "$SCRIPT_DIR_BSTAGES")
    # export ORDERED_FOLDERS=("$BUILDX_DIR/build/01-00-build-essential" "$BUILDX_DIR/build/04-python")
    # declare -gA SELECTED_FOLDERS_MAP=( ["01-00-build-essential"]=1 ["04-python"]=1 )
    # export SELECTED_BASE_IMAGE="ubuntu:22.04" # Example base
    # export DOCKER_USERNAME="testuser"
    # export DOCKER_REPO_PREFIX="testprefix"
    # export use_cache="n"; export platform="linux/arm64"; export use_squash="n"; export skip_intermediate_push_pull="y";

    if [[ -z "${ORDERED_FOLDERS[*]}" ]]; then
        log_error "ORDERED_FOLDERS not set. Cannot run directly without manual setup." # Use log_error
        exit 1
    fi
     if [[ -z "${!SELECTED_FOLDERS_MAP[@]}" ]]; then
        log_error "SELECTED_FOLDERS_MAP not set. Cannot run directly without manual setup." # Use log_error
        exit 1
    fi


    build_selected_stages
    exit $?
fi

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── build_stages.sh    <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Builds Docker stages based on ORDERED_FOLDERS and SELECTED_FOLDERS_MAP. Updates AVAILABLE_IMAGES in .env. Added logging. Verified .env updates.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-095000-BSTAGESREF
