# COMMIT-TRACKING: UUID-20240803-103000-ARGS # Replace YYYYMMDD-HHMMSS with current system time
# Description: Added support for reading Docker build arguments from a .buildargs file.
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
# Build a Docker image from a specific folder
# =========================================================================
# Parameters:
# $1: folder_path - The directory containing the Dockerfile and build context.
# $2: use_cache - 'y' or 'n' to enable/disable Docker build cache.
# $3: docker_username - Docker Hub username (now loaded from env).
# $4: platform - Target platform (e.g., linux/arm64).
# $5: use_squash - 'y' or 'n' to enable/disable image squashing.
# $6: skip_intermediate_push_pull - 'y' or 'n' to skip push/pull after build.
# $7: base_image_tag - The base image tag to use (passed as --build-arg BASE_IMAGE).
# Uses Environment Variables:
# DOCKER_REGISTRY, DOCKER_USERNAME, DOCKER_REPO_PREFIX
# Sets:
# fixed_tag (global): The generated tag for the built image (e.g., [registry/]kairin/001:01-01-arrow).
# =========================================================================
build_folder_image() {
    local folder_path=$1
    local use_cache=$2
    # $3 (docker_username) is now primarily loaded from env, but keep arg for potential override? No, rely on env.
    local platform=$4
    local use_squash=$5
    local skip_intermediate_push_pull=$6
    local base_image_tag=$7 # Base image tag passed from build.sh

    local image_name
    image_name=$(basename "$folder_path")

    # --- Construct the tag dynamically ---
    local tag_repo="${DOCKER_USERNAME}/${DOCKER_REPO_PREFIX}"
    local tag_prefix=""
    if [[ -n "$DOCKER_REGISTRY" ]]; then
        tag_prefix="${DOCKER_REGISTRY}/"
    fi
    # Ensure tag is lowercase as required by Docker
    fixed_tag=$(echo "${tag_prefix}${tag_repo}:${image_name}" | tr '[:upper:]' '[:lower:]')
    # --- End tag construction ---

    echo "--------------------------------------------------"
    echo "Building image from folder: $folder_path"
    echo "Image Name: $image_name"
    echo "Platform: $platform"
    echo "Tag: $fixed_tag"
    echo "Base Image (FROM via ARG): $base_image_tag" # Display the base image being used
    echo "Skip Intermediate Push/Pull: $skip_intermediate_push_pull"
    echo "--------------------------------------------------"

    local build_cmd="docker buildx build --platform $platform -t $fixed_tag"

    # --- Add BASE_IMAGE build-arg ---
    # Always pass the base image tag determined by the main build script
    build_cmd+=" --build-arg BASE_IMAGE=$base_image_tag"

    # --- Add build args from .buildargs file ---
    local build_args_file="$folder_path/.buildargs"
    if [[ -f "$build_args_file" ]]; then
        echo "Found .buildargs file: $build_args_file"
        # Read file line by line, skipping comments and empty lines
        while IFS='=' read -r key value || [[ -n "$key" ]]; do
            # Trim leading/trailing whitespace from key and value
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            # Skip empty lines or lines starting with #
            if [[ -n "$key" && ! "$key" =~ ^# ]]; then
                # Ensure value is not empty before adding
                if [[ -n "$value" ]]; then
                    echo "  Adding build arg: --build-arg $key=\"$value\""
                    build_cmd+=" --build-arg $key=\"$value\""
                else
                    echo "  Skipping build arg '$key': No value provided."
                fi
            fi
        done < "$build_args_file"
    fi
    # --- End build args handling ---


    # Add cache option
    if [[ "$use_cache" == "n" ]]; then
        build_cmd+=" --no-cache"
        echo "Using --no-cache"
    fi

    # Add squash option
    if [[ "$use_squash" == "y" ]]; then
        build_cmd+=" --squash"
        echo "Using --squash"
    fi

    # Add push option if intermediate push/pull is NOT skipped
    if [[ "$skip_intermediate_push_pull" != "y" ]]; then
        build_cmd+=" --push"
        echo "Using --push"
    else
        build_cmd+=" --load" # Load the image into the local Docker daemon if not pushing
        echo "Using --load (intermediate push skipped)"
    fi


    # Add the build context path at the end
    build_cmd+=" $folder_path"

    echo "Running: $build_cmd"
    if eval "$build_cmd"; then
        echo "Successfully built image: $fixed_tag"

        # Only pull if push was performed
        if [[ "$skip_intermediate_push_pull" != "y" ]]; then
            echo "Pulling image $fixed_tag to ensure it's available locally..."
            if docker pull "$fixed_tag"; then
                echo "Successfully pulled image $fixed_tag."
                # Verify image exists locally after pull
                if verify_image_exists "$fixed_tag"; then
                    echo "Image $fixed_tag verified locally after pull."
                    return 0 # Success
                else
                    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
                    echo "Error: Image $fixed_tag NOT found locally after 'docker pull' succeeded."
                    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
                    return 1 # Failure
                fi
            else
                echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
                echo "Error: Failed to pull image $fixed_tag after successful build and push."
                echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
                return 1 # Failure
            fi
        else
            # If push/pull was skipped, verify the image exists locally (due to --load)
            echo "Verifying image $fixed_tag exists locally (push/pull skipped)..."
             if verify_image_exists "$fixed_tag"; then
                 echo "Image $fixed_tag verified locally."
                 return 0 # Success
             else
                 echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
                 echo "Error: Image $fixed_tag NOT found locally after build with --load."
                 echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
                 return 1 # Failure
             fi
        fi
    else
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "Error: Failed to build image for $image_name ($folder_path)."
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        return 1 # Failure
    fi
}
