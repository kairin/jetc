#!/bin/bash
echo "--- Creating Final Timestamped Tag ---"
if [[ -z "$CURRENT_DATE_TIME" ]]; then
    CURRENT_DATE_TIME=$(date +%Y%m%d-%H%M%S)
    echo "Warning: CURRENT_DATE_TIME not set, using current time: $CURRENT_DATE_TIME"
fi
if [[ -n "$FINAL_FOLDER_TAG" ]] && [[ "$BUILD_FAILED" -eq 0 ]]; then
    generate_timestamped_tag "$DOCKER_USERNAME" "$DOCKER_REPO_PREFIX" "$DOCKER_REGISTRY" "$CURRENT_DATE_TIME"
    TIMESTAMPED_LATEST_TAG="$timestamped_tag"
    echo "Attempting to tag $FINAL_FOLDER_TAG as $TIMESTAMPED_LATEST_TAG"
    echo "Verifying image $FINAL_FOLDER_TAG exists locally before tagging..."
    if verify_image_exists "$FINAL_FOLDER_TAG"; then
        echo "Image $FINAL_FOLDER_TAG found locally. Proceeding with tag."
        if docker tag "$FINAL_FOLDER_TAG" "$TIMESTAMPED_LATEST_TAG"; then
            echo "Tagged successfully."
            if [[ "$local_skip_intermediate" != "y" ]]; then
                echo "Pushing $TIMESTAMPED_LATEST_TAG"
                docker push "$TIMESTAMPED_LATEST_TAG"
            else
                echo "Skipping push for $TIMESTAMPED_LATEST_TAG (local build only)"
            fi
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
