#!/bin/bash

# =========================================================================
# IMPORTANT: This build system requires Docker with buildx extension.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

# =========================================================================
# Utility Functions for Docker Build Process
# =========================================================================

# =========================================================================
# Function: Display a progress bar
# Arguments: $1 = current value, $2 = max value, $3 = operation description
# =========================================================================
show_progress() {
  local current=$1
  local max=$2
  local description=$3
  local percentage=$((current * 100 / max))
  local completed=$((percentage / 2))
  local remaining=$((50 - completed))

  # Create the progress bar
  local bar="["
  for ((i=0; i<completed; i++)); do
    bar+="="
  done
  
  if [ $completed -lt 50 ]; then
    bar+=">"
    for ((i=0; i<remaining-1; i++)); do
      bar+=" "
    done
  else
    bar+="="
  fi

  bar+="] ${percentage}%"
  
  # Print the progress bar and operation description
  printf "\r%-80s" "${description}: ${bar}"
}

# =========================================================================
# Function: Verify image exists locally
# Arguments: $1 = image tag to verify
# Returns: 0 if image exists, 1 if not
# =========================================================================
verify_image_exists() {
  local tag=$1
  if docker image inspect "$tag" &> /dev/null; then
    return 0  # Image exists
  else
    return 1  # Image does not exist
  fi
}

# =========================================================================
# Function: Create final timestamped tag
# =========================================================================
create_final_tag() {
  echo "--- Creating Final Timestamped Tag ---" >&2
  if [ -n "$FINAL_FOLDER_TAG" ] && [ "$BUILD_FAILED" -eq 0 ]; then
    TIMESTAMPED_LATEST_TAG=$(echo "${DOCKER_USERNAME}/001:latest-${CURRENT_DATE_TIME}-1" | tr '[:upper:]' '[:lower:]')
    echo "Attempting to tag $FINAL_FOLDER_TAG as $TIMESTAMPED_LATEST_TAG" >&2

    # Verify base image exists locally before tagging
    echo "Verifying image $FINAL_FOLDER_TAG exists locally before tagging..." >&2
    if verify_image_exists "$FINAL_FOLDER_TAG"; then
        echo "Image $FINAL_FOLDER_TAG found locally. Proceeding with tag." >&2
        
        # Tag, push, and pull the final timestamped image
        if docker tag "$FINAL_FOLDER_TAG" "$TIMESTAMPED_LATEST_TAG"; then
            echo "Pushing $TIMESTAMPED_LATEST_TAG" >&2
            if docker push "$TIMESTAMPED_LATEST_TAG"; then
                echo "Pulling final timestamped tag: $TIMESTAMPED_LATEST_TAG" >&2
                pull_output=$(docker pull "$TIMESTAMPED_LATEST_TAG" 2>&1)
                pull_status=$?
                
                if [ $pull_status -eq 0 ]; then
                    # Verify final image exists locally
                    echo "Verifying final image $TIMESTAMPED_LATEST_TAG exists locally after pull..." >&2
                    if verify_image_exists "$TIMESTAMPED_LATEST_TAG"; then
                        echo "Final image $TIMESTAMPED_LATEST_TAG verified locally." >&2
                        BUILT_TAGS+=("$TIMESTAMPED_LATEST_TAG")
                        echo "Successfully created, pushed, and pulled final timestamped tag." >&2
                    else
                        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
                        echo "Error: Final image $TIMESTAMPED_LATEST_TAG NOT found locally after 'docker pull' succeeded." >&2
                        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
                        BUILD_FAILED=1
                    fi
                else
                    echo "Error: Failed to pull final timestamped tag $TIMESTAMPED_LATEST_TAG after push." >&2
                    
                    # Check for layer limit error
                    if [[ "$pull_output" == *"max depth exceeded"* ]] && [ "$ENABLE_FLATTENING" = true ]; then
                        echo "DETECTED: Layer limit error when pulling final timestamped tag" >&2
                        
                        if fix_layer_limit "$TIMESTAMPED_LATEST_TAG"; then
                            # Verify again after fixing
                            if verify_image_exists "$TIMESTAMPED_LATEST_TAG"; then
                                echo "Successfully pulled flattened final image." >&2
                                BUILT_TAGS+=("$TIMESTAMPED_LATEST_TAG")
                                echo "Successfully created, pushed, and pulled final timestamped tag (after flattening)." >&2
                            else
                                BUILD_FAILED=1
                            fi
                        else
                            BUILD_FAILED=1
                        fi
                    else
                        BUILD_FAILED=1
                    fi
                fi
            else
                echo "Error: Failed to push final timestamped tag $TIMESTAMPED_LATEST_TAG." >&2
                BUILD_FAILED=1
            fi
        else
            echo "Error: Failed to tag $FINAL_FOLDER_TAG as $TIMESTAMPED_LATEST_TAG." >&2
            BUILD_FAILED=1
        fi
    else
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
        echo "Error: Image $FINAL_FOLDER_TAG not found locally right before tagging, despite pre-tagging pull attempt." >&2
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
        BUILD_FAILED=1
    fi
  else
    if [ "$BUILD_FAILED" -ne 0 ]; then
        echo "Skipping final timestamped tag creation due to previous errors." >&2
    else
        echo "Skipping final timestamped tag creation as no base image was successfully built/pushed/pulled." >&2
    fi
  fi

  echo "--------------------------------------------------" >&2
}

# =========================================================================
# Function: Verify and pull all attempted images
# =========================================================================
verify_all_images() {
  echo "--- Verifying and Pulling All Attempted Images ---" >&2
  if [ "$BUILD_FAILED" -eq 0 ] && [ ${#ATTEMPTED_TAGS[@]} -gt 0 ]; then
      echo "Pulling ${#ATTEMPTED_TAGS[@]} image(s) before final tagging..." >&2
      
      PULL_ALL_FAILED=0
      
      for tag in "${ATTEMPTED_TAGS[@]}"; do
          echo "Pulling $tag..." >&2
          pull_output=$(docker pull "$tag" 2>&1)
          pull_status=$?
          
          if [ $pull_status -ne 0 ]; then
              echo "Error: Failed to pull image $tag during pre-tagging verification." >&2
              
              # Check for layer limit error
              if [[ "$pull_output" == *"max depth exceeded"* ]] && [ "$ENABLE_FLATTENING" = true ]; then
                  echo "DETECTED: Layer limit error when pulling $tag" >&2
                  
                  if fix_layer_limit "$tag"; then
                      echo "Successfully fixed layer limit issue for $tag" >&2
                      continue  # Skip marking as failed
                  fi
              fi
              
              PULL_ALL_FAILED=1
          fi
      done
      
      if [ "$PULL_ALL_FAILED" -eq 1 ]; then
          echo "Error: Failed to pull one or more required images before final tagging. Aborting." >&2
          BUILD_FAILED=1
      else
          echo "All attempted images successfully pulled/refreshed." >&2
      fi
  else
      if [ "$BUILD_FAILED" -ne 0 ]; then
          echo "Skipping pre-tagging pull verification due to earlier build failures." >&2
      else
          echo "No images were attempted, skipping pre-tagging pull verification." >&2
      fi
  fi

  echo "--------------------------------------------------" >&2
}

# Function to check if user is logged in to Docker
is_docker_logged_in() {
    # Check if Docker credential file exists and has content
    if [ -f "$HOME/.docker/config.json" ]; then
        # Check if the config file contains auth credentials
        if grep -q "auth" "$HOME/.docker/config.json" || grep -q "credStore" "$HOME/.docker/config.json"; then
            # Verify access by running a command that requires authentication
            if docker info >/dev/null 2>&1; then
                return 0  # User is logged in
            fi
        fi
    fi
    return 1  # User is not logged in
}
