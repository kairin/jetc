#!/bin/bash
echo "--------------------------------------------------"
echo "--- Verifying all SUCCESSFULLY PROCESSED images exist locally ---"
VERIFICATION_FAILED=0
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
        if [[ "$BUILD_FAILED" -eq 0 ]]; then
           BUILD_FAILED=1
           echo "(Marking build as failed due to final verification failure)"
        fi
    else
        echo "All successfully processed images verified successfully locally during final check."
    fi
else
    echo "No images were recorded as successfully processed, skipping final verification."
fi
echo "--------------------------------------------------"
if [[ "$BUILD_FAILED" -ne 0 ]]; then
    echo "Script finished with one or more errors."
    echo "--------------------------------------------------"
    exit 1
else
    echo "Updating .env with latest successful build..."
    ENV_FILE="$(dirname "$0")/../.env"
    if [ -f "$ENV_FILE" ]; then
        LATEST_SUCCESSFUL_TAG_FOR_DEFAULT=""
        tag_exists=0
        if [[ -n "$TIMESTAMPED_LATEST_TAG" ]]; then
            for t in "${BUILT_TAGS[@]}"; do
                [[ "$t" == "$TIMESTAMPED_LATEST_TAG" ]] && { tag_exists=1; break; }
            done
            [[ $tag_exists -eq 1 ]] && LATEST_SUCCESSFUL_TAG_FOR_DEFAULT="$TIMESTAMPED_LATEST_TAG"
        fi
        if [[ -z "$LATEST_SUCCESSFUL_TAG_FOR_DEFAULT" ]] && [[ -n "$FINAL_FOLDER_TAG" ]]; then
             tag_exists=0
             for t in "${BUILT_TAGS[@]}"; do
                 [[ "$t" == "$FINAL_FOLDER_TAG" ]] && { tag_exists=1; break; }
             done
             [[ $tag_exists -eq 1 ]] && LATEST_SUCCESSFUL_TAG_FOR_DEFAULT="$FINAL_FOLDER_TAG"
        fi
        if [[ -n "$LATEST_SUCCESSFUL_TAG_FOR_DEFAULT" ]]; then
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
    exit 0
fi
generate_error_summary

# Add final verification step to ensure CURRENT_BASE_IMAGE is set to a valid image tag
if [[ -z "$CURRENT_BASE_IMAGE" ]]; then
    echo "Error: CURRENT_BASE_IMAGE is empty. Exiting."
    exit 1
else
    echo "CURRENT_BASE_IMAGE is set to: $CURRENT_BASE_IMAGE"
fi
