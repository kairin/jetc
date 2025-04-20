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
source "$SCRIPT_DIR/docker_utils.sh"
source "$SCRIPT_DIR/setup_env.sh"
source "$SCRIPT_DIR/setup_buildx.sh"
source "$SCRIPT_DIR/post_build_menu.sh"

set -e  # Exit immediately if a command exits with a non-zero status

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

# Setup environment and buildx
setup_build_environment || exit 1 # Note: DEFAULT_BASE_IMAGE and LATEST_SUCCESSFUL_NUMBERED_TAG removed from setup_env.sh
load_env_variables || exit 1
setup_buildx_builder || exit 1
get_user_preferences || exit 1 # This function should export the chosen base image tag, e.g., as SELECTED_BASE_IMAGE

# Arrays to track build status
declare -a BUILT_TAGS=()
declare -a ATTEMPTED_TAGS=() # Keep this to track attempts for final verification

# Initialize the base image for the first build using the user's selection
# Ensure the variable name matches the one exported by get_user_preferences
CURRENT_BASE_IMAGE="${SELECTED_BASE_IMAGE}"
if [[ -z "$CURRENT_BASE_IMAGE" ]]; then
    echo "Error: No base image was selected or determined (SELECTED_BASE_IMAGE is empty). Exiting."
    exit 1
fi
echo "Initial base image set to: $CURRENT_BASE_IMAGE"

# Ensure the build process continues even if individual builds fail
set +e  # Don't exit on errors during builds

# =========================================================================
# Determine Build Order
# =========================================================================

echo "Determining build order..."
BUILD_DIR="build"
mapfile -t numbered_dirs < <(find "$BUILD_DIR" -maxdepth 1 -mindepth 1 -type d -name '[0-9]*-*' | sort)
mapfile -t other_dirs < <(find "$BUILD_DIR" -maxdepth 1 -mindepth 1 -type d ! -name '[0-9]*-*' | sort)

# =========================================================================
# Build Process - Numbered Directories First
# =========================================================================
echo "Starting build process..."
# 1. Build Numbered Directories in Order (sequential dependencies)
echo "--- Building Numbered Directories ---"
if [[ ${#numbered_dirs[@]} -eq 0 ]]; then
    echo "No numbered directories found in $BUILD_DIR."
else
    for dir in "${numbered_dirs[@]}"; do
      echo "Processing numbered directory: $dir"
      echo "Using base image: $CURRENT_BASE_IMAGE"
      # Call build_folder_image WITH the current base tag argument
      # Note: docker_utils.sh is modified to accept base tag parameter.
      build_folder_image "$dir" "$use_cache" "$DOCKER_USERNAME" "$PLATFORM" "$use_squash" "$skip_intermediate_push_pull" "$CURRENT_BASE_IMAGE"
      # shellcheck disable=SC2044
      local build_status=$?

      # Note: $fixed_tag is set by build_folder_image regardless of success/failure
      ATTEMPTED_TAGS+=("$fixed_tag") # Add the tag to attempted tags

      if [[ $build_status -eq 0 ]]; then
          # Add to BUILT_TAGS array
          BUILT_TAGS+=("$fixed_tag")
          # Update AVAILABLE_IMAGES in .env
          update_available_images_in_env "$fixed_tag"
          # Update CURRENT_BASE_IMAGE to the tag just built for the next iteration
          CURRENT_BASE_IMAGE="$fixed_tag"
          # Keep track of the last successful tag for the final timestamped tag
          FINAL_FOLDER_TAG="$fixed_tag"
          echo "Successfully built, pushed, and pulled numbered image: $fixed_tag"
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
    # Use the last successful base image from the numbered sequence
    echo "Building non-numbered directories using base image: $CURRENT_BASE_IMAGE"
    for dir in "${other_dirs[@]}"; do
      echo "Processing other directory: $dir"
      # Call build_folder_image WITH the current base tag argument
      build_folder_image "$dir" "$use_cache" "$DOCKER_USERNAME" "$PLATFORM" "$use_squash" "$skip_intermediate_push_pull" "$CURRENT_BASE_IMAGE"
      # shellcheck disable=SC2044
      local build_status=$?

      ATTEMPTED_TAGS+=("$fixed_tag") # Add the tag to attempted tags

      if [[ $build_status -eq 0 ]]; then
          BUILT_TAGS+=("$fixed_tag")
          # Update AVAILABLE_IMAGES in .env
          update_available_images_in_env "$fixed_tag" 
          # Update CURRENT_BASE_IMAGE and FINAL_FOLDER_TAG for potential subsequent non-numbered builds
          CURRENT_BASE_IMAGE="$fixed_tag"
          FINAL_FOLDER_TAG="$fixed_tag"
          echo "Successfully built, pushed, and pulled other image: $fixed_tag"
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
if [[ "$skip_intermediate_push_pull" != "y" ]]; then
    if [[ "$BUILD_FAILED" -eq 0 ]] && [[ ${#ATTEMPTED_TAGS[@]} -gt 0 ]]; then
        echo "Pulling ${#ATTEMPTED_TAGS[@]} image(s) before final tagging..."
        PULL_ALL_FAILED=0
        for tag in "${ATTEMPTED_TAGS[@]}"; do
            echo "Pulling $tag..."
            # shellcheck disable=SC2044
            docker pull "$tag" || true # Ignore pull errors here, as they might be expected
            if [[ $? -ne 0 ]]; then
                echo "Error: Failed to pull image $tag during pre-tagging verification."
                PULL_ALL_FAILED=1
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
        if ! verify_image_exists "$FINAL_FOLDER_TAG"; then
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
if [[ -n "$FINAL_FOLDER_TAG" ]] && [[ "$BUILD_FAILED" -eq 0 ]]; then
    # --- Construct the tag dynamically ---
    local tag_repo="${DOCKER_USERNAME}/${DOCKER_REPO_PREFIX}"
    local tag_prefix=""
    if [[ -n "$DOCKER_REGISTRY" ]]; then
        tag_prefix="${DOCKER_REGISTRY}/"
    fi
    TIMESTAMPED_LATEST_TAG=$(echo "${tag_prefix}${tag_repo}:latest-${CURRENT_DATE_TIME}-1" | tr '[:upper:]' '[:lower:]')
    # --- End tag construction ---

    echo "Attempting to tag $FINAL_FOLDER_TAG as $TIMESTAMPED_LATEST_TAG"

    # Verify base image exists locally before tagging (redundant if pre-tagging verification passed, but safe)
    echo "Verifying image $FINAL_FOLDER_TAG exists locally before tagging..."
    if verify_image_exists "$FINAL_FOLDER_TAG"; then
        echo "Image $FINAL_FOLDER_TAG found locally. Proceeding with tag."

        # Tag the final timestamped image
        # shellcheck disable=SC2044
        if docker tag "$FINAL_FOLDER_TAG" "$TIMESTAMPED_LATEST_TAG"; then
            echo "Pushing $TIMESTAMPED_LATEST_TAG"
            # Always push the final timestamped tag
            # shellcheck disable=SC2044
            if docker push "$TIMESTAMPED_LATEST_TAG"; then
                echo "Pulling final timestamped tag: $TIMESTAMPED_LATEST_TAG"
                # Always pull the final timestamped tag to ensure it's the registry version
                # shellcheck disable=SC2044
                docker pull "$TIMESTAMPED_LATEST_TAG"
                if [[ $? -eq 0 ]]; then
                    # Verify final image exists locally
                    echo "Verifying final image $TIMESTAMPED_LATEST_TAG exists locally after pull..."
                    if verify_image_exists "$TIMESTAMPED_LATEST_TAG"; then
                        echo "Final image $TIMESTAMPED_LATEST_TAG verified locally."
                        BUILT_TAGS+=("$TIMESTAMPED_LATEST_TAG")
                        # Update AVAILABLE_IMAGES in .env for the final timestamped tag
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
            echo "Error: Failed to tag $FINAL_FOLDER_TAG as $TIMESTAMPED_LATEST_TAG."
            BUILD_FAILED=1
        fi
    else
        # This error case should ideally be caught by the pre-tagging verification now
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
echo "Total images successfully built/pushed/pulled/verified: ${#BUILT_TAGS[@]}"
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
        show_post_build_menu "$TIMESTAMPED_LATEST_TAG"
    else
        echo "Skipping options because the final tag was not successfully processed."
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
    for tag in "${BUILT_TAGS[@]}"; do
        echo -n "Verifying $tag... "
        # shellcheck disable=SC2044
        if docker image inspect "$tag" &>/dev/null; then
            echo "OK"
        else
            echo "MISSING!"
            # This error is more significant now, as this image *should* exist
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
    # Message remains relevant if BUILT_TAGS is empty
    echo "No images were recorded as successfully built/pushed/pulled/verified, skipping final verification."
fi

# =========================================================================
# Script Completion
# =========================================================================
echo "--------------------------------------------------"
if [[ "$BUILD_FAILED" -ne 0 ]]; then
    echo "Script finished with one or more errors."
    echo "--------------------------------------------------"
    exit 1  # Exit with failure code
else
    # Update .env with the latest successful build as the new default base image
    # The AVAILABLE_IMAGES update is now handled within the build loops and final tagging
    echo "Updating .env with latest successful build..."
    ENV_FILE="$(dirname "$0")/.env"

    if [ -f "$ENV_FILE" ]; then
        # Set the latest successful build (timestamped tag if available, otherwise last folder tag) as the new default base image
        LATEST_SUCCESSFUL_TAG_FOR_DEFAULT=""
        if [[ -n "$TIMESTAMPED_LATEST_TAG" ]]; then
             # Check if timestamped tag is in BUILT_TAGS (meaning it was successfully processed)
             tag_exists=0
             for t in "${BUILT_TAGS[@]}"; do
                 [[ "$t" == "$TIMESTAMPED_LATEST_TAG" ]] && { tag_exists=1; break; }
             done
             if [[ "$tag_exists" -eq 1 ]]; then
                 LATEST_SUCCESSFUL_TAG_FOR_DEFAULT="$TIMESTAMPED_LATEST_TAG"
             fi
        elif [[ -n "$FINAL_FOLDER_TAG" ]]; then
             # Fallback to the last folder tag if timestamped tag wasn't created or failed
             tag_exists=0
             for t in "${BUILT_TAGS[@]}"; do
                 [[ "$t" == "$FINAL_FOLDER_TAG" ]] && { tag_exists=1; break; }
             done
             if [[ "$tag_exists" -eq 1 ]]; then
                 LATEST_SUCCESSFUL_TAG_FOR_DEFAULT="$FINAL_FOLDER_TAG"
             fi
        fi

        if [[ -n "$LATEST_SUCCESSFUL_TAG_FOR_DEFAULT" ]]; then
            if grep -q "^DEFAULT_BASE_IMAGE=" "$ENV_FILE"; then
                # Replace existing line
                # shellcheck disable=SC2001
                sed -i "s|^DEFAULT_BASE_IMAGE=.*|DEFAULT_BASE_IMAGE=$LATEST_SUCCESSFUL_TAG_FOR_DEFAULT|" "$ENV_FILE"
            else
                # Add new line
                echo "" >> "$ENV_FILE" # Ensure newline
                echo "# Default base image for builds" >> "$ENV_FILE"
                echo "DEFAULT_BASE_IMAGE=$LATEST_SUCCESSFUL_TAG_FOR_DEFAULT" >> "$ENV_FILE"
            fi
            echo "  Set $LATEST_SUCCESSFUL_TAG_FOR_DEFAULT as the new default base image in $ENV_FILE"
        else
             echo "  No successfully processed final tag found to set as default base image."
        fi

        echo "Successfully updated .env with build results (AVAILABLE_IMAGES updated during build)."
    else
        echo "Warning: .env file not found, cannot save default base image for future use."
    fi

    echo "Build, push, pull, tag, verification, and run processes completed successfully!"
    echo "--------------------------------------------------"
    exit 0  # Exit with success code
fi