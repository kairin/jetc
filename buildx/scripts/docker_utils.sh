# COMMIT-TRACKING: UUID-20240729-004815-A3B1
# Description: Clarify UUID reuse policy in instructions
# Author: Mr K
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
# Arguments: $1 = folder path, $2 = base image tag (optional), $3 = use_cache (y/n)
# Returns: The fixed tag name on success via $fixed_tag, non-zero exit status on failure
# =========================================================================
build_folder_image() {
  local folder=$1
  local base_tag_arg=$2
  local use_cache=$3
  local docker_username=$4
  local platform=$5
  local default_base_image=$6
  
  # Variable to store the tag name
  fixed_tag=""
  
  local image_name
  image_name=$(basename "$folder" | tr '[:upper:]' '[:lower:]')
  fixed_tag=$(echo "${docker_username}/001:${image_name}" | tr '[:upper:]' '[:lower:]')

  echo "Generating fixed tag: $fixed_tag"

  if [ ! -f "$folder/Dockerfile" ]; then
    echo "Warning: Dockerfile not found in $folder. Skipping."
    return 1
  fi

  local build_args=()
  if [ -z "$base_tag_arg" ]; then
      base_tag_arg="$default_base_image"
      echo "Using default base image: $default_base_image"
  fi
  build_args+=(--build-arg "BASE_IMAGE=$base_tag_arg")
  echo "Using base image build arg: $base_tag_arg"

  echo "--------------------------------------------------"
  echo "Building and pushing image from folder: $folder"
  echo "Image Name: $image_name"
  echo "Platform: $platform"
  echo "Tag: $fixed_tag"
  echo "--------------------------------------------------"

  local cmd_args=("--platform" "$platform" "-t" "$fixed_tag" "${build_args[@]}" --push "$folder")
  if [ "$use_cache" != "y" ]; then
      cmd_args=("--no-cache" "${cmd_args[@]}")
  fi

  echo "Running: docker buildx build ${cmd_args[*]}"
  docker buildx build "${cmd_args[@]}"
  local build_status=$?

  if [ $build_status -ne 0; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Error: Failed to build and push image for $image_name ($folder)."
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    return 1
  fi

  echo "Pulling built image: $fixed_tag"
  docker pull "$fixed_tag"
  local pull_status=$?

  if [ $pull_status -ne 0; then
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo "Error: Failed to pull the built image $fixed_tag after push."
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      return 1
  fi

  echo "Verifying image $fixed_tag exists locally after pull..."
  if ! verify_image_exists "$fixed_tag"; then
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo "Error: Image $fixed_tag NOT found locally immediately after successful 'docker pull'."
      echo "This indicates a potential issue with the Docker daemon or registry synchronization."
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      return 1
  fi

  echo "Image $fixed_tag verified locally."
  return 0
}
