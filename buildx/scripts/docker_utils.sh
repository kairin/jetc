# COMMIT-TRACKING: UUID-20240730-160000-HRD1
# Description: Remove base image parameter and sed logic from build_folder_image.
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
# Arguments: $1 = folder path, $2 = use_cache (y/n), $3 = docker_username,
#            $4 = platform, $5 = use_squash (y/n),
#            $6 = skip_intermediate_push_pull (y/n)
#            $7 = base_image_tag (tag to use for FROM ${BASE_IMAGE})
# Returns: The fixed tag name on success via $fixed_tag, non-zero exit status on failure
# =========================================================================
build_folder_image() {
  local folder=$1
  local use_cache=$2
  local docker_username=$3
  local platform=$4
  local use_squash=$5
  local skip_push_pull=$6
  local base_image_tag=$7 # Added base image tag argument

  # Variable to store the tag name
  fixed_tag=""

  local image_name
  image_name=$(basename "$folder" | tr '[:upper:]' '[:lower:]')
  # Ensure fixed_tag is set early for ATTEMPTED_TAGS in build.sh
  fixed_tag=$(echo "${docker_username}/001:${image_name}" | tr '[:upper:]' '[:lower:]')

  echo "Generating fixed tag: $fixed_tag"

  local dockerfile_path="$folder/Dockerfile"

  # Use [[ ]] for file existence check
  if [[ ! -f "$dockerfile_path" ]]; then
    echo "Warning: Dockerfile not found in $folder. Skipping."
    return 1
  fi

  # Check if base_image_tag is provided
  if [[ -z "$base_image_tag" ]]; then
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo "Error: Base image tag not provided for build of $folder."
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      return 1
  fi

  echo "--------------------------------------------------"
  echo "Building image from folder: $folder"
  echo "Image Name: $image_name"
  echo "Platform: $platform"
  echo "Tag: $fixed_tag"
  echo "Base Image (FROM via ARG): $base_image_tag" # Show the base image being passed
  echo "Skip Intermediate Push/Pull: $skip_push_pull"
  echo "--------------------------------------------------"

  # Base command args
  local cmd_args=("--platform" "$platform" "-t" "$fixed_tag")

  # Add the build argument for the base image
  cmd_args+=("--build-arg" "BASE_IMAGE=$base_image_tag")

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
