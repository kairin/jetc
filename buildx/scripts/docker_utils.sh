# COMMIT-TRACKING: UUID-20240730-150000-SED1
# Description: Modify build_folder_image to set FROM line via sed instead of build-arg.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── docker_utils.sh    <- THIS FILE
# └── ...                        <- Other project files

#!/bin/bash

# =========================================================================
# Function: Verify image exists locally
# Arguments: $1 = image tag to verify
# Returns: 0 if image exists, 1 if not
# =========================================================================
verify_image_exists() {
  local tag_to_check="$1"
  if docker image inspect "$tag_to_check" >/dev/null 2>&1; then
    return 0  # Image exists
  else
    return 1  # Image does not exist
  fi
}

# =========================================================================
# Function: Run verification directly in an existing container
# Arguments: $1 = image tag to check, $2 = verification mode (optional)
# =========================================================================
verify_container_apps() {
  local tag=$1
  local verify_mode="${2:-quick}"
  local script_path="$(dirname "$0")/list_installed_apps.sh"
  
  echo "Running verification directly in $tag container (mode: $verify_mode)..."
  
  # Copy the verification script into the container and run it
  # First create a temporary container
  local container_id=$(docker create "$tag" bash)
  
  # Copy the script into the container
  docker cp "$script_path" "$container_id:/tmp/verify_apps.sh"
  
  # Start the container and run the script
  docker start -a "$container_id"
  docker exec "$container_id" bash -c "chmod +x /tmp/verify_apps.sh && /tmp/verify_apps.sh $verify_mode"
  
  # Remove the container
  docker rm -f "$container_id" > /dev/null
  
  return $?
}

# =========================================================================
# Function: List installed applications in a container
# Arguments: $1 = image tag to check
# =========================================================================
list_installed_apps() {
  local image_tag=$1
  local script_path="$(dirname "$0")/list_installed_apps.sh"
  
  if ! verify_image_exists "$image_tag"; then
    echo "Error: Image $image_tag not found locally"
    return 1
  fi
  
  echo "--------------------------------------------------"
  echo "Listing installed apps in: $image_tag"
  echo "--------------------------------------------------"
  
  # Mount the script into the container and run it
  docker run -it --rm \
      -v "$script_path:/tmp/list_installed_apps.sh" \
      --entrypoint /bin/bash \
      "$image_tag" \
      -c "chmod +x /tmp/list_installed_apps.sh && /tmp/list_installed_apps.sh"
}

# =========================================================================
# Function: Build, push, and pull a Docker image from a folder
# Arguments: $1 = folder path, $2 = base image tag (optional), $3 = use_cache (y/n),
#            $4 = docker_username, $5 = platform, $6 = default_base_image,
#            $7 = use_squash (y/n), $8 = skip_intermediate_push_pull (y/n)
# Returns: The fixed tag name on success via $fixed_tag, non-zero exit status on failure
# =========================================================================
build_folder_image() {
  local folder=$1
  local base_tag_arg=$2
  local use_cache=$3
  local docker_username=$4
  local platform=$5
  local default_base_image=$6
  local use_squash=$7
  local skip_push_pull=$8 # Added argument

  # Variable to store the tag name
  fixed_tag=""

  local image_name
  image_name=$(basename "$folder" | tr '[:upper:]' '[:lower:]')
  fixed_tag=$(echo "${docker_username}/001:${image_name}" | tr '[:upper:]' '[:lower:]')

  echo "Generating fixed tag: $fixed_tag"

  local dockerfile_path="$folder/Dockerfile"
  local backup_path="$folder/Dockerfile.bak"

  # Use [[ ]] for file existence check
  if [[ ! -f "$dockerfile_path" ]]; then
    echo "Warning: Dockerfile not found in $folder. Skipping."
    return 1
  fi

  # Determine the actual base tag to use
  local actual_base_tag
  if [[ -z "$base_tag_arg" ]]; then
      actual_base_tag="$default_base_image"
      echo "Using default base image: $default_base_image"
  else
      actual_base_tag="$base_tag_arg"
      echo "Using base image from previous step: $actual_base_tag"
  fi

  # --- Dockerfile Modification and Restore Logic ---
  # Setup trap to restore the Dockerfile on exit (success, error, or interrupt)
  trap 'echo "Restoring Dockerfile $dockerfile_path"; mv "$backup_path" "$dockerfile_path" 2>/dev/null || echo "Restore failed or backup missing for $dockerfile_path"; trap - EXIT' EXIT

  echo "Backing up Dockerfile to $backup_path"
  cp "$dockerfile_path" "$backup_path"
  if [[ $? -ne 0 ]]; then
      echo "Error: Failed to backup Dockerfile $dockerfile_path. Aborting build for this step."
      trap - EXIT # Clear the trap as the operation failed before build
      return 1
  fi

  echo "Modifying $dockerfile_path to use FROM ${actual_base_tag}"
  # Use a temporary file for sed on systems where in-place editing might be tricky
  sed "s|^FROM \${BASE_IMAGE}.*|FROM ${actual_base_tag}|" "$backup_path" > "$dockerfile_path"
  if [[ $? -ne 0 ]]; then
      echo "Error: Failed to modify Dockerfile $dockerfile_path using sed. Aborting build for this step."
      # Trap will still attempt restore
      return 1
  fi
  # --- End Dockerfile Modification ---


  echo "--------------------------------------------------"
  echo "Building image from folder: $folder"
  echo "Image Name: $image_name"
  echo "Platform: $platform"
  echo "Tag: $fixed_tag"
  echo "Base Image (FROM): $actual_base_tag" # Show the base image being used
  echo "Skip Intermediate Push/Pull: $skip_push_pull"
  echo "--------------------------------------------------"

  # Base command args - REMOVED the build_args array for BASE_IMAGE
  local cmd_args=("--platform" "$platform" "-t" "$fixed_tag")

  # Add --no-cache if requested - Use [[ ]] for string comparison
  if [[ "$use_cache" != "y" ]]; then
      cmd_args+=("--no-cache") # Use += to append
  fi
  # Add --squash if requested - Use [[ ]] for string comparison
  if [[ "$use_squash" == "y" ]]; then
      echo "Attempting build with --squash (experimental)"
      cmd_args+=("--squash") # Use += to append
  fi

  # Add --push or --load based on preference - Use [[ ]] for string comparison
  if [[ "$skip_push_pull" == "y" ]]; then
      echo "Using --load instead of --push"
      cmd_args+=("--load")
  else
      echo "Using --push"
      cmd_args+=("--push")
  fi

  # Add the folder path at the end
  cmd_args+=("$folder")

  echo "Running: docker buildx build ${cmd_args[*]}"
  docker buildx build "${cmd_args[@]}"
  local build_status=$?

  # The trap will automatically restore the Dockerfile now

  # Use [[ ]] for numerical comparison
  if [[ $build_status -ne 0 ]]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Error: Failed to build image for $image_name ($folder)."
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    return 1 # Build failed
  fi

  # --- Post-Build Push/Pull/Verification (remains the same) ---
  # Only pull if we pushed - Use [[ ]] for string comparison
  if [[ "$skip_push_pull" != "y" ]]; then
      echo "Pulling built image: $fixed_tag"
      docker pull "$fixed_tag"
      local pull_status=$?

      # Use [[ ]] for numerical comparison
      if [[ $pull_status -ne 0 ]]; then
          echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
          echo "Error: Failed to pull the built image $fixed_tag after push."
          echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
          return 1 # Pull failed
      fi
  else
      echo "Skipped pulling image $fixed_tag as push was skipped."
  fi

  echo "Verifying image $fixed_tag exists locally..."
  if ! verify_image_exists "$fixed_tag"; then
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      # Use [[ ]] for string comparison
      if [[ "$skip_push_pull" == "y" ]]; then
          echo "Error: Image $fixed_tag NOT found locally immediately after successful 'docker buildx build --load'."
      else
          echo "Error: Image $fixed_tag NOT found locally immediately after successful 'docker pull'."
      fi
      echo "This indicates a potential issue with the Docker daemon or buildx driver."
      return 1 # Verification failed
  fi

  echo "Image $fixed_tag verified locally."
  return 0 # Success
}
