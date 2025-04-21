#!/bin/bash

# Import utility scripts
SCRIPT_DIR="$(dirname "$0")/scripts"
# Source scripts individually with error checking
source "$SCRIPT_DIR/utils.sh" || { echo "Error sourcing utils.sh"; exit 1; }
source "$SCRIPT_DIR/docker_helpers.sh" || { echo "Error sourcing docker_helpers.sh"; exit 1; }
source "$SCRIPT_DIR/build_ui.sh" || { echo "Error sourcing build_ui.sh"; exit 1; }
source "$SCRIPT_DIR/verification.sh" || { echo "Error sourcing verification.sh"; exit 1; }
source "$SCRIPT_DIR/logging.sh" || { echo "Error sourcing logging.sh"; exit 1; }

set -e # Exit immediately if a command exits with a non-zero status (temporarily disabled during builds)

# Initialize logging
BUILD_ID=$(date +"%Y%m%d-%H%M%S")
LOGS_DIR="$(dirname "$0")/logs"
init_logging "$LOGS_DIR" "$BUILD_ID"

# =========================================================================
# Function to handle build errors but continue with other builds
# =========================================================================
handle_build_error() {
  local folder=$1
  # shellcheck disable=SC2034
  local error_code=$2
  echo "Build process for $folder exited with code $error_code" | tee -a "${ERROR_LOG}"
  echo "Continuing with next build..." | tee -a "${MAIN_LOG}"
}

# =========================================================================
# Main Build Process
# =========================================================================

# Define the temporary file path for preferences
PREFS_FILE="/tmp/build_prefs.sh"

# Setup basic build environment (like ARCH, PLATFORM, DATE)
setup_build_environment || exit 1

# Load initial .env variables (might be overridden by user preferences)
load_env_variables || exit 1

# Setup builder *before* getting preferences that might depend on it
setup_buildx_builder || exit 1

# Call the function that shows the dialogs
# This function MUST now write selected variables to $PREFS_FILE
echo "Launching user preferences dialog..."
get_user_preferences # Function is defined in build_ui.sh
prefs_exit_code=$?
echo "Preferences dialog finished with exit code: $prefs_exit_code"

if [[ $prefs_exit_code -ne 0 ]]; then
    echo "User cancelled or an error occurred in preferences dialog. Exiting."
    # Clean up temp file if it exists
    [ -f "$PREFS_FILE" ] && rm -f "$PREFS_FILE"
    exit 1
fi

# Source the preferences from the temporary file created by get_user_preferences
if [ -f "$PREFS_FILE" ]; then
    echo "Sourcing preferences from $PREFS_FILE..."
    # shellcheck disable=SC1090
    source "$PREFS_FILE"
    rm -f "$PREFS_FILE" # Clean up the temp file
    echo "Preferences sourced."
    # --- Debugging Start ---
    echo "DEBUG: Sourced SELECTED_FOLDERS_LIST in build.sh: '$SELECTED_FOLDERS_LIST'"
    # --- Debugging End ---
else
    echo "Error: Preferences file $PREFS_FILE not found. Cannot proceed."
    exit 1
fi

# --- Verification Section ---
echo "Verifying sourced preferences:"
echo "  DOCKER_USERNAME: ${DOCKER_USERNAME}"
echo "  DOCKER_REPO_PREFIX: ${DOCKER_REPO_PREFIX}"
echo "  DOCKER_REGISTRY: ${DOCKER_REGISTRY}"
echo "  use_cache: ${use_cache}"
echo "  use_squash: ${use_squash}"
echo "  skip_intermediate_push_pull: ${skip_intermediate_push_pull}"
echo "  SELECTED_BASE_IMAGE: ${SELECTED_BASE_IMAGE}"
echo "  PLATFORM: ${PLATFORM}" # Should be set by setup_build_env or prefs
echo "  use_builder: ${use_builder}" # Added verification
echo "  SELECTED_FOLDERS_LIST: ${SELECTED_FOLDERS_LIST:-<All>}" # Verify selected folders
# --- End Verification ---

# Initialize the base image for the first build using the user's selection
CURRENT_BASE_IMAGE="${SELECTED_BASE_IMAGE}"

# Validate that SELECTED_BASE_IMAGE is now populated
if [[ -z "$SELECTED_BASE_IMAGE" ]]; then
    echo "Error: SELECTED_BASE_IMAGE is still empty after sourcing preferences. Exiting."
    exit 1
fi
echo "Initial base image set to: $CURRENT_BASE_IMAGE"

# Ensure the build process continues even if individual builds fail
set +e # Don't exit on errors during builds

# =========================================================================
# Determine Build Order and Prepare Selected Folders Map
# =========================================================================

echo "Determining build order and filtering selected stages..."
BUILD_DIR="build"
# Check if BUILD_DIR exists
if [ ! -d "$BUILD_DIR" ]; then
    echo "Error: Build directory '$BUILD_DIR' not found."
    exit 1
fi

# Create an associative array for quick lookup of selected folders
declare -A selected_folders_map
if [[ -n "$SELECTED_FOLDERS_LIST" ]]; then
    for folder_name in $SELECTED_FOLDERS_LIST; do
        selected_folders_map["$folder_name"]=1
        echo "  Will build stage: $folder_name"
    done
else
    # If the list is empty, it means the user deselected all items.
    echo "  No specific stages selected by user. No numbered stages will be built."
    # The map remains empty, so the filtering logic below will result in an empty numbered_dirs array.
fi

# Get all numbered dirs first
mapfile -t all_numbered_dirs < <(find "$BUILD_DIR" -maxdepth 1 -mindepth 1 -type d -name '[0-9]*-*' | sort)
# Filter numbered dirs based on selection
numbered_dirs=()
# Only filter if the map is not empty (i.e., user selected at least one)
if [[ ${#selected_folders_map[@]} -gt 0 ]]; then
    for dir in "${all_numbered_dirs[@]}"; do
        basename=$(basename "$dir")
        if [[ -v selected_folders_map[$basename] ]]; then
            numbered_dirs+=("$dir")
        fi
    done
    echo "Filtered numbered stages to build: ${#numbered_dirs[@]}"
# If the map is empty (user selected none), numbered_dirs remains empty.
elif [[ -z "$SELECTED_FOLDERS_LIST" ]]; then
     echo "No numbered stages were selected, skipping numbered builds."
fi


# Get other dirs (currently not selectable, build logic remains the same)
mapfile -t other_dirs < <(find "$BUILD_DIR" -maxdepth 1 -mindepth 1 -type d ! -name '[0-9]*-*' | sort)

# =========================================================================
# Build Process - Selected Numbered Directories First
# =========================================================================
echo "Starting build process for selected stages..."
# Convert user preferences ('y'/'n') to build command flags/args as needed
local_use_cache="$use_cache" # Already 'y' or 'n' from prefs
local_use_squash="$use_squash" # Already 'y' or 'n' from prefs
local_skip_intermediate="$skip_intermediate_push_pull" # Already 'y' or 'n' from prefs

# Platform should be set correctly by setup_build_environment
local_platform="$PLATFORM"

# 1. Build Numbered Directories in Order (sequential dependencies)
echo "--- Building Selected Numbered Directories ---"
if [[ ${#numbered_dirs[@]} -eq 0 ]]; then
    echo "No numbered directories selected or found to build in $BUILD_DIR."
else
    for dir in "${numbered_dirs[@]}"; do
      # The loop now only iterates over selected directories
      local basename=$(basename "$dir")
      set_stage "$basename"
      echo "Processing selected numbered directory: $basename ($dir)"
      echo "Using base image: $CURRENT_BASE_IMAGE"
      # Call build_folder_image WITH the current base tag argument AND sourced preferences
      # Pass DOCKER_REPO_PREFIX and DOCKER_REGISTRY as well
      log_command build_folder_image "$dir" "$local_use_cache" "$local_platform" "$local_use_squash" "$local_skip_intermediate" "$CURRENT_BASE_IMAGE" "$DOCKER_USERNAME" "$DOCKER_REPO_PREFIX" "$DOCKER_REGISTRY"

      build_status=$?
      # Assuming build_folder_image exports 'fixed_tag' even on failure for logging
      # shellcheck disable=SC2154 # fixed_tag might be exported by build_folder_image
      ATTEMPTED_TAGS+=("$fixed_tag") # Add the tag to attempted tags

      if [[ $build_status -eq 0 ]]; then
          BUILT_TAGS+=("$fixed_tag")
          update_available_images_in_env "$fixed_tag"
          CURRENT_BASE_IMAGE="$fixed_tag"
          FINAL_FOLDER_TAG="$fixed_tag" # Keep track of the last successful tag
          echo "Successfully built/pushed/pulled numbered image: $fixed_tag"
          echo "Next base image will be: $CURRENT_BASE_IMAGE"
      else
          echo "Build, push or pull failed for $dir. Subsequent dependent builds might fail."
          handle_build_error "$dir" $build_status
          BUILD_FAILED=1
          # Do NOT update CURRENT_BASE_IMAGE on failure
      fi
    done
fi

# 2. Build Other (Non-Numbered) Directories
echo "--- Building Other Directories ---"
if [[ ${#other_dirs[@]} -eq 0 ]]; then
    echo "No non-numbered directories found in $BUILD_DIR."
elif [[ "$BUILD_FAILED" -ne 0 ]]; then
    echo "Skipping other directories due to previous build failures."
else
    echo "Building non-numbered directories using base image: $CURRENT_BASE_IMAGE"
    for dir in "${other_dirs[@]}"; do
      echo "Processing other directory: $dir"
      # Call build_folder_image WITH the current base tag argument AND sourced preferences
      log_command build_folder_image "$dir" "$local_use_cache" "$local_platform" "$local_use_squash" "$local_skip_intermediate" "$CURRENT_BASE_IMAGE" "$DOCKER_USERNAME" "$DOCKER_REPO_PREFIX" "$DOCKER_REGISTRY"

      build_status=$?
      # shellcheck disable=SC2154 # fixed_tag might be exported by build_folder_image
      ATTEMPTED_TAGS+=("$fixed_tag") # Add the tag to attempted tags

      if [[ $build_status -eq 0 ]]; then
          BUILT_TAGS+=("$fixed_tag")
          update_available_images_in_env "$fixed_tag"
          CURRENT_BASE_IMAGE="$fixed_tag"
          FINAL_FOLDER_TAG="$fixed_tag" # Update last successful tag
          echo "Successfully built/pushed/pulled other image: $fixed_tag"
          echo "Next base image (if any) will be: $CURRENT_BASE_IMAGE"
      else
          echo "Build, push or pull failed for $dir."
          handle_build_error "$dir" $build_status
          BUILD_FAILED=1
          # Do NOT update CURRENT_BASE_IMAGE on failure
      fi
    done
fi

echo "--------------------------------------------------"
echo "Folder build process complete!"

# =========================================================================
# Create Final Timestamped Tag
# =========================================================================
echo "--- Creating Final Timestamped Tag ---"
# Ensure CURRENT_DATE_TIME is set (should be handled by setup_env)
if [[ -z "$CURRENT_DATE_TIME" ]]; then
    CURRENT_DATE_TIME=$(date +%Y%m%d-%H%M%S)
    echo "Warning: CURRENT_DATE_TIME not set, using current time: $CURRENT_DATE_TIME"
fi

if [[ -n "$FINAL_FOLDER_TAG" ]] && [[ "$BUILD_FAILED" -eq 0 ]]; then
    # Generate the timestamped tag
    generate_timestamped_tag "$DOCKER_USERNAME" "$DOCKER_REPO_PREFIX" "$DOCKER_REGISTRY" "$CURRENT_DATE_TIME"
    TIMESTAMPED_LATEST_TAG="$timestamped_tag" # Use the exported variable from the function call

    echo "Attempting to tag $FINAL_FOLDER_TAG as $TIMESTAMPED_LATEST_TAG"

    # Verify base image exists locally before tagging
    echo "Verifying image $FINAL_FOLDER_TAG exists locally before tagging..."
    if verify_image_exists "$FINAL_FOLDER_TAG"; then
        echo "Image $FINAL_FOLDER_TAG found locally. Proceeding with tag."

        # Tag the final timestamped image
        if docker tag "$FINAL_FOLDER_TAG" "$TIMESTAMPED_LATEST_TAG"; then
            echo "Tagged successfully."
            # Push only if local_skip_intermediate is 'n'
            if [[ "$local_skip_intermediate" != "y" ]]; then
                echo "Pushing $TIMESTAMPED_LATEST_TAG"
                docker push "$TIMESTAMPED_LATEST_TAG"
            else
                echo "Skipping push for $TIMESTAMPED_LATEST_TAG (local build only)"
            fi
            # Add the tag to our tracking arrays
            BUILT_TAGS+=("$TIMESTAMPED_LATEST_TAG")
            update_available_images_in_env "$TIMESTAMPED_LATEST_TAG"
        else
            echo "Error: Failed to tag $FINAL_FOLDER_TAG as $TIMESTAMPED_LATEST_TAG."
            BUILD_FAILED=1
        fi
    else
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "Error: Image $FINAL_FOLDER_TAG not found locally right before tagging."
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        BUILD_FAILED=1
    fi
else
    if [[ "$BUILD_FAILED" -ne 0 ]]; then
        echo "Skipping final timestamped tag creation due to previous errors."
    else
        echo "Skipping final timestamped tag creation as no base image was successfully built/pushed/pulled."
    fi
fi

echo "--------------------------------------------------"
echo "Build, Push, Pull, and Tagging process complete!"
echo "Total images successfully processed: ${#BUILT_TAGS[@]}"
if [[ "$BUILD_FAILED" -ne 0 ]]; then
    echo "Warning: One or more steps failed. See logs above."
fi
echo "--------------------------------------------------"

# =========================================================================
# Post-Build Steps - Options for final image
# =========================================================================

# Run the very last successfully built & timestamped image (optional)
if [[ -n "$TIMESTAMPED_LATEST_TAG" ]] && [[ "$BUILD_FAILED" -eq 0 ]]; then
    # Show post-build menu for the final image
    show_post_build_menu "$TIMESTAMPED_LATEST_TAG"
else
    echo "No final image tag recorded or build failed, skipping further operations."
fi

# =========================================================================
# Final Image Verification - Check Successfully Processed Images
# =========================================================================
echo "--------------------------------------------------"
# Verify against BUILT_TAGS to see if successfully processed images are present
echo "--- Verifying all SUCCESSFULLY PROCESSED images exist locally ---"
VERIFICATION_FAILED=0
# Use BUILT_TAGS here
if [[ ${#BUILT_TAGS[@]} -gt 0 ]]; then
    echo "Checking ${#BUILT_TAGS[@]} image(s) recorded as successful:"
    for tag in "${BUILT_TAGS[@]}"; do
        echo -n "Verifying $tag... "
        if verify_image_exists "$tag"; then
            echo "OK"
        else
            echo "MISSING!"
            echo "Error: Image '$tag', which successfully completed build/push/pull/verify earlier, was not found locally at final check."
            VERIFICATION_FAILED=1
        fi
    done

    if [[ "$VERIFICATION_FAILED" -eq 1 ]]; then
        echo "Error: One or more successfully processed images were missing locally during final check."
        # Ensure BUILD_FAILED reflects this verification failure
        if [[ "$BUILD_FAILED" -eq 0 ]]; then
           BUILD_FAILED=1 # Set to 1 if it was previously 0
           echo "(Marking build as failed due to final verification failure)"
        fi
    else
        echo "All successfully processed images verified successfully locally during final check."
    fi
else
    echo "No images were recorded as successfully processed, skipping final verification."
fi

# =========================================================================
# Script Completion
# =========================================================================
echo "--------------------------------------------------"
# Use the BUILD_FAILED flag set throughout the script
if [[ "$BUILD_FAILED" -ne 0 ]]; then
    echo "Script finished with one or more errors."
    echo "--------------------------------------------------"
    exit 1  # Exit with failure code
else
    # Update .env with the latest successful build as the new default base image
    echo "Updating .env with latest successful build..."
    ENV_FILE="$(dirname "$0")/.env"

    if [ -f "$ENV_FILE" ]; then
        LATEST_SUCCESSFUL_TAG_FOR_DEFAULT=""
        # Check if the timestamped tag was successfully processed (exists in BUILT_TAGS)
        tag_exists=0
        if [[ -n "$TIMESTAMPED_LATEST_TAG" ]]; then
            for t in "${BUILT_TAGS[@]}"; do
                [[ "$t" == "$TIMESTAMPED_LATEST_TAG" ]] && { tag_exists=1; break; }
            done
            [[ "$tag_exists" -eq 1 ]] && LATEST_SUCCESSFUL_TAG_FOR_DEFAULT="$TIMESTAMPED_LATEST_TAG"
        fi

        # Fallback to the last folder tag if timestamped tag failed or wasn't created, AND was successful
        if [[ -z "$LATEST_SUCCESSFUL_TAG_FOR_DEFAULT" ]] && [[ -n "$FINAL_FOLDER_TAG" ]]; then
             tag_exists=0
             for t in "${BUILT_TAGS[@]}"; do
                 [[ "$t" == "$FINAL_FOLDER_TAG" ]] && { tag_exists=1; break; }
             done
             [[ "$tag_exists" -eq 1 ]] && LATEST_SUCCESSFUL_TAG_FOR_DEFAULT="$FINAL_FOLDER_TAG"
        fi

        if [[ -n "$LATEST_SUCCESSFUL_TAG_FOR_DEFAULT" ]]; then
            # Update DEFAULT_BASE_IMAGE in .env file
            update_env_file "$DOCKER_USERNAME" "$DOCKER_REGISTRY" "$DOCKER_REPO_PREFIX" "$LATEST_SUCCESSFUL_TAG_FOR_DEFAULT"
            echo "Set $LATEST_SUCCESSFUL_TAG_FOR_DEFAULT as the new default base image in $ENV_FILE"
        else
            echo "No successfully processed final tag found to set as default base image."
        fi
    else
        echo "Warning: .env file not found, cannot save default base image for future use."
    fi

    echo "Build process completed successfully!"
    echo "--------------------------------------------------"
    exit 0  # Exit with success code
fi

# COMMIT-TRACKING: UUID-20250421-020700-REFA
generate_error_summary

# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Current directory
# │   └── build.sh               <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Main build orchestrator for Jetson container buildx system. Modular, interactive, and tracks all build stages and tags.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250422-064000-BLDX