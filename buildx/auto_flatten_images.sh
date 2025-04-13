#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

# =========================================================================
# Docker Image Flattening Script
# 
# This script automatically flattens Docker images to avoid layer depth limits
# It is designed to be integrated into the build process, taking the output
# of one build step and creating a flattened version for the next step
# =========================================================================

# Load environment variables from .env file if it exists
if [ -f .env ]; then
  set -a  # Automatically export all variables
  source .env
  set +a  # Stop automatically exporting
fi

# If DOCKER_USERNAME isn't set in .env, use a fallback
if [ -z "$DOCKER_USERNAME" ]; then
  DOCKER_USERNAME="kairin"
  echo "Warning: DOCKER_USERNAME not found in .env, using default: $DOCKER_USERNAME"
fi

# Function to check if image exists
verify_image_exists() {
  local tag=$1
  if docker image inspect "$tag" &> /dev/null; then
    return 0  # Image exists
  else
    return 1  # Image does not exist
  fi
}

# Function to flatten an image
flatten_image() {
  local source_tag="$1"
  local target_tag="$2"
  
  echo "Flattening image: $source_tag → $target_tag"
  
  # Method 1: Using docker export/import (completely flattens to one layer)
  echo "Creating temporary container..."
  container_id=$(docker create "$source_tag" /bin/true)
  if [ $? -eq 0 ]; then
    echo "Created container: $container_id"
    
    # Export and import to flatten completely
    echo "Exporting container filesystem and importing as flattened image..."
    docker export "$container_id" | docker import - "$target_tag"
    import_status=$?
    
    # Clean up container regardless of success
    docker rm "$container_id" >/dev/null
    
    if [ $import_status -eq 0 ]; then
      echo "Successfully created flattened image: $target_tag"
      
      # Check if we need to set ENTRYPOINT and CMD from original image
      # This is necessary because 'docker import' doesn't preserve them
      echo "Preserving ENTRYPOINT and CMD from original image..."
      
      # Get original ENTRYPOINT and CMD
      entrypoint_json=$(docker inspect --format='{{json .Config.Entrypoint}}' "$source_tag" 2>/dev/null)
      cmd_json=$(docker inspect --format='{{json .Config.Cmd}}' "$source_tag" 2>/dev/null)
      
      # Create Dockerfile with the preserved ENTRYPOINT and CMD
      temp_dir=$(mktemp -d)
      cat > "$temp_dir/Dockerfile" << DOCKERFILE
FROM $target_tag
ENTRYPOINT ${entrypoint_json:-["/bin/sh", "-c"]}
CMD ${cmd_json:-["/bin/bash"]}
DOCKERFILE
      
      # Build final image with ENTRYPOINT and CMD preserved
      final_tag_with_cmd="${target_tag}-with-cmd"
      docker build -t "$final_tag_with_cmd" "$temp_dir"
      final_build_status=$?
      
      # Clean up
      rm -rf "$temp_dir"
      
      if [ $final_build_status -eq 0 ]; then
        # Tag the finalized image as the target tag
        docker tag "$final_tag_with_cmd" "$target_tag"
        docker rmi "$final_tag_with_cmd" >/dev/null 2>&1 || true
        echo "Successfully preserved ENTRYPOINT and CMD in flattened image"
        
        # Push the flattened image
        echo "Pushing flattened image: $target_tag"
        docker push "$target_tag"
        push_status=$?
        
        if [ $push_status -eq 0 ]; then
          echo "✅ Successfully flattened, tagged and pushed image: $target_tag"
          return 0
        else
          echo "❌ Failed to push flattened image: $target_tag"
          return 1
        fi
      else
        echo "❌ Failed to preserve ENTRYPOINT and CMD"
        return 1
      fi
    else
      echo "❌ Failed to create flattened image using export/import"
    fi
  else
    echo "❌ Failed to create temporary container"
  fi
  
  # If we reach here, method 1 failed. Try method 2.
  echo "Trying alternative flattening method..."
  
  # Method 2: Using a minimal Dockerfile with COPY --from
  temp_dir=$(mktemp -d)
  cat > "$temp_dir/Dockerfile" << DOCKERFILE
FROM scratch
COPY --from=$source_tag / /
ENTRYPOINT ["/bin/bash"]
DOCKERFILE

  echo "Building flattened image via multi-stage approach..."
  docker buildx build --platform linux/arm64 -t "$target_tag" "$temp_dir" --push
  method2_status=$?
  
  # Clean up
  rm -rf "$temp_dir"
  
  if [ $method2_status -eq 0 ]; then
    echo "✅ Successfully flattened and pushed image using method 2: $target_tag"
    return 0
  else
    echo "❌ Failed to flatten image using method 2"
    return 1
  fi
}

# Function to process a numbered directory in the build structure
# This function is designed to be called from your main build script
process_and_flatten() {
  local image_tag="$1"              # Image tag to flatten
  local next_stage_name="$2"        # Name for the flattened image 
  local next_folder_path="$3"       # Path to the next build folder
  
  if [ -z "$image_tag" ]; then
    echo "Error: Image tag to flatten is required"
    return 1
  fi
  
  if [ -z "$next_stage_name" ]; then
    echo "Error: Next stage name is required"
    return 1
  fi
  
  # Default folder path if not provided
  if [ -z "$next_folder_path" ]; then
    next_folder_path="build/$next_stage_name"
  fi
  
  # Create the target tag for the flattened image
  local flattened_tag="${DOCKER_USERNAME}/001:${next_stage_name}"
  
  echo "===== Processing Image Flattening ====="
  echo "Source Image: $image_tag"
  echo "Target Flattened: $flattened_tag"
  echo "Next Build Folder: $next_folder_path"
  echo "====================================="
  
  # Verify source image exists
  if ! verify_image_exists "$image_tag"; then
    echo "❌ Source image $image_tag not found locally, cannot flatten"
    return 1
  fi
  
  # Flatten the image
  if flatten_image "$image_tag" "$flattened_tag"; then
    echo "Image flattened successfully and ready for next build step"
    
    # Return the flattened image tag so the build script can use it
    echo "$flattened_tag"
    return 0
  else
    echo "❌ Failed to flatten image"
    return 1
  fi
}

# Main script logic when run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [ $# -lt 2 ]; then
    echo "Usage: $0 <source_image_tag> <next_stage_name> [next_folder_path]"
    echo ""
    echo "Example:"
    echo "  $0 kairin/001:01-build-essential 02-bazel build/02-bazel"
    echo ""
    echo "This will flatten kairin/001:01-build-essential and create"
    echo "kairin/001:02-bazel ready to be used for the next build step"
    exit 1
  fi

  SOURCE_TAG="$1"
  NEXT_STAGE="$2"
  NEXT_FOLDER="${3:-build/$NEXT_STAGE}"
  
  process_and_flatten "$SOURCE_TAG" "$NEXT_STAGE" "$NEXT_FOLDER"
  exit $?
fi
