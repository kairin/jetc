#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

# =========================================================================
# Docker Image Building Script with Layer Limit Handling
# 
# This script improves Docker image building by:
# 1. Detecting and handling "max depth exceeded" errors
# 2. Implementing better diagnostics and recovery options
# 3. Providing guidance for reducing layer count
# =========================================================================

# Function to check if Docker is running
check_docker() {
  if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker is not running or accessible."
    return 1
  fi
  return 0
}

# Function to check if image exists locally
image_exists_locally() {
  if docker image inspect "$1" >/dev/null 2>&1; then
    return 0  # Image exists
  else
    return 1  # Image does not exist
  fi
}

# Function to rebuild with squashing if supported
rebuild_with_squash() {
  local image_tag="$1"
  local folder="$2"
  
  echo "Attempting to rebuild with --squash option to reduce layers..."
  
  # Check if Docker daemon supports --squash
  if ! docker build --help | grep -q -- "--squash"; then
    echo "Warning: Your Docker daemon doesn't support the --squash option."
    echo "Enable experimental features in daemon.json to use this option."
    return 1
  fi
  
  # Run with --squash option
  docker buildx build --squash --platform linux/arm64 -t "$image_tag" "$folder"
  return $?
}

# Function to fix a pulled image with layer issues
fix_layer_limit() {
  local image_tag="$1"
  local repo_name=$(echo "$image_tag" | cut -d: -f1)
  local new_tag="${repo_name}:fixed-layers-$(date +%s)"
  
  echo "Attempting to fix layer limit issue for image: $image_tag"
  echo "New compressed tag will be: $new_tag"
  
  # Check if image exists remotely by trying to inspect manifest
  if ! docker manifest inspect "$image_tag" >/dev/null 2>&1; then
    echo "Error: Image $image_tag doesn't exist in registry"
    return 1
  fi
  
  # Try to create a flattened version
  echo "Creating a flattened version with reduced layers..."
  
  # Method 1: Using docker export/import to flatten entirely
  container_id=$(docker create "$image_tag" /bin/true)
  if [ $? -eq 0 ]; then
    echo "Created temporary container: $container_id"
    
    # Export and import to flatten completely
    docker export "$container_id" | docker import - "$new_tag"
    import_status=$?
    
    # Clean up container regardless of success
    docker rm "$container_id" >/dev/null
    
    if [ $import_status -eq 0 ]; then
      echo "Successfully created flattened image: $new_tag"
      echo "Pushing flattened image..."
      docker push "$new_tag"
      if [ $? -eq 0 ]; then
        echo "Successfully pushed flattened image: $new_tag"
        echo "You can now use this image as a base for further builds."
        return 0
      else
        echo "Failed to push flattened image."
        return 1
      fi
    else
      echo "Failed to import flattened image."
    fi
  else
    echo "Failed to create temporary container for flattening."
  fi
  
  # If we reach here, the first method failed
  echo "First flattening method failed, trying alternative approach..."
  
  # Method 2: Using intermediate Dockerfile
  temp_dir=$(mktemp -d)
  echo "Created temporary directory: $temp_dir"
  
  # Create a simple Dockerfile that copies from the problem image
  cat > "$temp_dir/Dockerfile" << ENDDF
FROM scratch
COPY --from=$image_tag / /
ENTRYPOINT ["/bin/bash"]
ENDDF
  
  # Build the new image
  echo "Building new flattened image via multi-stage approach..."
  docker buildx build --platform linux/arm64 -t "$new_tag" "$temp_dir" --push
  flatten_status=$?
  
  # Clean up temp dir
  rm -rf "$temp_dir"
  
  if [ $flatten_status -eq 0 ]; then
    echo "Successfully created and pushed flattened image: $new_tag"
    echo "You can now use this image as a base for further builds."
    return 0
  else
    echo "Failed to create flattened image via alternative approach."
    return 1
  fi
}

# Function to analyze Dockerfile for layer reduction
analyze_dockerfile() {
  local dockerfile="$1"
  local issues=0
  
  echo "Analyzing Dockerfile for potential layer reduction..."
  
  if [ ! -f "$dockerfile" ]; then
    echo "Error: Dockerfile not found at $dockerfile"
    return 1
  fi
  
  # Check for multiple RUN commands that could be combined
  run_count=$(grep -c "^RUN " "$dockerfile")
  if [ $run_count -gt 5 ]; then
    issues=1
    echo "⚠️ Found $run_count RUN commands - consider combining them with && to reduce layers"
  fi
  
  # Check for COPY/ADD commands that could be consolidated
  copy_count=$(grep -c "^COPY \|^ADD " "$dockerfile")
  if [ $copy_count -gt 5 ]; then
    issues=1
    echo "⚠️ Found $copy_count COPY/ADD commands - consider consolidating them"
  fi
  
  # Check if multi-stage build is being used
  if ! grep -q "^FROM .* AS " "$dockerfile"; then
    issues=1
    echo "⚠️ No multi-stage build detected - consider implementing to reduce layers"
  fi
  
  # Look for layer cache invalidation patterns
  if grep -q "COPY \. \|ADD \. " "$dockerfile"; then
    issues=1
    echo "⚠️ Copying entire directory can invalidate caches - be more selective"
  fi
  
  # Check for apt/pip caches not being cleaned
  if grep -q "apt-get \|apt" "$dockerfile" && ! grep -q "rm -rf /var/lib/apt/lists/\*" "$dockerfile"; then
    issues=1
    echo "⚠️ apt is used but cache files may not be cleaned up"
  fi
  
  if grep -q "pip install" "$dockerfile" && ! grep -q "pip cache purge\|rm -rf /root/.cache/pip" "$dockerfile"; then
    issues=1
    echo "⚠️ pip is used but cache files may not be cleaned up"
  fi
  
  if [ $issues -eq 0 ]; then
    echo "✅ No obvious layer optimization issues found in Dockerfile."
  else
    echo "Recommendations to reduce layer count:"
    echo "1. Combine RUN commands with && and \\"
    echo "2. Use multi-stage builds to discard build dependencies"
    echo "3. Clean up package manager caches in the same RUN command"
    echo "4. Group related operations in the same layer"
    echo "5. Consider using a .dockerignore file"
  fi
  
  return 0
}

# Main function to handle an image with layer limit issues
handle_layer_limit() {
  local image_tag="$1"
  local folder="$2"
  
  if [ -z "$image_tag" ] || [ -z "$folder" ]; then
    echo "Usage: handle_layer_limit <image_tag> <dockerfile_folder>"
    return 1
  fi
  
  echo "==============================================================="
  echo "Handling Docker 'max depth exceeded' layer limit issue"
  echo "Image: $image_tag"
  echo "Folder: $folder"
  echo "==============================================================="
  
  # Check Docker is running
  if ! check_docker; then
    echo "Cannot proceed without Docker running."
    return 1
  fi
  
  # First, analyze the Dockerfile
  local dockerfile="${folder}/Dockerfile"
  if [ -f "$dockerfile" ]; then
    analyze_dockerfile "$dockerfile"
  else
    echo "Warning: Dockerfile not found at $dockerfile, skipping analysis."
  fi
  
  # Present options to the user
  echo ""
  echo "Select an action to resolve the layer limit issue:"
  echo "1) Rebuild with layer squashing (requires experimental Docker features)"
  echo "2) Create a flattened version of the image (may lose metadata/history)"
  echo "3) Show detailed instructions for manual Dockerfile optimization"
  echo "4) Skip and continue"
  read -p "Select option (1-4): " action
  
  case $action in
    1)
      rebuild_with_squash "$image_tag" "$folder"
      ;;
    2)
      fix_layer_limit "$image_tag"
      ;;
    3)
      cat << ENDHELP
=====================================================================
DETAILED INSTRUCTIONS FOR REDUCING DOCKER LAYERS

1. COMBINE RUN COMMANDS
   Instead of:
     RUN apt-get update
     RUN apt-get install -y package1
     RUN apt-get install -y package2
   
   Use:
     RUN apt-get update && \\
         apt-get install -y package1 package2 && \\
         rm -rf /var/lib/apt/lists/*

2. IMPLEMENT MULTI-STAGE BUILDS
   Example:
     FROM ubuntu:20.04 AS builder
     RUN apt-get update && apt-get install -y build-essential
     COPY . /app
     RUN cd /app && make
     
     FROM ubuntu:20.04
     COPY --from=builder /app/binary /usr/local/bin/
     
3. MINIMIZE CONTEXT SIZE
   - Create a proper .dockerignore file
   - Only COPY what's needed
   
4. CLEAN UP IN THE SAME LAYER
   RUN apt-get update && \\
       apt-get install -y python3-pip && \\
       pip3 install package && \\
       rm -rf /var/lib/apt/lists/* && \\
       rm -rf ~/.cache/pip
       
5. FLATTEN EXISTING IMAGES
   If you can't rebuild:
   - Export/import: docker export \$(docker create image) | docker import - newimage
   - Use as base with empty Dockerfile: FROM problematic-image
=====================================================================
ENDHELP
      ;;
    4)
      echo "Skipping layer limit fix."
      ;;
    *)
      echo "Invalid option, skipping."
      ;;
  esac
  
  echo ""
  echo "Layer limit handling complete."
  return 0
}

# Main script - check arguments
if [ $# -lt 2 ]; then
  echo "Usage: $0 <image_tag> <dockerfile_folder>"
  echo "Example: $0 kairin/001:12-huggingface_hub buildx/build/12-huggingface_hub"
  exit 1
fi

IMAGE_TAG="$1"
FOLDER="$2"

# Execute the handler
handle_layer_limit "$IMAGE_TAG" "$FOLDER"
