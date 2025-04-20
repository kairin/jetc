#!/bin/bash

# COMMIT-TRACKING: UUID-20240802-165200-CONS
# Description: Consolidated commit tracking headers - includes both removing hardcoded FROM lines
#              and implementing dynamic base image tracking via build-arg
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Current directory
# │   └── build.sh               <- THIS FILE
# └── ...                        <- Other project files

# Import utility scripts
SCRIPT_DIR="$(dirname "$0")/scripts"
# Source scripts individually with error checking
source "$SCRIPT_DIR/setup_env.sh" || { echo "Error sourcing setup_env.sh"; exit 1; }
source "$SCRIPT_DIR/docker_utils.sh" || { echo "Error sourcing docker_utils.sh"; exit 1; }
source "$SCRIPT_DIR/setup_buildx.sh" || { echo "Error sourcing setup_buildx.sh"; exit 1; }
source "$SCRIPT_DIR/post_build_menu.sh" || { echo "Error sourcing post_build_menu.sh"; exit 1; }


set -e # Exit immediately if a command exits with a non-zero status (temporarily disabled during builds)

# =========================================================================
# Function to handle build errors but continue with other builds
# =========================================================================
handle_build_error() {
  local folder=$1
  # shellcheck disable=SC2034
  local error_code=$2
  echo "Build process for $folder exited with code $error_code"
  echo "Continuing with next build..."
}

# =========================================================================
# Function to update AVAILABLE_IMAGES in .env
# =========================================================================
update_available_images_in_env() {
    local new_tag="$1"
    local env_file="$(dirname "$0")/.env"

    if [ ! -f "$env_file" ]; then
        echo "Warning: .env file not found at $env_file. Cannot update AVAILABLE_IMAGES."
        return 1
    fi

    # Source the .env file safely to get the current list
    local current_images=""
    if grep -q "^AVAILABLE_IMAGES=" "$env_file"; then
        # shellcheck disable=SC1090
        current_images=$(grep "^AVAILABLE_IMAGES=" "$env_file" | cut -d'=' -f2-)
    fi

    # Check if the tag already exists
    if [[ ";$current_images;" == *";$new_tag;"* ]]; then
        echo "  Tag '$new_tag' already exists in AVAILABLE_IMAGES."
        return 0
    fi

    # Append the new tag
    local updated_images
    if [ -z "$current_images" ]; then
        updated_images="$new_tag"
    else
        updated_images="$current_images;$new_tag"
    fi

    # Update the .env file using sed
    if grep -q "^AVAILABLE_IMAGES=" "$env_file"; then
        # Use a different delimiter for sed in case tags contain slashes
        sed -i "s|^AVAILABLE_IMAGES=.*|AVAILABLE_IMAGES=$updated_images|" "$env_file"
    else
        # If the line doesn't exist, add it
        echo "" >> "$env_file" # Ensure newline before adding
        echo "# Available container images (semicolon-separated)" >> "$env_file"
        echo "AVAILABLE_IMAGES=$updated_images" >> "$env_file"
    fi

    echo "  Updated AVAILABLE_IMAGES in $env_file with tag '$new_tag'."
    return 0
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
# Note: setup_buildx_builder now uses DOCKER_USERNAME from load_env_variables
setup_buildx_builder || exit 1

# Call the function that shows the dialogs
# This function MUST now write selected variables to $PREFS_FILE
echo "Launching user preferences dialog..."
get_user_preferences # Function is defined in setup_env.sh
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


# Arrays to track build status (already declared in setup_env.sh and exported)
# Re-declare locally if export wasn't used or preferred
# declare -a BUILT_TAGS=()
# declare -a ATTEMPTED_TAGS=()
# BUILD_FAILED=0 # Initialized in setup_env.sh

# Initialize the base image for the first build using the user's selection
# This now uses the variable sourced from the temp file
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
    echo "  No specific stages selected, will attempt to build all found numbered stages."
    # If list is empty, map remains empty, effectively selecting none unless logic below changes
fi

# Get all numbered dirs first
mapfile -t all_numbered_dirs < <(find "$BUILD_DIR" -maxdepth 1 -mindepth 1 -type d -name '[0-9]*-*' | sort)
# Filter numbered dirs based on selection (or build all if SELECTED_FOLDERS_LIST was empty initially)
numbered_dirs=()
if [[ ${#selected_folders_map[@]} -gt 0 ]]; then
    for dir in "${all_numbered_dirs[@]}"; do
        basename=$(basename "$dir")
        if [[ -v selected_folders_map[$basename] ]]; then
            numbered_dirs+=("$dir")
        fi
    done
    echo "Filtered numbered stages to build: ${#numbered_dirs[@]}"
elif [[ -z "$SELECTED_FOLDERS_LIST" ]] && [[ ${#all_numbered_dirs[@]} -gt 0 ]]; then
    # If the selection list was explicitly empty (meaning user selected none), numbered_dirs remains empty.
    # If the selection list was empty because the user *intended* to build all (e.g., basic prompt default),
    # then we should populate numbered_dirs here. Let's assume empty list means build all found.
    echo "Building all found numbered stages as no specific selection was made."
    numbered_dirs=("${all_numbered_dirs[@]}")
fi


# Get other dirs (currently not selectable, build logic remains the same)
mapfile -t other_dirs < <(find "$BUILD_DIR" -maxdepth 1 -mindepth 1 -type d ! -name '[0-9]*-*' | sort)

# =========================================================================
# Build Process - Selected Numbered Directories First
# =========================================================================
echo "Starting build process for selected stages..."
# Convert user preferences ('y'/'n') to build command flags/args as needed
# Assuming docker_utils.sh expects 'y' or 'n' for boolean flags
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
      echo "Processing selected numbered directory: $basename ($dir)"
      echo "Using base image: $CURRENT_BASE_IMAGE"
      # Call build_folder_image WITH the current base tag argument AND sourced preferences
      # Pass DOCKER_REPO_PREFIX and DOCKER_REGISTRY as well
      build_folder_image "$dir" "$local_use_cache" "$DOCKER_USERNAME" "$local_platform" "$local_use_squash" "$local_skip_intermediate" "$CURRENT_BASE_IMAGE" "$DOCKER_REPO_PREFIX" "$DOCKER_REGISTRY"

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
      build_folder_image "$dir" "$local_use_cache" "$DOCKER_USERNAME" "$local_platform" "$local_use_squash" "$local_skip_intermediate" "$CURRENT_BASE_IMAGE" "$DOCKER_REPO_PREFIX" "$DOCKER_REGISTRY"

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
# Pre-Tagging Verification - Pull all attempted images to ensure they exist
# =========================================================================
echo "--- Verifying and Pulling All Attempted Images (if needed) ---"
# Only pull if intermediate push/pull was NOT skipped
if [[ "$local_skip_intermediate" != "y" ]]; then
    if [[ "$BUILD_FAILED" -eq 0 ]] && [[ ${#ATTEMPTED_TAGS[@]} -gt 0 ]]; then
        echo "Pulling ${#ATTEMPTED_TAGS[@]} image(s) before final tagging..."
        PULL_ALL_FAILED=0
        for tag in "${ATTEMPTED_TAGS[@]}"; do
            echo "Pulling $tag..."
            # Use docker_utils function if available, otherwise direct command
            if command -v pull_image &> /dev/null; then
                pull_image "$tag" || PULL_ALL_FAILED=1
            else
                docker pull "$tag" || PULL_ALL_FAILED=1 # Basic fallback
            fi
            if [[ $PULL_ALL_FAILED -eq 1 ]]; then
                 echo "Error: Failed to pull image $tag during pre-tagging verification."
                 # Decide whether to break or continue trying others
                 # break # Uncomment to stop on first pull failure
            fi
        done

        if [[ "$PULL_ALL_FAILED" -eq 1 ]]; then
            echo "Error: Failed to pull one or more required images before final tagging. Aborting."
            BUILD_FAILED=1
        else
            echo "All attempted images successfully pulled/refreshed."
        fi
    else
        if [[ "$BUILD_FAILED" -ne 0 ]]; then
            echo "Skipping pre-tagging pull verification due to earlier build failures."
        else
            echo "No images were attempted, skipping pre-tagging pull verification."
        fi
    fi
else
    echo "Skipping pre-tagging pull verification as intermediate push/pull was disabled."
    # Add a verification step here to ensure the FINAL_FOLDER_TAG exists locally
    if [[ -n "$FINAL_FOLDER_TAG" ]] && [[ "$BUILD_FAILED" -eq 0 ]]; then
        echo "Verifying final intermediate image $FINAL_FOLDER_TAG exists locally..."
        # Use docker_utils function if available
        local verify_func="verify_image_exists"
        if ! command -v $verify_func &> /dev/null; then
            # Fallback using docker image inspect, checking exit code
             verify_func() { docker image inspect "$1" &>/dev/null; }
        fi

        if ! $verify_func "$FINAL_FOLDER_TAG"; then
             echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
             echo "Error: Image $FINAL_FOLDER_TAG (needed for final tag) not found locally even though push/pull was skipped."
             echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
             BUILD_FAILED=1
        else
             echo "Image $FINAL_FOLDER_TAG found locally."
        fi
    fi
fi
echo "--------------------------------------------------"


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
    # --- Construct the tag dynamically ---
    # Use sourced DOCKER_USERNAME, DOCKER_REPO_PREFIX, DOCKER_REGISTRY
    local tag_repo="${DOCKER_USERNAME}/${DOCKER_REPO_PREFIX}"
    local tag_prefix=""
    if [[ -n "$DOCKER_REGISTRY" ]]; then
        tag_prefix="${DOCKER_REGISTRY}/"
    fi
    TIMESTAMPED_LATEST_TAG=$(echo "${tag_prefix}${tag_repo}:latest-${CURRENT_DATE_TIME}-1" | tr '[:upper:]' '[:lower:]')
    # --- End tag construction ---

    echo "Attempting to tag $FINAL_FOLDER_TAG as $TIMESTAMPED_LATEST_TAG"

    # Verify base image exists locally before tagging
    echo "Verifying image $FINAL_FOLDER_TAG exists locally before tagging..."
    local verify_func="verify_image_exists"
    if ! command -v $verify_func &> /dev/null; then
        verify_func() { docker image inspect "$1" &>/dev/null; } # Fallback
    fi

    if $verify_func "$FINAL_FOLDER_TAG"; then
        echo "Image $FINAL_FOLDER_TAG found locally. Proceeding with tag."

        # Tag the final timestamped image
        if docker tag "$FINAL_FOLDER_TAG" "$TIMESTAMPED_LATEST_TAG"; then
            echo "Tagged successfully."
             # Push only if local_skip_intermediate is 'n'
            if [[ "$local_skip_intermediate" != "y" ]]; then
                echo "Pushing $TIMESTAMPED_LATEST_TAG"
                if docker push "$TIMESTAMPED_LATEST_TAG"; then
                    echo "Pulling final timestamped tag: $TIMESTAMPED_LATEST_TAG"
                    # Always pull the final timestamped tag to ensure it's the registry version
                    if docker pull "$TIMESTAMPED_LATEST_TAG"; then
                        # Verify final image exists locally
                        echo "Verifying final image $TIMESTAMPED_LATEST_TAG exists locally after pull..."
                        if $verify_func "$TIMESTAMPED_LATEST_TAG"; then
                            echo "Final image $TIMESTAMPED_LATEST_TAG verified locally."
                            BUILT_TAGS+=("$TIMESTAMPED_LATEST_TAG")
                            update_available_images_in_env "$TIMESTAMPED_LATEST_TAG"
                            echo "Successfully created, pushed, and pulled final timestamped tag."
                        else
                            echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
                            echo "Error: Final image $TIMESTAMPED_LATEST_TAG NOT found locally after 'docker pull' succeeded."
                            echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
                            BUILD_FAILED=1
                        fi
                    else
                        echo "Error: Failed to pull final timestamped tag $TIMESTAMPED_LATEST_TAG after push."
                        BUILD_FAILED=1
                    fi
                else
                    echo "Error: Failed to push final timestamped tag $TIMESTAMPED_LATEST_TAG."
                    BUILD_FAILED=1
                fi
            else
                echo "Skipping push/pull for final tag (Build Locally Only selected)."
                # Image should be available locally due to '--load' or direct build
                echo "Verifying final image $TIMESTAMPED_LATEST_TAG exists locally..."
                 if $verify_func "$TIMESTAMPED_LATEST_TAG"; then
                    echo "Final image $TIMESTAMPED_LATEST_TAG verified locally."
                    BUILT_TAGS+=("$TIMESTAMPED_LATEST_TAG")
                    update_available_images_in_env "$TIMESTAMPED_LATEST_TAG"
                    echo "Successfully created and verified final timestamped tag locally."
                else
                    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
                    echo "Error: Final image $TIMESTAMPED_LATEST_TAG NOT found locally after tagging (and push/pull skipped)."
                    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
                    BUILD_FAILED=1
                fi
            fi
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
echo "(Image pulling and verification now happens during build process)"

# Run the very last successfully built & timestamped image (optional)
if [[ -n "$TIMESTAMPED_LATEST_TAG" ]] && [[ "$BUILD_FAILED" -eq 0 ]]; then
    # Check if the timestamped tag is in the BUILT_TAGS array (validation)
    tag_exists=0
    for t in "${BUILT_TAGS[@]}"; do
        [[ "$t" == "$TIMESTAMPED_LATEST_TAG" ]] && { tag_exists=1; break; }
    done

    if [[ "$tag_exists" -eq 1 ]]; then
        # Ensure show_post_build_menu exists before calling
        if command -v show_post_build_menu &> /dev/null; then
            show_post_build_menu "$TIMESTAMPED_LATEST_TAG"
        else
            echo "Warning: show_post_build_menu function not found."
        fi
    else
        echo "Skipping post-build options because the final tag was not successfully processed."
    fi
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
     local verify_func="verify_image_exists"
     if ! command -v $verify_func &> /dev/null; then
        verify_func() { docker image inspect "$1" &>/dev/null; } # Fallback
     fi

    for tag in "${BUILT_TAGS[@]}"; do
        echo -n "Verifying $tag... "
        if $verify_func "$tag"; then
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
            # Update DEFAULT_BASE_IMAGE
            if grep -q "^DEFAULT_BASE_IMAGE=" "$ENV_FILE"; then
                # Use different sed delimiter for safety
                sed -i "s|^DEFAULT_BASE_IMAGE=.*|DEFAULT_BASE_IMAGE=$LATEST_SUCCESSFUL_TAG_FOR_DEFAULT|" "$ENV_FILE"
            else
                echo "" >> "$ENV_FILE"; echo "# Default base image for builds" >> "$ENV_FILE"; echo "DEFAULT_BASE_IMAGE=$LATEST_SUCCESSFUL_TAG_FOR_DEFAULT" >> "$ENV_FILE"
            fi
            echo "  Set $LATEST_SUCCESSFUL_TAG_FOR_DEFAULT as the new default base image in $ENV_FILE"

            # Update AVAILABLE_IMAGES (already done during build, but ensure consistency)
            update_available_images_in_env "$LATEST_SUCCESSFUL_TAG_FOR_DEFAULT"

            # Save Docker user/prefix back to .env defaults (optional, uncomment if desired)
            # if grep -q "^DOCKER_USERNAME=" "$ENV_FILE"; then sed -i "s|^DOCKER_USERNAME=.*|DOCKER_USERNAME=$DOCKER_USERNAME|" "$ENV_FILE"; else echo "DOCKER_USERNAME=$DOCKER_USERNAME" >> "$ENV_FILE"; fi
            # if grep -q "^DOCKER_REPO_PREFIX=" "$ENV_FILE"; then sed -i "s|^DOCKER_REPO_PREFIX=.*|DOCKER_REPO_PREFIX=$DOCKER_REPO_PREFIX|" "$ENV_FILE"; else echo "DOCKER_REPO_PREFIX=$DOCKER_REPO_PREFIX" >> "$ENV_FILE"; fi
            # if grep -q "^DOCKER_REGISTRY=" "$ENV_FILE"; then sed -i "s|^DOCKER_REGISTRY=.*|DOCKER_REGISTRY=$DOCKER_REGISTRY|" "$ENV_FILE"; else echo "DOCKER_REGISTRY=$DOCKER_REGISTRY" >> "$ENV_FILE"; fi

        else
             echo "  No successfully processed final tag found to set as default base image."
        fi
        echo "Successfully updated .env with build results."
    else
        echo "Warning: .env file not found, cannot save default base image for future use."
    fi

    echo "Build process completed successfully!"
    echo "--------------------------------------------------"
    exit 0  # Exit with success code
fi