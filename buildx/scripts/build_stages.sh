#!/bin/bash
echo "Starting build process for selected stages..."

# Remove the use of `local` outside a function
use_cache="$use_cache"
use_squash="$use_squash"
skip_intermediate_push_pull="$skip_intermediate_push_pull"
platform="$PLATFORM"

CURRENT_BASE_IMAGE="${SELECTED_BASE_IMAGE}"
if [[ -z "$SELECTED_BASE_IMAGE" ]]; then
    echo "Error: SELECTED_BASE_IMAGE is still empty after sourcing preferences. Exiting."
    exit 1
fi
echo "Initial base image set to: $CURRENT_BASE_IMAGE"

# Define the `update_available_images_in_env` function
update_available_images_in_env() {
    local new_image="$1"
    if [ -f "$ENV_FILE" ]; then
        if grep -q "^AVAILABLE_IMAGES=" "$ENV_FILE"; then
            sed -i "s|^AVAILABLE_IMAGES=.*|&;$new_image|" "$ENV_FILE"
        else
            echo "AVAILABLE_IMAGES=$new_image" >> "$ENV_FILE"
        fi
    fi
}

echo "--- Building Selected Numbered Directories ---"
if [[ ${#numbered_dirs[@]} -eq 0 ]]; then
    echo "No numbered directories selected or found to build in $BUILD_DIR."
else
    for dir in "${numbered_dirs[@]}"; do
        local basename=$(basename "$dir")
        set_stage "$basename"
        echo "Processing selected numbered directory: $basename ($dir)"
        echo "Using base image: $CURRENT_BASE_IMAGE"
        log_command build_folder_image "$dir" "$use_cache" "$platform" "$use_squash" "$skip_intermediate_push_pull" "$CURRENT_BASE_IMAGE" "$DOCKER_USERNAME" "$DOCKER_REPO_PREFIX" "$DOCKER_REGISTRY"
        build_status=$?
        ATTEMPTED_TAGS+=("$fixed_tag")
        if [[ $build_status -eq 0 ]]; then
            BUILT_TAGS+=("$fixed_tag")
            update_available_images_in_env "$fixed_tag"
            CURRENT_BASE_IMAGE="$fixed_tag"
            FINAL_FOLDER_TAG="$fixed_tag"
            echo "Successfully built/pushed/pulled numbered image: $fixed_tag"
            echo "Next base image will be: $CURRENT_BASE_IMAGE"
        else
            echo "Build, push or pull failed for $dir. Subsequent dependent builds might fail."
            handle_build_error "$dir" $build_status
            BUILD_FAILED=1
        fi
    done
fi

echo "--- Building Other Directories ---"
if [[ ${#other_dirs[@]} -eq 0 ]]; then
    echo "No non-numbered directories found in $BUILD_DIR."
elif [[ "$BUILD_FAILED" -ne 0 ]]; then
    echo "Skipping other directories due to previous build failures."
else
    echo "Building non-numbered directories using base image: $CURRENT_BASE_IMAGE"
    for dir in "${other_dirs[@]}"; do
        echo "Processing other directory: $dir"
        log_command build_folder_image "$dir" "$use_cache" "$platform" "$use_squash" "$skip_intermediate_push_pull" "$CURRENT_BASE_IMAGE" "$DOCKER_USERNAME" "$DOCKER_REPO_PREFIX" "$DOCKER_REGISTRY"
        build_status=$?
        ATTEMPTED_TAGS+=("$fixed_tag")
        if [[ $build_status -eq 0 ]]; then
            BUILT_TAGS+=("$fixed_tag")
            update_available_images_in_env "$fixed_tag"
            CURRENT_BASE_IMAGE="$fixed_tag"
            FINAL_FOLDER_TAG="$fixed_tag"
            echo "Successfully built/pushed/pulled other image: $fixed_tag"
            echo "Next base image (if any) will be: $CURRENT_BASE_IMAGE"
        else
            echo "Build, push or pull failed for $dir."
            handle_build_error "$dir" $build_status
            BUILD_FAILED=1
        fi
    done
fi

echo "--------------------------------------------------"
echo "Folder build process complete!"
