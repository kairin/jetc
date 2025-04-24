#!/bin/bash

# Source necessary utilities and helpers
SCRIPT_DIR_BSTAGES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BSTAGES/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BSTAGES/docker_helpers.sh" || { echo "Error: docker_helpers.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BSTAGES/logging.sh" || { echo "Error: logging.sh not found."; exit 1; }
# Source env_update to update AVAILABLE_IMAGES (though env_helpers might be enough if loaded)
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BSTAGES/env_update.sh" || { echo "Error: env_update.sh not found."; exit 1; }


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
    echo "=================================================="
    echo "Starting Build Stages..."
    echo "=================================================="

    # Ensure required variables are set (should be sourced from PREFS_FILE by build.sh/user_interaction.sh)
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
        echo "Error: ORDERED_FOLDERS array is empty or not set. Cannot proceed." >&2
        return 1
    fi
     if [[ -z "${!SELECTED_FOLDERS_MAP[@]}" && -n "${SELECTED_FOLDERS_LIST:-}" ]]; then
        # If the map is empty but the list wasn't, it indicates an issue in build_order.sh
        echo "Warning: SELECTED_FOLDERS_MAP is empty, but SELECTED_FOLDERS_LIST was not. Check build_order.sh." >&2
        # Depending on desired behavior, could return 1 here or try to rebuild map from list.
        # For now, proceed, but builds might be skipped unexpectedly.
    fi

    # SKIP_APPS_LIST is optional, default to empty if not set
    SKIP_APPS_LIST="${SKIP_APPS_LIST:-}"

    # Convert SKIP_APPS_LIST to an associative array for faster lookups
    declare -A skip_apps_map
    if [[ -n "$SKIP_APPS_LIST" ]]; then
        echo "Apps selected to SKIP installation (if already present): $SKIP_APPS_LIST"
        for app_to_skip in $SKIP_APPS_LIST; do
            skip_apps_map["$app_to_skip"]=1
        done
    fi

    local current_base_image="$SELECTED_BASE_IMAGE" # Start with the base image selected by the user
    export LAST_SUCCESSFUL_TAG="$current_base_image" # Initialize with the starting base image
    local build_failed=0
    local build_dir_path # Define outside loop for use in update_available_images_in_env

    # Iterate through the ordered list of folders provided by build_order.sh
    for folder_path in "${ORDERED_FOLDERS[@]}"; do
        local folder_name
        folder_name=$(basename "$folder_path")
        build_dir_path=$(dirname "$folder_path") # Store the parent build dir path

        # Check if this folder was selected for building using the map from build_order.sh
        if [[ -z "${SELECTED_FOLDERS_MAP[$folder_name]}" ]]; then
            echo "Skipping folder (not selected): $folder_name"
            continue
        fi

        # --- Check if app should be skipped ---
        # ... existing skip logic ...
        local app_name="${folder_name#*-}" # Heuristic: app name is after first dash
        # Refine heuristic: handle multi-part prefixes like 01-01-00-
        if [[ "$folder_name" =~ ^[0-9]+(-[0-9]+)*-(.*) ]]; then
            app_name="${BASH_REMATCH[2]}" # Capture everything after the last numbered prefix dash
        else
             app_name="${folder_name#*-}" # Fallback
        fi

        if [[ -n "${skip_apps_map[$app_name]}" ]]; then
            echo "==================================================" | tee -a "${MAIN_LOG}"
            echo "SKIPPING build stage for '$app_name' ($folder_name) as requested (already present in base)." | tee -a "${MAIN_LOG}"
            echo "Using previous stage's image as input for next stage: $LAST_SUCCESSFUL_TAG" | tee -a "${MAIN_LOG}"
            echo "==================================================" | tee -a "${MAIN_LOG}"
            # The LAST_SUCCESSFUL_TAG remains unchanged, acting as the base for the next stage
            continue # Move to the next folder
        fi
        # --- End skip check ---

        set_stage "$folder_name" # Set current stage for logging

        # Disable exit on error temporarily for build_folder_image
        set +e
        # Call build_folder_image from docker_helpers.sh
        # It exports 'fixed_tag' on success
        build_folder_image "$folder_path" "$use_cache" "$platform" "$use_squash" "$skip_intermediate_push_pull" "$current_base_image" "$DOCKER_USERNAME" "$DOCKER_REPO_PREFIX" "$DOCKER_REGISTRY"
        local build_status=$?
        set -e # Re-enable exit on error

        if [ $build_status -eq 0 ]; then
            # Build succeeded, update the base image for the next stage
            # 'fixed_tag' is exported by build_folder_image
            current_base_image="$fixed_tag"
            export LAST_SUCCESSFUL_TAG="$fixed_tag" # Update the last known good tag
            echo "Successfully built stage: $folder_name. Output image: $LAST_SUCCESSFUL_TAG" | tee -a "${MAIN_LOG}"

            # Update AVAILABLE_IMAGES in .env immediately after successful build
            # Use the dedicated function from env_update.sh
            if [[ -n "$build_dir_path" ]]; then # Ensure path is valid
                 local env_file_path="$(dirname "$build_dir_path")/.env" # Assumes .env is one level above build/
                 update_available_images_in_env "$env_file_path" "$LAST_SUCCESSFUL_TAG"
            else
                 echo "Warning: Could not determine .env file path to update AVAILABLE_IMAGES." | tee -a "${MAIN_LOG}" "${ERROR_LOG}"
            fi

        else
            # Build failed
            handle_build_error "$folder_path" "$build_status" # Log error but continue
            build_failed=1
            # Do NOT update LAST_SUCCESSFUL_TAG or current_base_image
            echo "Build failed for stage: $folder_name. Last successful image remains: $LAST_SUCCESSFUL_TAG" | tee -a "${MAIN_LOG}" "${ERROR_LOG}"
            # Optionally, ask user if they want to continue? For now, continue automatically.
            # Consider adding a prompt here or an overall build strategy flag (fail fast vs continue)
            # read -p "Stage $folder_name failed. Continue with next stage? (y/n) [y]: " continue_on_fail
            # if [[ "${continue_on_fail:-y}" != "y" ]]; then
            #     echo "Exiting build due to stage failure." | tee -a "${MAIN_LOG}" "${ERROR_LOG}"
            #     return 1 # Exit immediately
            # fi
        fi
    done

    echo "=================================================="
    echo "Finished Building Selected Stages."
    if [ $build_failed -eq 1 ]; then
        echo "One or more build stages failed. Final image is the last successful one: $LAST_SUCCESSFUL_TAG" | tee -a "${MAIN_LOG}" "${ERROR_LOG}"
        return 1 # Indicate failure
    else
        echo "All selected build stages completed successfully. Final image: $LAST_SUCCESSFUL_TAG" | tee -a "${MAIN_LOG}"
        return 0 # Indicate success
    fi
}

# Execute the function if the script is run directly (for testing or modular use)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Running build_stages.sh directly..."
    # Load prefs from temp file if it exists (for testing)
    PREFS_FILE="/tmp/build_prefs.sh"
    if [ -f "$PREFS_FILE" ]; then
        echo "Sourcing preferences from $PREFS_FILE"
        # shellcheck disable=SC1090
        source "$PREFS_FILE"
    else
        echo "Warning: $PREFS_FILE not found. Using potentially unset variables."
    fi

    # Need to manually set up ORDERED_FOLDERS and SELECTED_FOLDERS_MAP for direct execution
    echo "Note: Direct execution requires ORDERED_FOLDERS and SELECTED_FOLDERS_MAP to be set manually."
    # Example setup for testing:
    # BUILDX_DIR=$(dirname "$SCRIPT_DIR_BSTAGES")
    # export ORDERED_FOLDERS=("$BUILDX_DIR/build/01-00-build-essential" "$BUILDX_DIR/build/04-python")
    # declare -gA SELECTED_FOLDERS_MAP=( ["01-00-build-essential"]=1 ["04-python"]=1 )
    # export SELECTED_BASE_IMAGE="ubuntu:22.04" # Example base
    # export DOCKER_USERNAME="testuser"
    # export DOCKER_REPO_PREFIX="testprefix"
    # export use_cache="n"; export platform="linux/arm64"; export use_squash="n"; export skip_intermediate_push_pull="y";

    if [[ -z "${ORDERED_FOLDERS[*]}" ]]; then
        echo "Error: ORDERED_FOLDERS not set. Cannot run directly without manual setup."
        exit 1
    fi
     if [[ -z "${!SELECTED_FOLDERS_MAP[@]}" ]]; then
        echo "Error: SELECTED_FOLDERS_MAP not set. Cannot run directly without manual setup."
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
# Description: Builds Docker stages based on ORDERED_FOLDERS and SELECTED_FOLDERS_MAP. Updates AVAILABLE_IMAGES in .env.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-095000-BSTAGESREF
