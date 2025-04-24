#!/bin/bash

# Source necessary utilities and helpers
SCRIPT_DIR_BSTAGES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BSTAGES/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BSTAGES/docker_helpers.sh" || { echo "Error: docker_helpers.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BSTAGES/logging.sh" || { echo "Error: logging.sh not found."; exit 1; }

# =========================================================================
# Function: Build selected numbered and other directories
# Relies on: Variables exported by build_prefs.sh (use_cache, platform, etc.)
#            SELECTED_FOLDERS_MAP (associative array from build_order.sh)
#            ORDERED_FOLDERS (array from build_order.sh)
#            SKIP_APPS_LIST (space-separated list from build_prefs.sh)
# Exports:   LAST_SUCCESSFUL_TAG (tag of the final successfully built image)
# Returns: 0 if all selected stages build successfully, 1 otherwise
# =========================================================================
build_selected_stages() {
    echo "=================================================="
    echo "Starting Build Stages..."
    echo "=================================================="

    # Ensure required variables are set (should be sourced from PREFS_FILE by build.sh)
    : "${use_cache?Variable use_cache not set}"
    : "${platform?Variable platform not set}"
    : "${use_squash?Variable use_squash not set}"
    : "${skip_intermediate_push_pull?Variable skip_intermediate_push_pull not set}"
    : "${SELECTED_BASE_IMAGE?Variable SELECTED_BASE_IMAGE not set}"
    : "${DOCKER_USERNAME?Variable DOCKER_USERNAME not set}"
    : "${DOCKER_REPO_PREFIX?Variable DOCKER_REPO_PREFIX not set}"
    # DOCKER_REGISTRY is optional
    # SELECTED_FOLDERS_MAP and ORDERED_FOLDERS should be exported by build_order.sh
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

    # Iterate through the ordered list of folders to build
    for folder_path in "${ORDERED_FOLDERS[@]}"; do
        local folder_name
        folder_name=$(basename "$folder_path")

        # Check if this folder was selected for building
        if [[ -z "${SELECTED_FOLDERS_MAP[$folder_name]}" ]]; then
            echo "Skipping folder (not selected): $folder_name"
            continue
        fi

        # --- Check if app should be skipped ---
        # Heuristic: app name is after first dash, e.g. 01-03-numpy -> numpy
        local app_name="${folder_name#*-}"
        app_name="${app_name%%-*}" # Handle cases like 01-01-00-protobuf_apt -> protobuf_apt
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
            local env_file_path="$(dirname "$SCRIPT_DIR_BSTAGES")/.env"
            if [ -f "$env_file_path" ]; then
                local current_available_images
                # Read the line carefully, handling potential missing line
                current_available_images=$(grep "^AVAILABLE_IMAGES=" "$env_file_path" | head -n 1 | cut -d'=' -f2-) || current_available_images=""

                # Add the new tag if it's not already present (robust check)
                if ! echo ";${current_available_images};" | grep -q ";${LAST_SUCCESSFUL_TAG};"; then
                    local updated_images
                    if [ -z "$current_available_images" ]; then
                        updated_images="$LAST_SUCCESSFUL_TAG"
                    else
                        # Append with semicolon separator
                        updated_images="${current_available_images};${LAST_SUCCESSFUL_TAG}"
                    fi
                    # Use sed with a different delimiter (#) and escape potential special chars in tag for safety
                    local escaped_tag
                    escaped_tag=$(printf '%s\n' "$LAST_SUCCESSFUL_TAG" | sed 's/[&/\]/\\&/g') # Basic escaping for sed
                    local escaped_updated_images
                    escaped_updated_images=$(printf '%s\n' "$updated_images" | sed 's/[&/\]/\\&/g')

                    if grep -q "^AVAILABLE_IMAGES=" "$env_file_path"; then
                         # Update existing line
                         sed -i "s#^AVAILABLE_IMAGES=.*#AVAILABLE_IMAGES=${escaped_updated_images}#" "$env_file_path"
                    else
                         # Add new line if it doesn't exist
                         echo "" >> "$env_file_path" # Ensure newline
                         echo "# Available container images (semicolon-separated)" >> "$env_file_path"
                         echo "AVAILABLE_IMAGES=${escaped_updated_images}" >> "$env_file_path"
                    fi
                    echo "Updated AVAILABLE_IMAGES in $env_file_path" | tee -a "${MAIN_LOG}"
                fi
            fi

        else
            # Build failed
            handle_build_error "$folder_path" "$build_status" # Log error but continue
            build_failed=1
            # Do NOT update LAST_SUCCESSFUL_TAG or current_base_image
            echo "Build failed for stage: $folder_name. Last successful image remains: $LAST_SUCCESSFUL_TAG" | tee -a "${MAIN_LOG}" "${ERROR_LOG}"
            # Optionally, ask user if they want to continue? For now, continue automatically.
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
    # This part is complex and depends on build_order.sh, so direct execution might be limited
    echo "Note: Direct execution requires ORDERED_FOLDERS and SELECTED_FOLDERS_MAP to be set manually."
    # Example setup for testing:
    # export ORDERED_FOLDERS=("/path/to/buildx/build/01-folder" "/path/to/buildx/build/02-folder")
    # declare -A SELECTED_FOLDERS_MAP=( ["01-folder"]=1 ["02-folder"]=1 )

    if [[ -z "${ORDERED_FOLDERS[*]}" ]]; then
        echo "Error: ORDERED_FOLDERS not set. Cannot run directly without setup."
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
# Description: Script to build selected Docker stages in order. Uses helpers for build and logging.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20240806-103000-MODULAR # Updated UUID to match refactor
