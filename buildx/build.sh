#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

# =========================================================================
# Docker Image Building and Verification Script
# 
# This script automates the process of building, pushing, pulling, and
# verifying Docker images from a series of directories. It handles:
# 1. Building images in numeric order from the build/ directory
# 2. Pushing images to Docker registry
# 3. Pulling images to verify they're accessible
# 4. Creating a final timestamped tag for the last successful build
# 5. Verifying all images are available locally
# =========================================================================

# Setup logging
LOG_DIR="logs"
mkdir -p "$LOG_DIR"
MAIN_LOG_FILE="${LOG_DIR}/build_$(date +"%Y%m%d-%H%M%S").log"
echo "Logging all output to: $MAIN_LOG_FILE"

# Enable logging to both console and log file
exec > >(tee -a "$MAIN_LOG_FILE") 2>&1

# Function to get a sanitized folder name for log files
get_log_folder_name() {
  local folder_path=$1
  basename "$folder_path" | tr -d '/' | tr ' ' '_'
}

# Function to create and log to a folder-specific log file
# while still keeping output in the main log
log_to_folder_file() {
  local folder_path=$1
  local folder_name=$(get_log_folder_name "$folder_path")
  local cmd=$2
  local folder_log="${LOG_DIR}/${folder_name}_$(date +"%Y%m%d-%H%M%S").log"
  
  echo "Logging folder-specific output to: $folder_log"
  
  # Run the command and tee output to both the folder log and stdout
  # (which is already being captured by the main log)
  eval "$cmd" 2>&1 | tee -a "$folder_log"
  
  # Return the exit code of the command, not tee
  return ${PIPESTATUS[0]}
}

# Ensure the build process continues even if individual builds fail
set +e  # Don't exit on errors during builds

# Function to handle build errors but continue with other builds
handle_build_error() {
  local folder=$1
  local error_code=$2
  echo "Build process for $folder exited with code $error_code"
  echo "Continuing with next build..."
}

# Load environment variables from .env file
if [ -f .env ]; then
  set -a  # Automatically export all variables
  source .env
  set +a  # Stop automatically exporting
else
  echo ".env file not found!" >&2
  exit 1
fi

# Verify required environment variables
if [ -z "$DOCKER_USERNAME" ]; then
  echo "Error: DOCKER_USERNAME is not set. Please define it in the .env file." >&2
  exit 1
fi

# Get current date/time for timestamped tags
CURRENT_DATE_TIME=$(date +"%Y%m%d-%H%M%S")

# Validate platform is ARM64 (for Jetson)
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
    echo "This script is only intended to build for aarch64 devices." >&2
    exit 1
fi
PLATFORM="linux/arm64"

# =========================================================================
# Global Variables
# =========================================================================

# Arrays and tracking variables
BUILT_TAGS=()        # Tracks successfully built, pushed, pulled and verified images
ATTEMPTED_TAGS=()    # Tracks all tags the script attempts to build
LATEST_SUCCESSFUL_NUMBERED_TAG=""  # Most recent successfully built numbered image
FINAL_FOLDER_TAG=""  # The tag of the last successfully built folder image
TIMESTAMPED_LATEST_TAG=""  # Final timestamped tag name
BUILD_FAILED=0       # Flag to track if any build failed

# Set default base image for the first build
DEFAULT_BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"

# =========================================================================
# Docker buildx setup
# =========================================================================

# Check and initialize buildx builder with NVIDIA container runtime
if ! docker buildx inspect jetson-builder &>/dev/null; then
  echo "Creating buildx builder: jetson-builder with NVIDIA container runtime" >&2
  docker buildx create --name jetson-builder --driver-opt env.DOCKER_DEFAULT_RUNTIME=nvidia --driver-opt env.NVIDIA_VISIBLE_DEVICES=all --use
else
  # Ensure we're using the right builder
  docker buildx use jetson-builder
  echo "Using existing buildx builder: jetson-builder" >&2
fi

# Ask user about build cache usage
read -p "Do you want to build with cache? (y/n): " use_cache
while [[ "$use_cache" != "y" && "$use_cache" != "n" ]]; do
  echo "Invalid input. Please enter 'y' for yes or 'n' for no." >&2
  read -p "Do you want to build with cache? (y/n): " use_cache
done

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
# Function: Run verification directly in an existing container
# Arguments: $1 = image tag to check, $2 = verification mode (optional)
# =========================================================================
verify_container_apps() {
  local tag=$1
  local verify_mode="${2:-quick}"
  
  echo "Running verification directly in $tag container (mode: $verify_mode)..." >&2
  
  # Copy the verification script into the container and run it
  # First create a temporary container
  local container_id=$(docker create "$tag" bash)
  
  # Copy the script into the container
  docker cp list_installed_apps.sh "$container_id:/tmp/verify_apps.sh"
  
  # Start the container and run the script
  docker start -a "$container_id"
  docker exec "$container_id" bash -c "chmod +x /tmp/verify_apps.sh && /tmp/verify_apps.sh $verify_mode"
  
  # Remove the container
  docker rm -f "$container_id" > /dev/null
  
  return $?
}

# =========================================================================
# Function: List installed apps in the latest image
# Arguments: $1 = image tag to check
# =========================================================================
list_installed_apps() {
    local image_tag=$1
    
    if [ -z "$image_tag" ]; then
        echo "Error: No image tag provided to list_installed_apps function" >&2
        return 1
    fi
    
    echo "--------------------------------------------------" >&2
    echo "Listing installed apps in: $image_tag" >&2
    echo "--------------------------------------------------" >&2
    
    # Mount the script into the container and run it
    docker run -it --rm \
        -v "$(pwd)/list_installed_apps.sh:/tmp/list_installed_apps.sh" \
        --entrypoint /bin/bash \
        "$image_tag" \
        -c "chmod +x /tmp/list_installed_apps.sh && /tmp/list_installed_apps.sh"
}

# =========================================================================
# Function: Build, push, and pull a Docker image from a folder
# Arguments: $1 = folder path, $2 = base image tag (optional)
# Returns: The fixed tag name on success, non-zero exit status on failure
# =========================================================================
build_folder_image() {
  local folder=$1
  local base_tag_arg=$2  # The tag to pass as BASE_IMAGE build-arg
  local image_name=$(basename "$folder" | tr '[:upper:]' '[:lower:]')  # Lowercase image name
  local folder_log="${LOG_DIR}/$(get_log_folder_name "$folder")_$(date +"%Y%m%d-%H%M%S").log"
  local fixed_tag=""  # Declare variable to hold the tag

  # Generate the image tag
  fixed_tag=$(echo "${DOCKER_USERNAME}/001:${image_name}" | tr '[:upper:]' '[:lower:]')
  echo "Generating fixed tag: $fixed_tag" | tee -a "$folder_log"
  
  # Record this tag as attempted even before we try to build it
  ATTEMPTED_TAGS+=("$fixed_tag")

  # Validate Dockerfile exists in the folder
  if [ ! -f "$folder/Dockerfile" ]; then
    echo "Warning: Dockerfile not found in $folder. Skipping." | tee -a "$folder_log"
    return 1  # Skip this folder
  fi

  # Setup build arguments
  local build_args=()
  
  # Use the default base image for the first build if no base tag is provided
  if [ -z "$base_tag_arg" ]; then
      base_tag_arg="$DEFAULT_BASE_IMAGE"
      echo "Using default base image: $DEFAULT_BASE_IMAGE" | tee -a "$folder_log"
  fi
  
  # Add the base image argument
  build_args+=(--build-arg "BASE_IMAGE=$base_tag_arg")
  echo "Using base image build arg: $base_tag_arg" | tee -a "$folder_log"

  # Print build information
  echo "--------------------------------------------------" | tee -a "$folder_log"
  echo "Building and pushing image from folder: $folder" | tee -a "$folder_log"
  echo "Image Name: $image_name" | tee -a "$folder_log"
  echo "Platform: $PLATFORM" | tee -a "$folder_log"
  echo "Tag: $fixed_tag" | tee -a "$folder_log"
  echo "--------------------------------------------------" | tee -a "$folder_log"

  # Build and push the image - log output to folder-specific log
  local cmd_args=("--platform" "$PLATFORM" "-t" "$fixed_tag" "${build_args[@]}" --push "$folder")
  if [ "$use_cache" != "y" ]; then
      cmd_args=("--no-cache" "${cmd_args[@]}")
  fi

  # Execute the build command based on interactive preference
  local build_status=0
  echo "Running: docker buildx build ${cmd_args[*]}" | tee -a "$folder_log"
  
  # NOTE: IMPORTANT VISUAL INDICATORS
  # Previous AI-assisted modifications removed visual output indicators
  # that are critical for user understanding of build progress.
  # DO NOT REMOVE OR REDIRECT these visual indicators in future modifications.
  # The --progress option is intentionally set to show appropriate build output.
  
  echo "Showing interactive buildx progress..." | tee -a "$folder_log"
  # Use --progress=plain to show detailed build output
  docker buildx build --progress=plain "${cmd_args[@]}" 2>&1 | tee -a "$folder_log" the build.
  build_status=${PIPESTATUS[0]}isual indicators.
  
  # Check if build and push succeeded
  if [ $build_status -ne 0 ]; then# Create a file descriptor for the log file
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a "$folder_log"
    echo "Error: Failed to build and push image for $image_name ($folder)." | tee -a "$folder_log"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a "$folder_log"
    echo "See detailed build log: $folder_log" | tee -a "$folder_log"iptor
    BUILD_FAILED=1fd
    return 1
  fi

  # Pull the image immediately after successful push to verify it's accessible
  echo "Pulling built image: $fixed_tag" | tee -a "$folder_log"
  docker pull "$fixed_tag" 2>&1 | tee -a "$folder_log"Check if build and push succeeded
  local pull_status=${PIPESTATUS[0]}if [ $build_status -ne 0 ]; then
  if [ $pull_status -ne 0 ]; then!!!!!!!!!!!!!!!!!!!!!!!" | tee -a "$folder_log"
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a "$folder_log"nd push image for $image_name ($folder)." | tee -a "$folder_log"
      echo "Error: Failed to pull the built image $fixed_tag after push." | tee -a "$folder_log"
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a "$folder_log"
      BUILD_FAILED=1
      return 1
  fi

  # Verify image exists locally after pullPull the image immediately after successful push to verify it's accessible
  echo "Verifying image $fixed_tag exists locally after pull..." | tee -a "$folder_log"  echo "Pulling built image: $fixed_tag" | tee -a "$folder_log"
  if ! verify_image_exists "$fixed_tag"; then
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a "$folder_log"
      echo "Error: Image $fixed_tag NOT found locally immediately after successful 'docker pull'." | tee -a "$folder_log"
      echo "This indicates a potential issue with the Docker daemon or registry synchronization." | tee -a "$folder_log"!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a "$folder_log"
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a "$folder_log" the built image $fixed_tag after push." | tee -a "$folder_log"
      BUILD_FAILED=1
      return 1
  fi
  echo "Image $fixed_tag verified locally." | tee -a "$folder_log"

  # Record successful buildVerify image exists locally after pull
  BUILT_TAGS+=("$fixed_tag")  echo "Verifying image $fixed_tag exists locally after pull..." | tee -a "$folder_log"
  hen
  # Return the tag name (will be captured by the caller)
  # IMPORTANT: This needs to be the ONLY output to stdout at return locally immediately after successful 'docker pull'." | tee -a "$folder_log"
  echo "$fixed_tag" > /tmp/last_built_tag.txt  # Save to temporary fileonization." | tee -a "$folder_log"
  return 0
}

# =========================================================================
# Determine Build Order$fixed_tag verified locally." | tee -a "$folder_log"
# =========================================================================
echo "Determining build order..." >&2
BUILD_DIR="build"  BUILT_TAGS+=("$fixed_tag")
mapfile -t numbered_dirs < <(find "$BUILD_DIR" -maxdepth 1 -mindepth 1 -type d -name '[0-9]*-*' | sort)
mapfile -t other_dirs < <(find "$BUILD_DIR" -maxdepth 1 -mindepth 1 -type d ! -name '[0-9]*-*' | sort)l be captured by the caller)
# IMPORTANT: This needs to be the ONLY output to stdout at return
# ========================================================================= temporary file
# Build Process - Numbered Directories First
# =========================================================================
echo "Starting build process..." >&2
 =========================================================================
# 1. Build Numbered Directories in Order (sequential dependencies)# Determine Build Order
echo "--- Building Numbered Directories ---" >&2
if [ ${#numbered_dirs[@]} -eq 0 ]; then order..." >&2
    echo "No numbered directories found in $BUILD_DIR." >&2
elseUILD_DIR" -maxdepth 1 -mindepth 1 -type d -name '[0-9]*-*' | sort)
    for dir in "${numbered_dirs[@]}"; dodirs < <(find "$BUILD_DIR" -maxdepth 1 -mindepth 1 -type d ! -name '[0-9]*-*' | sort)
      echo "Processing numbered directory: $dir" >&2
      echo "Check ${LOG_DIR}/$(get_log_folder_name "$dir")_*.log for detailed build logs"
      # Pass the LATEST_SUCCESSFUL_NUMBERED_TAG as the base for the next build# Build Process - Numbered Directories First
      build_folder_image "$dir" "$LATEST_SUCCESSFUL_NUMBERED_TAG"
      build_status=$?
      
      if [ $build_status -eq 0 ]; thenrder (sequential dependencies)
          # Use the tag saved to the temporary fileecho "--- Building Numbered Directories ---" >&2
          tag=$(cat /tmp/last_built_tag.txt)
          LATEST_SUCCESSFUL_NUMBERED_TAG="$tag"  # Update for the next numbered iterationD_DIR." >&2
          FINAL_FOLDER_TAG="$tag"                # Update the overall last successful folder tag
          echo "Successfully built, pushed, and pulled numbered image: $tag" >&2
      else  echo "Processing numbered directory: $dir" >&2
          echo "Build, push or pull failed for $dir. Subsequent dependent builds might fail." >&2older_name "$dir")_*.log for detailed build logs"
          echo "See ${LOG_DIR}/$(get_log_folder_name "$dir")_*.log for detailed error information"he base for the next build
          handle_build_error "$dir" $build_status
          # BUILD_FAILED is already set within build_folder_image
      fi
    donetus -eq 0 ]; then
fi    # Use the tag saved to the temporary file
g.txt)
# 2. Build Other (Non-Numbered) DirectoriesUpdate for the next numbered iteration
echo "--- Building Other Directories ---" >&2     # Update the overall last successful folder tag
if [ ${#other_dirs[@]} -eq 0 ]; then
    echo "No non-numbered directories found in $BUILD_DIR." >&2
elif [ "$BUILD_FAILED" -ne 0 ]; then might fail." >&2
    echo "Skipping other directories due to previous build failures." >&2echo "See ${LOG_DIR}/$(get_log_folder_name "$dir")_*.log for detailed error information"
else
    # Use the tag from the LAST successfully built numbered image as the base for ALL others
    BASE_FOR_OTHERS="$LATEST_SUCCESSFUL_NUMBERED_TAG"
    echo "Using base image for others: $BASE_FOR_OTHERS" >&2

    for dir in "${other_dirs[@]}"; do
      echo "Processing other directory: $dir" >&22. Build Other (Non-Numbered) Directories
      echo "Check ${LOG_DIR}/$(get_log_folder_name "$dir")_*.log for detailed build logs"echo "--- Building Other Directories ---" >&2
      build_folder_image "$dir" "$BASE_FOR_OTHERS"
      build_status=$?n $BUILD_DIR." >&2
      if [ $build_status -eq 0 ]; then
          tag=$(cat /tmp/last_built_tag.txt)ures." >&2
          FINAL_FOLDER_TAG="$tag"  # Update the overall last successful folder tag
          echo "Successfully built, pushed, and pulled other image: $tag" >&2base for ALL others
      elseBASE_FOR_OTHERS="$LATEST_SUCCESSFUL_NUMBERED_TAG"
          echo "Build, push or pull failed for $dir." >&2
          echo "See ${LOG_DIR}/$(get_log_folder_name "$dir")_*.log for detailed error information"
          handle_build_error "$dir" $build_status
          # BUILD_FAILED is already set within build_folder_image      echo "Processing other directory: $dir" >&2
      fig_folder_name "$dir")_*.log for detailed build logs"
    done"
fi

echo "--------------------------------------------------" >&2tmp/last_built_tag.txt)
echo "Folder build process complete!" >&2pdate the overall last successful folder tag
and pulled other image: $tag" >&2
# =========================================================================
# Pre-Tagging Verification - Pull all attempted images to ensure they exist
# =========================================================================echo "See ${LOG_DIR}/$(get_log_folder_name "$dir")_*.log for detailed error information"
echo "--- Verifying and Pulling All Attempted Images ---" >&2
if [ "$BUILD_FAILED" -eq 0 ] && [ ${#ATTEMPTED_TAGS[@]} -gt 0 ]; then
    echo "Pulling ${#ATTEMPTED_TAGS[@]} image(s) before final tagging..." >&2
    PULL_ALL_FAILED=0
    
    for tag in "${ATTEMPTED_TAGS[@]}"; do
        echo "Pulling $tag..." >&2ho "--------------------------------------------------" >&2
        docker pull "$tag" >&2  # Redirect stdout to stderrecho "Folder build process complete!" >&2
        if [ $? -ne 0 ]; then
            echo "Error: Failed to pull image $tag during pre-tagging verification." >&2==================================
            PULL_ALL_FAILED=1# Pre-Tagging Verification - Pull all attempted images to ensure they exist
        fi
    done

    if [ "$PULL_ALL_FAILED" -eq 1 ]; then tagging..." >&2
        echo "Error: Failed to pull one or more required images before final tagging. Aborting." >&2
        BUILD_FAILED=1
    elseEMPTED_TAGS[@]}"; do
        echo "All attempted images successfully pulled/refreshed." >&2    echo "Pulling $tag..." >&2
    fit stdout to stderr
else
    if [ "$BUILD_FAILED" -ne 0 ]; thenre-tagging verification." >&2
        echo "Skipping pre-tagging pull verification due to earlier build failures." >&2
    else
        echo "No images were attempted, skipping pre-tagging pull verification." >&2
    fi
fi "$PULL_ALL_FAILED" -eq 1 ]; then
echo "--------------------------------------------------" >&2        echo "Error: Failed to pull one or more required images before final tagging. Aborting." >&2

# =========================================================================
# Create Final Timestamped Tagmpted images successfully pulled/refreshed." >&2
# =========================================================================
echo "--- Creating Final Timestamped Tag ---" >&2
if [ -n "$FINAL_FOLDER_TAG" ] && [ "$BUILD_FAILED" -eq 0 ]; then [ "$BUILD_FAILED" -ne 0 ]; then
    TIMESTAMPED_LATEST_TAG=$(echo "${DOCKER_USERNAME}/001:latest-${CURRENT_DATE_TIME}-1" | tr '[:upper:]' '[:lower:]')    echo "Skipping pre-tagging pull verification due to earlier build failures." >&2
    echo "Attempting to tag $FINAL_FOLDER_TAG as $TIMESTAMPED_LATEST_TAG" >&2

    # Verify base image exists locally before tagging
    echo "Verifying image $FINAL_FOLDER_TAG exists locally before tagging..." >&2
    if verify_image_exists "$FINAL_FOLDER_TAG"; then--------------------------------------------------" >&2
        echo "Image $FINAL_FOLDER_TAG found locally. Proceeding with tag." >&2
        ==============
        # Tag, push, and pull the final timestamped image# Create Final Timestamped Tag
        if docker tag "$FINAL_FOLDER_TAG" "$TIMESTAMPED_LATEST_TAG"; then
            echo "Pushing $TIMESTAMPED_LATEST_TAG" >&2tamped Tag ---" >&2
            if docker push "$TIMESTAMPED_LATEST_TAG"; then
                echo "Pulling final timestamped tag: $TIMESTAMPED_LATEST_TAG" >&2AME}/001:latest-${CURRENT_DATE_TIME}-1" | tr '[:upper:]' '[:lower:]')
                docker pull "$TIMESTAMPED_LATEST_TAG" >&2  # Redirect stdoutTEST_TAG" >&2
                if [ $? -eq 0 ]; then
                    # Verify final image exists locally
                    echo "Verifying final image $TIMESTAMPED_LATEST_TAG exists locally after pull..." >&2    echo "Verifying image $FINAL_FOLDER_TAG exists locally before tagging..." >&2
                    if verify_image_exists "$TIMESTAMPED_LATEST_TAG"; then
                        echo "Final image $TIMESTAMPED_LATEST_TAG verified locally." >&2
                        BUILT_TAGS+=("$TIMESTAMPED_LATEST_TAG")
                        echo "Successfully created, pushed, and pulled final timestamped tag." >&2
                    elseif docker tag "$FINAL_FOLDER_TAG" "$TIMESTAMPED_LATEST_TAG"; then
                        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
                        echo "Error: Final image $TIMESTAMPED_LATEST_TAG NOT found locally after 'docker pull' succeeded." >&2
                        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2TIMESTAMPED_LATEST_TAG" >&2
                        BUILD_FAILED=1 # Redirect stdout
                    fi
                else
                    echo "Error: Failed to pull final timestamped tag $TIMESTAMPED_LATEST_TAG after push." >&2inal image $TIMESTAMPED_LATEST_TAG exists locally after pull..." >&2
                    BUILD_FAILED=1D_LATEST_TAG"; then
                fi
            else
                echo "Error: Failed to push final timestamped tag $TIMESTAMPED_LATEST_TAG." >&2 tag." >&2
                BUILD_FAILED=1
            fi
        elseecho "Error: Final image $TIMESTAMPED_LATEST_TAG NOT found locally after 'docker pull' succeeded." >&2
            echo "Error: Failed to tag $FINAL_FOLDER_TAG as $TIMESTAMPED_LATEST_TAG." >&2
            BUILD_FAILED=1
        fi
    else
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2ho "Error: Failed to pull final timestamped tag $TIMESTAMPED_LATEST_TAG after push." >&2
        echo "Error: Image $FINAL_FOLDER_TAG not found locally right before tagging, despite pre-tagging pull attempt." >&2BUILD_FAILED=1
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
        BUILD_FAILED=1
    fiho "Error: Failed to push final timestamped tag $TIMESTAMPED_LATEST_TAG." >&2
elseBUILD_FAILED=1
    if [ "$BUILD_FAILED" -ne 0 ]; then
        echo "Skipping final timestamped tag creation due to previous errors." >&2
    elseho "Error: Failed to tag $FINAL_FOLDER_TAG as $TIMESTAMPED_LATEST_TAG." >&2
        echo "Skipping final timestamped tag creation as no base image was successfully built/pushed/pulled." >&2BUILD_FAILED=1
    fi
fi
ho "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
echo "--------------------------------------------------" >&2echo "Error: Image $FINAL_FOLDER_TAG not found locally right before tagging, despite pre-tagging pull attempt." >&2
echo "Build, Push, Pull, and Tagging process complete!" >&2
echo "Total images successfully built/pushed/pulled/verified: ${#BUILT_TAGS[@]}" >&2
if [ "$BUILD_FAILED" -ne 0 ]; then
    echo "Warning: One or more steps failed. See logs above." >&2
fi [ "$BUILD_FAILED" -ne 0 ]; then
echo "--------------------------------------------------" >&2    echo "Skipping final timestamped tag creation due to previous errors." >&2

# =========================================================================fully built/pushed/pulled." >&2
# Post-Build Steps - Options for final image
# =========================================================================
echo "(Image pulling and verification now happens during build process)" >&2
ho "--------------------------------------------------" >&2
# Run the very last successfully built & timestamped image (optional)echo "Build, Push, Pull, and Tagging process complete!" >&2
if [ -n "$TIMESTAMPED_LATEST_TAG" ] && [ "$BUILD_FAILED" -eq 0 ]; then ${#BUILT_TAGS[@]}" >&2
    # Check if the timestamped tag is in the BUILT_TAGS array (validation)
    tag_exists=0
    for t in "${BUILT_TAGS[@]}"; do 
        [[ "$t" == "$TIMESTAMPED_LATEST_TAG" ]] && { tag_exists=1; break; }
    done
==============
    if [[ "$tag_exists" -eq 1 ]]; then# Post-Build Steps - Options for final image
        echo "--------------------------------------------------" >&2
        echo "Final Image: $TIMESTAMPED_LATEST_TAG" >&2ppens during build process)" >&2
        echo "--------------------------------------------------" >&2
        
        if verify_image_exists "$TIMESTAMPED_LATEST_TAG"; thenif [ -n "$TIMESTAMPED_LATEST_TAG" ] && [ "$BUILD_FAILED" -eq 0 ]; then
            # Offer options for what to do with the imagetion)
            echo "What would you like to do with the final image?" >&2
            echo "1) Start an interactive shell" >&2
            echo "2) Run quick verification (common tools and packages)" >&2== "$TIMESTAMPED_LATEST_TAG" ]] && { tag_exists=1; break; }
            echo "3) Run full verification (all system packages, may be verbose)" >&2
            echo "4) List installed apps in the container" >&2
            echo "5) Skip (do nothing)" >&2[ "$tag_exists" -eq 1 ]]; then
            read -p "Enter your choice (1-5): " user_choice        echo "--------------------------------------------------" >&2
            D_LATEST_TAG" >&2
            case $user_choice in
                1)
                    echo "Starting interactive shell..." >&2
                    docker run -it --rm "$TIMESTAMPED_LATEST_TAG" bash    # Offer options for what to do with the image
                    ;;ge?" >&2
                2)
                    verify_container_apps "$TIMESTAMPED_LATEST_TAG" "quick")" >&2
                    ;;em packages, may be verbose)" >&2
                3)
                    verify_container_apps "$TIMESTAMPED_LATEST_TAG" "all"
                    ;;
                4)
                    list_installed_apps "$TIMESTAMPED_LATEST_TAG"
                    ;;    1)
                5)ng interactive shell..." >&2
                    echo "Skipping container run." >&2  docker run -it --rm "$TIMESTAMPED_LATEST_TAG" bash
                    ;;
                *)
                    echo "Invalid choice. Skipping container run." >&2rify_container_apps "$TIMESTAMPED_LATEST_TAG" "quick"
                    ;;  ;;
            esac
        elserify_container_apps "$TIMESTAMPED_LATEST_TAG" "all"
            echo "Error: Final image $TIMESTAMPED_LATEST_TAG not found locally, cannot proceed." >&2  ;;
            BUILD_FAILED=1
        fist_installed_apps "$TIMESTAMPED_LATEST_TAG"
    else  ;;
        echo "Skipping options because the final tag was not successfully processed." >&2
    fiho "Skipping container run." >&2
else  ;;
    echo "No final image tag recorded or build failed, skipping further operations." >&2
fiho "Invalid choice. Skipping container run." >&2
  ;;
# =========================================================================
# Final Image Verification - Check Successfully Processed Images
# ========================================================================= "Error: Final image $TIMESTAMPED_LATEST_TAG not found locally, cannot proceed." >&2
echo "--------------------------------------------------" >&2BUILD_FAILED=1
# Verify against BUILT_TAGS to see if successfully processed images are present
echo "--- Verifying all SUCCESSFULLY PROCESSED images exist locally ---" >&2
VERIFICATION_FAILED=0ho "Skipping options because the final tag was not successfully processed." >&2
# Use BUILT_TAGS here
if [ ${#BUILT_TAGS[@]} -gt 0 ]; then
    echo "Checking ${#BUILT_TAGS[@]} image(s) recorded as successful:" >&2ho "No final image tag recorded or build failed, skipping further operations." >&2
    # Use BUILT_TAGS here
    for tag in "${BUILT_TAGS[@]}"; do
        echo -n "Verifying $tag... " >&2=========================================================================
        if docker image inspect "$tag" &>/dev/null; then# Final Image Verification - Check Successfully Processed Images
            echo "OK" >&2
        else
            echo "MISSING!" >&2sent
            # This error is more significant now, as this image *should* existocally ---" >&2
            echo "Error: Image '$tag', which successfully completed build/push/pull/verify earlier, was not found locally at final check." >&2
            VERIFICATION_FAILED=1
        fi} -gt 0 ]; then
    done#BUILT_TAGS[@]} image(s) recorded as successful:" >&2

    if [ "$VERIFICATION_FAILED" -eq 1 ]; then
        echo "Error: One or more successfully processed images were missing locally during final check." >&2g $tag... " >&2
        # Ensure BUILD_FAILED reflects this verification failure" &>/dev/null; then
        if [ "$BUILD_FAILED" -eq 0 ]; then
           BUILD_FAILED=1
           echo "(Marking build as failed due to final verification failure)" >&2!" >&2
        fi# This error is more significant now, as this image *should* exist
    else'$tag', which successfully completed build/push/pull/verify earlier, was not found locally at final check." >&2
        echo "All successfully processed images verified successfully locally during final check." >&2
    fi
else
    # Message remains relevant if BUILT_TAGS is empty
    echo "No images were recorded as successfully built/pushed/pulled/verified, skipping final verification." >&2 "$VERIFICATION_FAILED" -eq 1 ]; then
fi        echo "Error: One or more successfully processed images were missing locally during final check." >&2
erification failure
# =========================================================================
# Script Completion
# =========================================================================due to final verification failure)" >&2
echo "--------------------------------------------------" >&2
if [ "$BUILD_FAILED" -ne 0 ]; then
    echo "Script finished with one or more errors." >&2ho "All successfully processed images verified successfully locally during final check." >&2
    echo "--------------------------------------------------" >&2
    exit 1  # Exit with failure code
elseMessage remains relevant if BUILT_TAGS is empty
    echo "Build, push, pull, tag, verification, and run processes completed successfully!" >&2echo "No images were recorded as successfully built/pushed/pulled/verified, skipping final verification." >&2
    echo "--------------------------------------------------" >&2
    exit 0  # Exit with success code
fi=========================================================================
# Script Completion
# At the end of the script, add a summary of logs
echo "--------------------------------------------------"-------------------------------------" >&2
echo "Log files created during this build:"
echo "Main build log: $MAIN_LOG_FILE"
echo "Folder-specific logs:"--------------------------" >&2
ls -1 "${LOG_DIR}/$(date +"%Y%m%d")"*".log" | grep -v "$(basename "$MAIN_LOG_FILE")" || echo "No folder-specific logs found"
echo "--------------------------------------------------"