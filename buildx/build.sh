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
# 6. Using auto_flatten_images.sh to prevent layer depth issues
# =========================================================================

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
if ! docker info >/dev/null 2>&1; then
# Validate platform is ARM64 (for Jetson)aemon. Is Docker running?" >&2
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
    echo "This script is only intended to build for aarch64 devices." >&2
    exit 1r login >/dev/null 2>&1; then
fiecho "Warning: You may not be logged into Docker. Images may fail to push if credentials are required." >&2
PLATFORM="linux/arm64"yway? (y/n): " continue_without_login
  if [[ "$continue_without_login" != "y" ]]; then
# Verify network connectivity     echo "Aborting. Please run 'docker login' and try again." >&2
echo "Checking network connectivity..."
if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1 && ! ping -c 1 -W 5 1.1.1.1 >/dev/null 2>&1; then
  echo "Warning: Network connectivity issues detected. Build process may fail when accessing remote resources." >&2
  read -p "Continue despite network issues? (y/n): " continue_with_network_issues
  if [[ "$continue_with_network_issues" != "y" ]]; thenGet current date/time for timestamped tags
    echo "Aborting build process." >&2CURRENT_DATE_TIME=$(date +"%Y%m%d-%H%M%S")
    exit 1
  fim is ARM64 (for Jetson)
fi
if [ "$ARCH" != "aarch64" ]; then
# Check if 'pv' and 'dialog' are installed, and install them if notntended to build for aarch64 devices." >&2r Registry
if ! command -v pv &> /dev/null || ! command -v dialog &> /dev/null; then
  echo "Installing required packages: pv and dialog..."
  sudo apt-get update && sudo apt-get install -y pv dialog
fi

# =========================================================================them if notdev/null 2>&1; then
# Global VariablesKER_USERNAME%%.*}'"
# =========================================================================  echo "Installing required packages: pv and dialog..."      exit 1
stall -y pv dialog
# Arrays and tracking variables
BUILT_TAGS=()        # Tracks successfully built, pushed, pulled and verified images
ATTEMPTED_TAGS=()    # Tracks all tags the script attempts to build===================================================================
LATEST_SUCCESSFUL_NUMBERED_TAG=""  # Most recent successfully built numbered imageGlobal Variables
FINAL_FOLDER_TAG=""  # The tag of the last successfully built folder image# =========================================================================
TIMESTAMPED_LATEST_TAG=""  # Final timestamped tag name
BUILD_FAILED=0       # Flag to track if any build faileduccessfully built, pushed, pulled and verified images
ENABLE_FLATTENING=true  # Enable image flattening to prevent layer depth issuesBUILT_TAGS=()        # Tracks successfully built, pushed, pulled and verified imagesATTEMPTED_TAGS=()    # Tracks all tags the script attempts to build

# Check if auto_flatten_images.sh existsBERED_TAG=""  # Most recent successfully built numbered image# The tag of the last successfully built folder image
if [ ! -f "auto_flatten_images.sh" ]; then
  echo "Error: auto_flatten_images.sh script not found. This script is required for layer flattening." >&2TIMESTAMPED_LATEST_TAG=""  # Final timestamped tag nameBUILD_FAILED=0       # Flag to track if any build failed
  exit 1if any build failede flattening to prevent layer depth issues
fit layer depth issues

# Ensure auto_flatten_images.sh is executableriver docker-container --use
chmod +x auto_flatten_images.sh [ ! -f "auto_flatten_images.sh" ]; thenecho "Error: auto_flatten_images.sh script not found. This script is required for layer flattening." >&2
es.sh script not found. This script is required for layer flattening." >&2ce if desired
# =========================================================================  exit 1  read -p "Do you want to enable persistent build cache? (y/n): " use_persistent_cachefi
# Docker buildx setup
# =========================================================================

# Check and initialize buildx builder
if ! docker buildx inspect jetson-builder &>/dev/null; then
  echo "Creating buildx builder: jetson-builder" >&2=======================================================================  --driver-opt network=host --driver-opt "image=moby/buildkit:latest" \cker buildx setup
  docker buildx create --name jetson-builder# Docker buildx setup      --buildkitd-flags '--allow-insecure-entitlement network.host' \# =========================================================================
fi=========================================
docker buildx use jetson-builder

# Ask user about build cache usage
read -p "Do you want to build with cache? (y/n): " use_cache
while [[ "$use_cache" != "y" && "$use_cache" != "n" ]]; docker buildx create --name jetson-builderk user about build cache usage
  echo "Invalid input. Please enter 'y' for yes or 'n' for no." >&2firead -p "Do you want to build with cache? (y/n): " use_cachedocker buildx use jetson-builder
  read -p "Do you want to build with cache? (y/n): " use_cache= "n" ]]; do
done 'n' for no." >&2che usage
 " use_cache(y/n): " use_cache
# Ask user about layer flattening  -p "Do you want to build with cache? (y/n): " use_cachee [[ "$use_cache" != "y" && "$use_cache" != "n" ]]; do
read -p "Do you want to enable image flattening between steps to prevent layer limit issues? (y/n): " use_flattening
while [[ "$use_flattening" != "y" && "$use_flattening" != "n" ]]; doecho "Invalid input. Please enter 'y' for yes or 'n' for no." >&2Ask user about layer flattening read -p "Do you want to build with cache? (y/n): " use_cache
  echo "Invalid input. Please enter 'y' for yes or 'n' for no." >&2  read -p "Do you want to build with cache? (y/n): " use_cacheread -p "Do you want to enable image flattening between steps to prevent layer limit issues? (y/n): " use_flatteningdone
  read -p "Do you want to enable image flattening between steps? (y/n): " use_flattening
done
lattening between steps? (y/n): " use_flatteningflattening between steps to prevent layer limit issues? (y/n): " use_flattening
if [[ "$use_flattening" == "n" ]]; thenlattening between steps to prevent layer limit issues? (y/n): " use_flattening
  ENABLE_FLATTENING=false
  echo "Image flattening is disabled." >&2Please enter 'y' for yes or 'n' for no." >&2 == "n" ]]; thento enable image flattening between steps? (y/n): " use_flattening
elseyou want to enable image flattening between steps? (y/n): " use_flatteningENING=false
  echo "Image flattening is enabled - this will help prevent 'max depth exceeded' errors." >&2
fi
"$use_flattening" == "n" ]]; then "Image flattening is enabled - this will help prevent 'max depth exceeded' errors." >&2LE_FLATTENING=false
# =========================================================================
# Function: Verify image exists locallyho "Image flattening is disabled." >&2
# Arguments: $1 = image tag to verifylse ========================================================================= echo "Image flattening is enabled - this will help prevent 'max depth exceeded' errors." >&2
# Returns: 0 if image exists, 1 if not  echo "Image flattening is enabled - this will help prevent 'max depth exceeded' errors." >&2# Function: Verify image exists locallyfi
# =========================================================================fi# Arguments: $1 = image tag to verify
verify_image_exists() {
  local tag=$1# =========================================================================# =========================================================================# Function: Verify image exists locally
  if docker image inspect "$tag" &> /dev/null; then
    return 0  # Image existsify
  else
    return 1  # Image does not exist
  fits() {
}does not existinspect "$tag" &> /dev/null; then
age inspect "$tag" &> /dev/null; thenists
exists
# Add this function to your build.sh file, before the fix_layer_limit function

# =========================================================================function
# Function: Display a progress bar
# Arguments: $1 = current value, $2 = max value, $3 = operation description=====================
# ========================================================================= bartion to your build.sh file, before the fix_layer_limit function
show_progress() {h file, before the fix_layer_limit function = max value, $3 = operation description
  local current=$1==================================================================================================================
  local max=$2=====================================================================rogress() {tion: Display a progress bar
  local description=$3Function: Display a progress barlocal current=$1Arguments: $1 = current value, $2 = max value, $3 = operation description
  local percentage=$((current * 100 / max)) $2 = max value, $3 = operation description=========================
  local completed=$((percentage / 2))===============================================================ription=$3s() {
  local remaining=$((50 - completed))
  t=$1ted=$((percentage / 2))
  # Create the progress barmax=$2remaining=$((50 - completed))description=$3
  local bar="["l description=$3rcentage=$((current * 100 / max))
  for ((i=0; i<completed; i++)); doentage=$((current * 100 / max))he progress barleted=$((percentage / 2))
    bar+="="cal completed=$((percentage / 2))cal bar="["cal remaining=$((50 - completed))
  donelocal remaining=$((50 - completed))for ((i=0; i<completed; i++)); do
  
  if [ $completed -lt 50 ]; then# Create the progress bardonelocal bar="["
    bar+=">"
    for ((i=0; i<remaining-1; i++)); do
      bar+=" "   bar+="="   bar+=">" done
    done  done    for ((i=0; i<remaining-1; i++)); do  
  else        bar+=" "  if [ $completed -lt 50 ]; then
    bar+="="
  fi
  o
  bar+="] ${percentage}%"
  
  # Print the progress bar and operation description
  printf "\r%-80s" "${description}: ${bar}"
}fi# Print the progress bar and operation description

bar+="] ${percentage}%"
# =========================================================================
# Function: Fix layer limit issues by flattening an imageoperation description
# Arguments: $1 = image tag to flattenprintf "\r%-80s" "${description}: ${bar}"=========================================================================
# Returns: 0 on success, 1 on failure
# =========================================================================
fix_layer_limit() {=======
  local tag="$1"============
  
  echo -e "\nAttempting to fix layer limit issue for image: $tag" >&2ten
  rns: 0 on success, 1 on failure=================================================================
  # Extract the image name part after the colon for use as the next stage name============================e for image: $tag" >&2
  local image_name="${tag##*:}"
  cal tag="$1"Extract the image name part after the colon for use as the next stage name
  # Monitor the flattening process using pv if available
  if command -v pv >/dev/null 2>&1; theno -e "\nAttempting to fix layer limit issue for image: $tag" >&2
    # Use pv to show a progress barflattening process using pv if availablect the image name part after the colon for use as the next stage name
    echo "Starting image flattening process with progress bar..." >&2he image name part after the colon for use as the next stage name-v pv >/dev/null 2>&1; then_name="${tag##*:}"
    ./auto_flatten_images.sh "$tag" "$image_name" 2>&1 | pv -pt -i 0.5 > /dev/null
    flatten_status=${PIPESTATUS[0]}
  elsetening process using pv if availablemages.sh "$tag" "$image_name" 2>&1 | pv -pt -i 0.5 > /dev/null/dev/null 2>&1; then
    # Fallback to our custom progress indicator
    echo "Starting image flattening process..." >&2 show a progress bar flattening process with progress bar..." >&2
    Starting image flattening process with progress bar..." >&2back to our custom progress indicator_flatten_images.sh "$tag" "$image_name" 2>&1 | pv -pt -i 0.5 > /dev/null
    # Create a background process to show progress while flattening happensimage_name" 2>&1 | pv -pt -i 0.5 > /dev/nullocess..." >&2
    (
      i=0
      max=100allback to our custom progress indicator"Starting image flattening process..." >&2
      while [ $i -lt $max ] && ! [ -f /tmp/flattening_complete ]; doimage flattening process..." >&2
        show_progress $i $max "Flattening image"  max=100# Create a background process to show progress while flattening happens
        i=$((i + 1))ss to show progress while flattening happens! [ -f /tmp/flattening_complete ]; do
        if [ $i -eq $max ]; then i=0; fi
        sleep 1
      done  max=100    if [ $i -eq $max ]; then i=0; fi  while [ $i -lt $max ] && ! [ -f /tmp/flattening_complete ]; do
      # Ensure we show 100% at the endtening_complete ]; do
      show_progress 100 100 "Flattening image"ttening image"
      echo # Add newline after progress bar
    ) &=0; fiening image"
    progress_pid=$!    sleep 1  echo # Add newline after progress bar  done
    
    # Run the actual flattening
    ./auto_flatten_images.sh "$tag" "$image_name" >/dev/nullage"
    flatten_status=$?ar
    ) &./auto_flatten_images.sh "$tag" "$image_name" >/dev/nullprogress_pid=$!
    # Signal completion to the progress display  progress_pid=$!  flatten_status=$?  
    touch /tmp/flattening_complete
    sleep 1.5  # Give the progress bar time to complete
    rm -f /tmp/flattening_complete./auto_flatten_images.sh "$tag" "$image_name" >/dev/nulltouch /tmp/flattening_completeflatten_status=$?
    
    # Clean up the progress display
    kill $progress_pid 2>/dev/null || trueress display
    wait $progress_pid 2>/dev/null || true
    echo # Add newline after progress bar # Give the progress bar time to completeress_pid 2>/dev/null || true/flattening_complete
  fif /tmp/flattening_complete $progress_pid 2>/dev/null || true
  
  if [ $flatten_status -eq 0 ]; then the progress display>/dev/null || true
    echo "✅ Successfully flattened image $tag" >&2ll $progress_pid 2>/dev/null || trueprogress_pid 2>/dev/null || true
    it $progress_pid 2>/dev/null || true $flatten_status -eq 0 ]; thenho # Add newline after progress bar
    # Pull the flattened image to verify it worked2
    echo "Pulling flattened image: $tag" >&2
    if docker pull "$tag" >&2; thenPull the flattened image to verify it worked [ $flatten_status -eq 0 ]; then
      echo "Successfully pulled flattened image!" >&2 if [ $flatten_status -eq 0 ]; then   echo "Pulling flattened image: $tag" >&2   echo "✅ Successfully flattened image $tag" >&2
      return 0    echo "✅ Successfully flattened image $tag" >&2    if docker pull "$tag" >&2; then    
    else          echo "Successfully pulled flattened image!" >&2    # Pull the flattened image to verify it worked
      echo "Failed to pull flattened image after flattening." >&2    # Pull the flattened image to verify it worked      return 0    echo "Pulling flattened image: $tag" >&2
      return 1
    fi
  else
    echo "❌ Failed to flatten image $tag" >&2
    return 1
  fil flattened image after flattening." >&2tten image $tag" >&2
}

else echo "❌ Failed to flatten image $tag" >&2

# =========================================================================  return 1
# Function: Create preventatively flattened version of an image for next step
# Arguments: $1 = source image tag, $2 = target image name for next step
# Returns: 0 on success, 1 on failurext step
# =========================================================================
flatten_for_next_step() {
  local source_tag="$1"================================================================================lattened version of an image for next step
  local next_step_name="$2"tion: Create preventatively flattened version of an image for next stepn_for_next_step() {ments: $1 = source image tag, $2 = target image name for next step
   image name for next step
  echo -e "\nCreating flattened version for next build step..." >&2
  =======================================================================n_for_next_step() {
  # Monitor the flattening process using pv if available
  if command -v pv >/dev/null 2>&1; thenal source_tag="$1"next_step_name="$2"
    # Use pv to show a progress barext_step_name="$2"or the flattening process using pv if available
    echo "Starting preventative flattening with progress bar..." >&2/null 2>&1; thenCreating flattened version for next build step..." >&2
    local flattened_tag=$(./auto_flatten_images.sh "$source_tag" "$next_step_name" 2>&1 | pv -pt -i 0.5)
    flatten_status=${PIPESTATUS[0]}
  elsetening process using pv if availabletag=$(./auto_flatten_images.sh "$source_tag" "$next_step_name" 2>&1 | pv -pt -i 0.5)/dev/null 2>&1; then
    # Fallback to our custom progress indicator
    echo "Starting preventative flattening..." >&2 show a progress barntative flattening with progress bar..." >&2
    Starting preventative flattening with progress bar..." >&2back to our custom progress indicatorflattened_tag=$(./auto_flatten_images.sh "$source_tag" "$next_step_name" 2>&1 | pv -pt -i 0.5)
    # Create a background process to show progress while flattening happensen_images.sh "$source_tag" "$next_step_name" 2>&1 | pv -pt -i 0.5)ning..." >&2
    (
      i=0
      max=100allback to our custom progress indicator"Starting preventative flattening..." >&2
      while [ $i -lt $max ] && ! [ -f /tmp/flattening_complete ]; dopreventative flattening..." >&2
        show_progress $i $max "Preventative flattening"  max=100# Create a background process to show progress while flattening happens
        i=$((i + 1))ss to show progress while flattening happens! [ -f /tmp/flattening_complete ]; do
        if [ $i -eq $max ]; then i=0; fi
        sleep 1
      done  max=100    if [ $i -eq $max ]; then i=0; fi  while [ $i -lt $max ] && ! [ -f /tmp/flattening_complete ]; do
      # Ensure we show 100% at the endtening_complete ]; do
      show_progress 100 100 "Preventative flattening"ventative flattening"
      echo # Add newline after progress bar
    ) &=0; fintative flattening"
    progress_pid=$!    sleep 1  echo # Add newline after progress bar  done
    
    # Run the actual flattening
    local flattened_tag=$(./auto_flatten_images.sh "$source_tag" "$next_step_name" 2>/dev/null)flattening"
    flatten_status=$?ar
    ) &local flattened_tag=$(./auto_flatten_images.sh "$source_tag" "$next_step_name" 2>/dev/null)progress_pid=$!
    # Signal completion to the progress display  progress_pid=$!  flatten_status=$?  
    touch /tmp/flattening_complete
    sleep 1.5  # Give the progress bar time to complete
    rm -f /tmp/flattening_completeattened_tag=$(./auto_flatten_images.sh "$source_tag" "$next_step_name" 2>/dev/null)mp/flattening_completestatus=$?
    atten_status=$?eep 1.5  # Give the progress bar time to complete
    # Clean up the progress display
    kill $progress_pid 2>/dev/null || true completion to the progress displayening_complete
    wait $progress_pid 2>/dev/null || truetouch /tmp/flattening_complete# Clean up the progress displaysleep 1.5  # Give the progress bar time to complete
    echo # Add newline after progress bar   sleep 1.5  # Give the progress bar time to complete   kill $progress_pid 2>/dev/null || true   rm -f /tmp/flattening_complete
  fi    rm -f /tmp/flattening_complete    wait $progress_pid 2>/dev/null || true    
  
  if [ $flatten_status -eq 0 ] && [ -n "$flattened_tag" ]; then
    echo "✅ Successfully created flattened version: $flattened_tag for next step" >&2
    return 0
  elseter progress barcreated flattened version: $flattened_tag for next step" >&2
    echo "⚠️ Warning: Failed to create flattened version for next step." >&2
    return 1
  fiif [ $flatten_status -eq 0 ] && [ -n "$flattened_tag" ]; then  echo "⚠️ Warning: Failed to create flattened version for next step." >&2  echo "✅ Successfully created flattened version: $flattened_tag for next step" >&2
}2
  return 0fielse
# =========================================================================
# Function: Run verification directly in an existing container flattened version for next step." >&2
# Arguments: $1 = image tag to check, $2 = verification mode (optional)
# =========================================================================fiFunction: Run verification directly in an existing container
verify_container_apps() {
  local tag=$1
  local verify_mode="${2:-quick}"=========================================================================rify_container_apps() {Function: Run verification directly in an existing container
  n existing container)
  echo "Running verification directly in $tag container (mode: $verify_mode)..." >&2eck, $2 = verification mode (optional)==========================================
  
  # Copy the verification script into the container and run itrify_container_apps() {echo "Running verification directly in $tag container (mode: $verify_mode)..." >&2local tag=$1
  # First create a temporary container
  local container_id=$(docker create "$tag" bash) and run it
  # First create a temporary containerecho "Running verification directly in $tag container (mode: $verify_mode)..." >&2
  # Copy the script into the containerning verification directly in $tag container (mode: $verify_mode)..." >&2tainer_id=$(docker create "$tag" bash)
  docker cp list_installed_apps.sh "$container_id:/tmp/verify_apps.sh"   # Copy the verification script into the container and run it
    # Copy the verification script into the container and run it  # Copy the script into the container  # First create a temporary container
  # Start the container and run the script
  docker start -a "$container_id"
  docker exec "$container_id" bash -c "chmod +x /tmp/verify_apps.sh && /tmp/verify_apps.sh $verify_mode"
  
  # Remove the containerled_apps.sh "$container_id:/tmp/verify_apps.sh"er_id" bash -c "chmod +x /tmp/verify_apps.sh && /tmp/verify_apps.sh $verify_mode"
  docker rm -f "$container_id" > /dev/null
  Start the container and run the scriptRemove the containercker start -a "$container_id"
  return $?" /dev/nullsh -c "chmod +x /tmp/verify_apps.sh && /tmp/verify_apps.sh $verify_mode"
}ify_apps.sh $verify_mode"

# =========================================================================move the container -f "$container_id" > /dev/null
# Function: List installed apps in the latest imagecker rm -f "$container_id" > /dev/null
# Arguments: $1 = image tag to check
# =========================================================================
list_installed_apps() {
    local image_tag=$1==========================================================================================================================================
    =======================
    if [ -z "$image_tag" ]; thend apps in the latest imageto check
        echo "Error: No image tag provided to list_installed_apps function" >&2
        return 1===========================================
    fi{o image tag provided to list_installed_apps function" >&2
    
    echo "--------------------------------------------------" >&2      fi   if [ -z "$image_tag" ]; then
    echo "Listing installed apps in: $image_tag" >&2    if [ -z "$image_tag" ]; then            echo "Error: No image tag provided to list_installed_apps function" >&2
    echo "--------------------------------------------------" >&2 >&2
    
    # Mount the script into the container and run it
    docker run -it --rm \
        -v "$(pwd)/list_installed_apps.sh:/tmp/list_installed_apps.sh" \
        --entrypoint /bin/bash \alled apps in: $image_tag" >&2m \--------------------------------------" >&2
        "$image_tag" \-------------------------------------------" >&2)/list_installed_apps.sh:/tmp/list_installed_apps.sh" \
        -c "chmod +x /tmp/list_installed_apps.sh && /tmp/list_installed_apps.sh"
}
    docker run -it --rm \        -c "chmod +x /tmp/list_installed_apps.sh && /tmp/list_installed_apps.sh"        -v "$(pwd)/list_installed_apps.sh:/tmp/list_installed_apps.sh" \
# =========================================================================stalled_apps.sh:/tmp/list_installed_apps.sh" \
# Function: Build, push, and pull a Docker image from a folder
# Arguments: $1 = folder path, $2 = base image tag (optional)=======.sh && /tmp/list_installed_apps.sh"
# Returns: The fixed tag name on success, non-zero exit status on failure      -c "chmod +x /tmp/list_installed_apps.sh && /tmp/list_installed_apps.sh"Function: Build, push, and pull a Docker image from a folder
# =========================================================================
build_folder_image() {n failure===========================================
  local folder=$1# =========================================================================# =========================================================================# Function: Build, push, and pull a Docker image from a folder
  local base_tag_arg=$2  # The tag to pass as BASE_IMAGE build-argmage from a folder
  local image_name=$(basename "$folder" | tr '[:upper:]' '[:lower:]')  # Lowercase image name image tag (optional)on failure
failure=========
  # Generate the image tag===========================================folder" | tr '[:upper:]' '[:lower:]')  # Lowercase image name
  local fixed_tag=$(echo "${DOCKER_USERNAME}/001:${image_name}" | tr '[:upper:]' '[:lower:]')d_folder_image() {folder=$1
  echo "Generating fixed tag: $fixed_tag" >&2  local folder=$1  # Generate the image tag  local base_tag_arg=$2  # The tag to pass as BASE_IMAGE build-arg
  # The tag to pass as BASE_IMAGE build-arg"${DOCKER_USERNAME}/001:${image_name}" | tr '[:upper:]' '[:lower:]')name "$folder" | tr '[:upper:]' '[:lower:]')  # Lowercase image name
  # Record this tag as attempted even before we try to build itbasename "$folder" | tr '[:upper:]' '[:lower:]')  # Lowercase image namexed tag: $fixed_tag" >&2
  ATTEMPTED_TAGS+=("$fixed_tag")
ower:]')
  # Validate Dockerfile exists in the folderame}" | tr '[:upper:]' '[:lower:]')
  if [ ! -f "$folder/Dockerfile" ]; then "Generating fixed tag: $fixed_tag" >&2
    echo "Warning: Dockerfile not found in $folder. Skipping." >&2
    return 1  # Skip this folderRecord this tag as attempted even before we try to build it [ ! -f "$folder/Dockerfile" ]; thenTEMPTED_TAGS+=("$fixed_tag")
  fi  ATTEMPTED_TAGS+=("$fixed_tag")    echo "Warning: Dockerfile not found in $folder. Skipping." >&2

  # Setup build arguments
  local build_args=()
  if [ -n "$base_tag_arg" ]; thenund in $folder. Skipping." >&2
      build_args+=(--build-arg "BASE_IMAGE=$base_tag_arg")
      echo "Using base image build arg: $base_tag_arg" >&2
  else
      echo "No base image build arg provided (likely the first image)." >&2  # Setup build arguments      echo "Using base image build arg: $base_tag_arg" >&2  local build_args=()
  fi

  # Print build informationSE_IMAGE=$base_tag_arg")
  echo "--------------------------------------------------" >&2tag_arg" >&2
  echo "Building and pushing image from folder: $folder" >&2sePrint build information  echo "No base image build arg provided (likely the first image)." >&2
  echo "Image Name: $image_name" >&2      echo "No base image build arg provided (likely the first image)." >&2  echo "--------------------------------------------------" >&2  fi
  echo "Platform: $PLATFORM" >&2r" >&2
  echo "Tag: $fixed_tag" >&2
  echo "--------------------------------------------------" >&2tionFORM" >&2-----------------------------------" >&2
echo "--------------------------------------------------" >&2echo "Tag: $fixed_tag" >&2echo "Building and pushing image from folder: $folder" >&2
  # Build and push the imageom folder: $folder" >&2---------------------" >&2
  local cmd_args=("--platform" "$PLATFORM" "-t" "$fixed_tag" "${build_args[@]}" --push "$folder")&2
  if [ "$use_cache" != "y" ]; then
      cmd_args=("--no-cache" "${cmd_args[@]}")
  fi
args[@]}") the image
  # Execute the build commandd push the image-platform" "$PLATFORM" "-t" "$fixed_tag" "${build_args[@]}" --push "$folder")
  docker buildx build "${cmd_args[@]}"cal cmd_args=("--platform" "$PLATFORM" "-t" "$fixed_tag" "${build_args[@]}" --push "$folder")$use_cache" != "y" ]; then
  local build_status=$?  if [ "$use_cache" != "y" ]; then  # Execute the build command      cmd_args=("--no-cache" "${cmd_args[@]}")
  
  # Check if build and push succeeded
  if [ $build_status -ne 0 ]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
    echo "Error: Failed to build and push image for $image_name ($folder)." >&2"${cmd_args[@]}"ne 0 ]; then?
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2local build_status=$?  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
    BUILD_FAILED=1
    return 1eded!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2n
  fi

  # Pull the image immediately after successful push to verify it's accessibleecho "Error: Failed to build and push image for $image_name ($folder)." >&2echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
  echo "Pulling built image: $fixed_tag" >&2!!!!!!!!!!!!!!!!!!" >&2
  local pull_output
  pull_output=$(docker pull "$fixed_tag" 2>&1)
  local pull_status=$?
  t=$(docker pull "$fixed_tag" 2>&1)ll the image immediately after successful push to verify it's accessible
  # Check for layer limit errors in the pull outputl push to verify it's accessible
  if [ $pull_status -ne 0 ]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2pull_outputk for layer limit errors in the pull outpututput=$(docker pull "$fixed_tag" 2>&1)
    echo "Error: Failed to pull the built image $fixed_tag after push." >&2)
    
    # Check for specific layer depth errord to pull the built image $fixed_tag after push." >&2r layer limit errors in the pull output
    if [[ "$pull_output" == *"max depth exceeded"* ]]; then
      echo "DETECTED: Layer limit error ('max depth exceeded')" >&20 ]; then layer depth error!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
      echo "This is a Docker limitation on maximum layer depth." >&2!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2utput" == *"max depth exceeded"* ]]; thenailed to pull the built image $fixed_tag after push." >&2
      Error: Failed to pull the built image $fixed_tag after push." >&2 "DETECTED: Layer limit error ('max depth exceeded')" >&2
      if [ "$ENABLE_FLATTENING" = true ]; then is a Docker limitation on maximum layer depth." >&2k for specific layer depth error
        echo "Attempting to fix layer limit issue..." >&2
        th exceeded"* ]]; thene ]; thenor ('max depth exceeded')" >&2
        if fix_layer_limit "$fixed_tag"; thenit error ('max depth exceeded')" >&2 layer limit issue..." >&2mitation on maximum layer depth." >&2
          echo "Layer limit issue successfully addressed." >&2Docker limitation on maximum layer depth." >&2
        else "$fixed_tag"; thenBLE_FLATTENING" = true ]; then
          echo "Failed to address layer limit issue." >&2 [ "$ENABLE_FLATTENING" = true ]; then  echo "Layer limit issue successfully addressed." >&2echo "Attempting to fix layer limit issue..." >&2
          BUILD_FAILED=1echo "Attempting to fix layer limit issue..." >&2else
          return 1mit issue." >&2t "$fixed_tag"; then
        fitag"; then addressed." >&2
      elsessue successfully addressed." >&2
        echo "Image flattening is disabled. Enable it to automatically fix this issue." >&2r limit issue." >&2
        echo "Full error output:" >&2 "Failed to address layer limit issue." >&2ILED=1
        echo "$pull_output" >&2    BUILD_FAILED=1  echo "Image flattening is disabled. Enable it to automatically fix this issue." >&2    return 1
        BUILD_FAILED=1      return 1    echo "Full error output:" >&2    fi
        return 1        fi        echo "$pull_output" >&2      else
      fi
    elsely fix this issue." >&2
      # Other pull errors
      echo "Full error output:" >&2
      echo "$pull_output" >&2
      BUILD_FAILED=1
      return 1
    fi
  fipull errorsll error output:" >&2
  echo "Full error output:" >&2fi  echo "$pull_output" >&2
  # Verify image exists locally after pull
  echo "Verifying image $fixed_tag exists locally after pull..." >&2      BUILD_FAILED=1      return 1
  if ! verify_image_exists "$fixed_tag"; then
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
      echo "Error: Image $fixed_tag NOT found locally immediately after successful 'docker pull'." >&2
      echo "This indicates a potential issue with the Docker daemon or registry synchronization." >&2
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2cally after pullfixed_tag NOT found locally immediately after successful 'docker pull'." >&2ixed_tag exists locally after pull..." >&2
      BUILD_FAILED=1 $fixed_tag exists locally after pull..." >&2tes a potential issue with the Docker daemon or registry synchronization." >&2sts "$fixed_tag"; then
      return 1; then!!!!!!!!!!!!!!!!!!!!!!!" >&2!!!!!!!!!!!!!!!!!!!!!!!" >&2
  fi!!!!!!" >&2ull'." >&2
  echo "Image $fixed_tag verified locally." >&2 $fixed_tag NOT found locally immediately after successful 'docker pull'." >&2tial issue with the Docker daemon or registry synchronization." >&2
a potential issue with the Docker daemon or registry synchronization." >&2!!!!!!!!!!!!" >&2
  # If flattening is enabled and this image will be used as a base for another image,!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2 $fixed_tag verified locally." >&2AILED=1
  # create a flattened version to prevent layer limit issues in the next stepILD_FAILED=1
  if [ "$ENABLE_FLATTENING" = true ]; thenturn 1lattening is enabled and this image will be used as a base for another image,
    # Get the index of the current folder in the numbered_dirs arraycreate a flattened version to prevent layer limit issues in the next stepho "Image $fixed_tag verified locally." >&2
    local current_index=-1
    local next_index=-1
    for i in "${!numbered_dirs[@]}"; dod as a base for another image,
      if [[ "${numbered_dirs[$i]}" == "$folder" ]]; then
        current_index=$i "$ENABLE_FLATTENING" = true ]; thenr i in "${!numbered_dirs[@]}"; doGet the index of the current folder in the numbered_dirs array
        next_index=$((i+1))
        break
      fi
    doner i in "${!numbered_dirs[@]}"; do  breakif [[ "${numbered_dirs[$i]}" == "$folder" ]]; then
      if [[ "${numbered_dirs[$i]}" == "$folder" ]]; then  fi    current_index=$i
    # If there's a next folder, flatten this image proactively for the next step        current_index=$i    done        next_index=$((i+1))
    if [ $current_index -ne -1 ] && [ $next_index -lt ${#numbered_dirs[@]} ]; then
      local next_folder="${numbered_dirs[$next_index]}"s image proactively for the next step
      local next_name=$(basename "$next_folder" | tr '[:upper:]' '[:lower:]')    fi  if [ $current_index -ne -1 ] && [ $next_index -lt ${#numbered_dirs[@]} ]; then  done
      
      echo "Proactively flattening image for next build step: $next_name" >&2$next_folder" | tr '[:upper:]' '[:lower:]')next folder, flatten this image proactively for the next step
      flatten_for_next_step "$fixed_tag" "$next_name"here's a next folder, flatten this image proactively for the next stepent_index -ne -1 ] && [ $next_index -lt ${#numbered_dirs[@]} ]; then
      # Note: we don't fail the build if preventative flattening fails   if [ $current_index -ne -1 ] && [ $next_index -lt ${#numbered_dirs[@]} ]; then     echo "Proactively flattening image for next build step: $next_name" >&2     local next_folder="${numbered_dirs[$next_index]}"
    fi      local next_folder="${numbered_dirs[$next_index]}"      flatten_for_next_step "$fixed_tag" "$next_name"      local next_name=$(basename "$next_folder" | tr '[:upper:]' '[:lower:]')
  fi')
tep: $next_name" >&2
  # Record successful build&2
  BUILT_TAGS+=("$fixed_tag")ag" "$next_name"
  don't fail the build if preventative flattening failssful build
  # Return the tag name (will be captured by the caller)
  echo "$fixed_tag"
  return 0  # Return the tag name (will be captured by the caller)  # Record successful build
}

# =========================================================================
# Determine Build Ordertured by the caller)
# =========================================================================  echo "$fixed_tag"# =========================================================================  return 0
echo "Determining build order..." >&2
BUILD_DIR="build"
mapfile -t numbered_dirs < <(find "$BUILD_DIR" -maxdepth 1 -mindepth 1 -type d -name '[0-9]*-*' | sort)
mapfile -t other_dirs < <(find "$BUILD_DIR" -maxdepth 1 -mindepth 1 -type d ! -name '[0-9]*-*' | sort)================
termine Build Orderile -t numbered_dirs < <(find "$BUILD_DIR" -maxdepth 1 -mindepth 1 -type d -name '[0-9]*-*' | sort)=======================================================================
# ============================================================================================================IR" -maxdepth 1 -mindepth 1 -type d ! -name '[0-9]*-*' | sort)
# Build Process - Numbered Directories First
# =========================================================================
echo "Starting build process..." >&2type d -name '[0-9]*-*' | sort)t)
ind "$BUILD_DIR" -maxdepth 1 -mindepth 1 -type d ! -name '[0-9]*-*' | sort)================================================
# 1. Build Numbered Directories in Order (sequential dependencies)
echo "--- Building Numbered Directories ---" >&2
if [ ${#numbered_dirs[@]} -eq 0 ]; then
    echo "No numbered directories found in $BUILD_DIR." >&2=================================================================Building Numbered Directories ---" >&2ting build process..." >&2
else
    for dir in "${numbered_dirs[@]}"; do
      echo "Processing numbered directory: $dir" >&2ld Numbered Directories in Order (sequential dependencies)ilding Numbered Directories ---" >&2
      # Pass the LATEST_SUCCESSFUL_NUMBERED_TAG as the base for the next build- Building Numbered Directories ---" >&2dir in "${numbered_dirs[@]}"; donumbered_dirs[@]} -eq 0 ]; then
      tag=$(build_folder_image "$dir" "$LATEST_SUCCESSFUL_NUMBERED_TAG") [ ${#numbered_dirs[@]} -eq 0 ]; then    echo "Processing numbered directory: $dir" >&2  echo "No numbered directories found in $BUILD_DIR." >&2
      if [ $? -eq 0 ]; then    echo "No numbered directories found in $BUILD_DIR." >&2      # Pass the LATEST_SUCCESSFUL_NUMBERED_TAG as the base for the next buildelse
          LATEST_SUCCESSFUL_NUMBERED_TAG="$tag"  # Update for the next numbered iteration
          FINAL_FOLDER_TAG="$tag"                # Update the overall last successful folder tag
          echo "Successfully built, pushed, and pulled numbered image: $tag" >&2ctory: $dir" >&2_TAG="$tag"  # Update for the next numbered iterationUMBERED_TAG as the base for the next build
      else the next buildverall last successful folder tagRED_TAG")
          echo "Build, push or pull failed for $dir. Subsequent dependent builds might fail." >&2" "$LATEST_SUCCESSFUL_NUMBERED_TAG")pushed, and pulled numbered image: $tag" >&2
          # BUILD_FAILED is already set within build_folder_image
      fi      LATEST_SUCCESSFUL_NUMBERED_TAG="$tag"  # Update for the next numbered iteration      echo "Build, push or pull failed for $dir. Subsequent dependent builds might fail." >&2      FINAL_FOLDER_TAG="$tag"                # Update the overall last successful folder tag
    done tag
fid numbered image: $tag" >&2

# 2. Build Other (Non-Numbered) Directories          echo "Build, push or pull failed for $dir. Subsequent dependent builds might fail." >&2fi          # BUILD_FAILED is already set within build_folder_image
echo "--- Building Other Directories ---" >&2et within build_folder_image
if [ ${#other_dirs[@]} -eq 0 ]; then
    echo "No non-numbered directories found in $BUILD_DIR." >&2
elif [ "$BUILD_FAILED" -ne 0 ]; then
    echo "Skipping other directories due to previous build failures." >&2
else
    # Use the tag from the LAST successfully built numbered image as the base for ALL othersBuilding Other Directories ---" >&2Skipping other directories due to previous build failures." >&2her_dirs[@]} -eq 0 ]; then
    BASE_FOR_OTHERS="$LATEST_SUCCESSFUL_NUMBERED_TAG"
    echo "Using base image for others: $BASE_FOR_OTHERS" >&2s the base for ALL others
$BUILD_FAILED" -ne 0 ]; then_FOR_OTHERS="$LATEST_SUCCESSFUL_NUMBERED_TAG" "Skipping other directories due to previous build failures." >&2
    for dir in "${other_dirs[@]}"; do "Skipping other directories due to previous build failures." >&2 "Using base image for others: $BASE_FOR_OTHERS" >&2
      echo "Processing other directory: $dir" >&2se# Use the tag from the LAST successfully built numbered image as the base for ALL others
      tag=$(build_folder_image "$dir" "$BASE_FOR_OTHERS")    # Use the tag from the LAST successfully built numbered image as the base for ALL others    for dir in "${other_dirs[@]}"; do    BASE_FOR_OTHERS="$LATEST_SUCCESSFUL_NUMBERED_TAG"
      if [ $? -eq 0 ]; then
          FINAL_FOLDER_TAG="$tag"  # Update the overall last successful folder tagASE_FOR_OTHERS" >&2ASE_FOR_OTHERS")
          echo "Successfully built, pushed, and pulled other image: $tag" >&2      if [ $? -eq 0 ]; then    for dir in "${other_dirs[@]}"; do
      else
          echo "Build, push or pull failed for $dir." >&2
          # BUILD_FAILED is already set within build_folder_image
      fi
    doneul folder tag >&2
fi
r $dir." >&2
echo "--------------------------------------------------" >&2      echo "Build, push or pull failed for $dir." >&2    # BUILD_FAILED is already set within build_folder_image
echo "Folder build process complete!" >&2ithin build_folder_image
2
# =========================================================================
# Pre-Tagging Verification - Pull all attempted images to ensure they exist
# ====================================================================================================================================------------------------------------------------" >&2
echo "--- Verifying and Pulling All Attempted Images ---" >&2-----------------" >&2ttempted images to ensure they exist&2
if [ "$BUILD_FAILED" -eq 0 ] && [ ${#ATTEMPTED_TAGS[@]} -gt 0 ]; then
    echo "Pulling ${#ATTEMPTED_TAGS[@]} image(s) before final tagging..." >&2Pulling All Attempted Images ---" >&2===============================================================
    PULL_ALL_FAILED=0==================================MPTED_TAGS[@]} -gt 0 ]; thenempted images to ensure they exist
    
    for tag in "${ATTEMPTED_TAGS[@]}"; do===
        echo "Pulling $tag..." >&2ing and Pulling All Attempted Images ---" >&2 && [ ${#ATTEMPTED_TAGS[@]} -gt 0 ]; then
        pull_output=$(docker pull "$tag" 2>&1)TAGS[@]} -gt 0 ]; thenre final tagging..." >&2
        pull_status=$?2
        
        if [ $pull_status -ne 0 ]; thenTAGS[@]}"; do
            echo "Error: Failed to pull image $tag during pre-tagging verification." >&2 "${ATTEMPTED_TAGS[@]}"; dog $tag..." >&2
             "Pulling $tag..." >&2 $pull_status -ne 0 ]; then_output=$(docker pull "$tag" 2>&1)
            # Check for layer limit errorpull "$tag" 2>&1)ed to pull image $tag during pre-tagging verification." >&2
            if [[ "$pull_output" == *"max depth exceeded"* ]] && [ "$ENABLE_FLATTENING" = true ]; thenll_status=$?  
                echo "DETECTED: Layer limit error when pulling $tag" >&2    # Check for layer limit errorif [ $pull_status -ne 0 ]; then
                        if [ $pull_status -ne 0 ]; then            if [[ "$pull_output" == *"max depth exceeded"* ]] && [ "$ENABLE_FLATTENING" = true ]; then            echo "Error: Failed to pull image $tag during pre-tagging verification." >&2
                if fix_layer_limit "$tag"; thenmage $tag during pre-tagging verification." >&2it error when pulling $tag" >&2
                    echo "Successfully fixed layer limit issue for $tag" >&2
                    continue  # Skip marking as failedr layer limit error_layer_limit "$tag"; thenll_output" == *"max depth exceeded"* ]] && [ "$ENABLE_FLATTENING" = true ]; then
                fi    if [[ "$pull_output" == *"max depth exceeded"* ]] && [ "$ENABLE_FLATTENING" = true ]; then            echo "Successfully fixed layer limit issue for $tag" >&2        echo "DETECTED: Layer limit error when pulling $tag" >&2
            fi&2
                                fi          if fix_layer_limit "$tag"; then
            PULL_ALL_FAILED=1            if fix_layer_limit "$tag"; then        fi                echo "Successfully fixed layer limit issue for $tag" >&2
        fi fixed layer limit issue for $tag" >&2
    done
        fifi    fi
    if [ "$PULL_ALL_FAILED" -eq 1 ]; then
        echo "Error: Failed to pull one or more required images before final tagging. Aborting." >&2      PULL_ALL_FAILED=1
        BUILD_FAILED=1          PULL_ALL_FAILED=1  if [ "$PULL_ALL_FAILED" -eq 1 ]; then      fi
    else
        echo "All attempted images successfully pulled/refreshed." >&2    done        BUILD_FAILED=1
    fi
elseq 1 ]; thenages successfully pulled/refreshed." >&2 pull one or more required images before final tagging. Aborting." >&2
    if [ "$BUILD_FAILED" -ne 0 ]; thenl tagging. Aborting." >&2
        echo "Skipping pre-tagging pull verification due to earlier build failures." >&2
    else
        echo "No images were attempted, skipping pre-tagging pull verification." >&2
    fi
fielse        echo "No images were attempted, skipping pre-tagging pull verification." >&2    if [ "$BUILD_FAILED" -ne 0 ]; then
echo "--------------------------------------------------" >&2
s." >&2
# =========================================================================
# Create Final Timestamped Tag." >&2
# ==========================================================================================================================================
echo "--- Creating Final Timestamped Tag ---" >&2
if [ -n "$FINAL_FOLDER_TAG" ] && [ "$BUILD_FAILED" -eq 0 ]; then
    TIMESTAMPED_LATEST_TAG=$(echo "${DOCKER_USERNAME}/001:latest-${CURRENT_DATE_TIME}-1" | tr '[:upper:]' '[:lower:]')
    echo "Attempting to tag $FINAL_FOLDER_TAG as $TIMESTAMPED_LATEST_TAG" >&2=================; then

    # Verify base image exists locally before tagging== >&2
    echo "Verifying image $FINAL_FOLDER_TAG exists locally before tagging..." >&2tamped Tag ---" >&2then
    if verify_image_exists "$FINAL_FOLDER_TAG"; thenFOLDER_TAG" ] && [ "$BUILD_FAILED" -eq 0 ]; thene image exists locally before taggingLATEST_TAG=$(echo "${DOCKER_USERNAME}/001:latest-${CURRENT_DATE_TIME}-1" | tr '[:upper:]' '[:lower:]')
        echo "Image $FINAL_FOLDER_TAG found locally. Proceeding with tag." >&2RNAME}/001:latest-${CURRENT_DATE_TIME}-1" | tr '[:upper:]' '[:lower:]')sts locally before tagging..." >&2s $TIMESTAMPED_LATEST_TAG" >&2
        TAMPED_LATEST_TAG" >&2
        # Tag, push, and pull the final timestamped image
        if docker tag "$FINAL_FOLDER_TAG" "$TIMESTAMPED_LATEST_TAG"; then
            echo "Pushing $TIMESTAMPED_LATEST_TAG" >&2
            if docker push "$TIMESTAMPED_LATEST_TAG"; thenwith tag." >&2
                echo "Pulling final timestamped tag: $TIMESTAMPED_LATEST_TAG" >&2
                pull_output=$(docker pull "$TIMESTAMPED_LATEST_TAG" 2>&1)_LATEST_TAG"; then pull the final timestamped image
                pull_status=$?
                
                if [ $pull_status -eq 0 ]; then
                    # Verify final image exists locallyED_LATEST_TAG"; thenAMPED_LATEST_TAG" >&2
                    echo "Verifying final image $TIMESTAMPED_LATEST_TAG exists locally after pull..." >&2Pulling final timestamped tag: $TIMESTAMPED_LATEST_TAG" >&2pull_status -eq 0 ]; thenutput=$(docker pull "$TIMESTAMPED_LATEST_TAG" 2>&1)
                    if verify_image_exists "$TIMESTAMPED_LATEST_TAG"; then_output=$(docker pull "$TIMESTAMPED_LATEST_TAG" 2>&1)# Verify final image exists locally_status=$?
                        echo "Final image $TIMESTAMPED_LATEST_TAG verified locally." >&2
                        BUILT_TAGS+=("$TIMESTAMPED_LATEST_TAG")erify_image_exists "$TIMESTAMPED_LATEST_TAG"; then $pull_status -eq 0 ]; then
                        echo "Successfully created, pushed, and pulled final timestamped tag." >&2PED_LATEST_TAG verified locally." >&2ocally
                    else
                        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2..." >&22
                        echo "Error: Final image $TIMESTAMPED_LATEST_TAG NOT found locally after 'docker pull' succeeded." >&2erify_image_exists "$TIMESTAMPED_LATEST_TAG"; thenecho "Final image $TIMESTAMPED_LATEST_TAG verified locally." >&2
                        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2 locally." >&2!!!!!!" >&2
                        BUILD_FAILED=1ST_TAG")TAMPED_LATEST_TAG NOT found locally after 'docker pull' succeeded." >&2hed, and pulled final timestamped tag." >&2
                    fitamped tag." >&2>&2
                else
                    echo "Error: Failed to pull final timestamped tag $TIMESTAMPED_LATEST_TAG after push." >&2!!!!!!!!!" >&2." >&2
                    2
                    # Check for layer limit error!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2 Failed to pull final timestamped tag $TIMESTAMPED_LATEST_TAG after push." >&2ILED=1
                    if [[ "$pull_output" == *"max depth exceeded"* ]] && [ "$ENABLE_FLATTENING" = true ]; then
                        echo "DETECTED: Layer limit error when pulling final timestamped tag" >&2limit error
                        put" == *"max depth exceeded"* ]] && [ "$ENABLE_FLATTENING" = true ]; thenror: Failed to pull final timestamped tag $TIMESTAMPED_LATEST_TAG after push." >&2
                        if fix_layer_limit "$TIMESTAMPED_LATEST_TAG"; then pull final timestamped tag $TIMESTAMPED_LATEST_TAG after push." >&2yer limit error when pulling final timestamped tag" >&2
                            # Verify again after fixingyer limit error
                            if verify_image_exists "$TIMESTAMPED_LATEST_TAG"; theneck for layer limit errorif fix_layer_limit "$TIMESTAMPED_LATEST_TAG"; then[ "$pull_output" == *"max depth exceeded"* ]] && [ "$ENABLE_FLATTENING" = true ]; then
                                echo "Successfully pulled flattened final image." >&2t" == *"max depth exceeded"* ]] && [ "$ENABLE_FLATTENING" = true ]; thengain after fixing: Layer limit error when pulling final timestamped tag" >&2
                                BUILT_TAGS+=("$TIMESTAMPED_LATEST_TAG")  echo "DETECTED: Layer limit error when pulling final timestamped tag" >&2      if verify_image_exists "$TIMESTAMPED_LATEST_TAG"; then  
                                echo "Successfully created, pushed, and pulled final timestamped tag (after flattening)." >&2                    echo "Successfully pulled flattened final image." >&2      if fix_layer_limit "$TIMESTAMPED_LATEST_TAG"; then
                            else        if fix_layer_limit "$TIMESTAMPED_LATEST_TAG"; then                BUILT_TAGS+=("$TIMESTAMPED_LATEST_TAG")            # Verify again after fixing
                                BUILD_FAILED=1
                            fi verify_image_exists "$TIMESTAMPED_LATEST_TAG"; thense  echo "Successfully pulled flattened final image." >&2
                        else                  echo "Successfully pulled flattened final image." >&2                  BUILD_FAILED=1                  BUILT_TAGS+=("$TIMESTAMPED_LATEST_TAG")
                            BUILD_FAILED=1                    BUILT_TAGS+=("$TIMESTAMPED_LATEST_TAG")                fi                    echo "Successfully created, pushed, and pulled final timestamped tag (after flattening)." >&2
                        fistamped tag (after flattening)." >&2
                    else  else  BUILD_FAILED=1      BUILD_FAILED=1
                        BUILD_FAILED=1                      BUILD_FAILED=1              fi                  fi
                    fi                    fi            else                else
                fi
            else
                echo "Error: Failed to push final timestamped tag $TIMESTAMPED_LATEST_TAG." >&2
                BUILD_FAILED=1seD_FAILED=1
            fi                  BUILD_FAILED=1          echo "Error: Failed to push final timestamped tag $TIMESTAMPED_LATEST_TAG." >&2              fi
        else                fi            BUILD_FAILED=1            fi
            echo "Error: Failed to tag $FINAL_FOLDER_TAG as $TIMESTAMPED_LATEST_TAG." >&2
            BUILD_FAILED=1
        fi        echo "Error: Failed to push final timestamped tag $TIMESTAMPED_LATEST_TAG." >&2    echo "Error: Failed to tag $FINAL_FOLDER_TAG as $TIMESTAMPED_LATEST_TAG." >&2        BUILD_FAILED=1
    else
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2      fi  fi  else
        echo "Error: Image $FINAL_FOLDER_TAG not found locally right before tagging, despite pre-tagging pull attempt." >&2      else  else          echo "Error: Failed to tag $FINAL_FOLDER_TAG as $TIMESTAMPED_LATEST_TAG." >&2
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2            echo "Error: Failed to tag $FINAL_FOLDER_TAG as $TIMESTAMPED_LATEST_TAG." >&2        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2            BUILD_FAILED=1
        BUILD_FAILED=1-tagging pull attempt." >&2
    fi
else
    if [ "$BUILD_FAILED" -ne 0 ]; then!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2 right before tagging, despite pre-tagging pull attempt." >&2
        echo "Skipping final timestamped tag creation due to previous errors." >&2ght before tagging, despite pre-tagging pull attempt." >&2
    else      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2  if [ "$BUILD_FAILED" -ne 0 ]; then      BUILD_FAILED=1
        echo "Skipping final timestamped tag creation as no base image was successfully built/pushed/pulled." >&2
    fi    fi    elseelse
fi

echo "--------------------------------------------------" >&2s." >&2
echo "Build, Push, Pull, and Tagging process complete!" >&2
echo "Total images successfully built/pushed/pulled/verified: ${#BUILT_TAGS[@]}" >&2        echo "Skipping final timestamped tag creation as no base image was successfully built/pushed/pulled." >&2echo "--------------------------------------------------" >&2    fi
if [ "$BUILD_FAILED" -ne 0 ]; then
    echo "Warning: One or more steps failed. See logs above." >&2
fi
echo "--------------------------------------------------" >&2----------------------------------------" >&2g: One or more steps failed. See logs above." >&2h, Pull, and Tagging process complete!" >&2
 process complete!" >&2_TAGS[@]}" >&2
# =========================================================================[@]}" >&2
# Post-Build Steps - Options for final imageUILD_FAILED" -ne 0 ]; theng: One or more steps failed. See logs above." >&2
# =========================================================================    echo "Warning: One or more steps failed. See logs above." >&2# =========================================================================fi
echo "(Image pulling and verification now happens during build process)" >&2

# Run the very last successfully built & timestamped image (optional)
if [ -n "$TIMESTAMPED_LATEST_TAG" ] && [ "$BUILD_FAILED" -eq 0 ]; then======
    # Check if the timestamped tag is in the BUILT_TAGS array (validation)uild Steps - Options for final imagee very last successfully built & timestamped image (optional)===================================================================
    tag_exists=0============= ]; then process)" >&2
    for t in "${BUILT_TAGS[@]}"; do build process)" >&2rray (validation)
        [[ "$t" == "$TIMESTAMPED_LATEST_TAG" ]] && { tag_exists=1; break; }
    done image (optional)en

    if [[ "$tag_exists" -eq 1 ]]; then
        echo "--------------------------------------------------" >&2
        echo "Final Image: $TIMESTAMPED_LATEST_TAG" >&2g_exists=1; break; }
        echo "--------------------------------------------------" >&2ists=1; break; }-----" >&2
        nal Image: $TIMESTAMPED_LATEST_TAG" >&2
        if verify_image_exists "$TIMESTAMPED_LATEST_TAG"; then" >&2; then
            # Offer options for what to do with the imageists" -eq 1 ]]; then------------------------------------" >&2
            echo "What would you like to do with the final image?" >&2----" >&2en
            echo "1) Start an interactive shell" >&2
            echo "2) Run quick verification (common tools and packages)" >&2------------------------------------------" >&2 would you like to do with the final image?" >&2
            echo "3) Run full verification (all system packages, may be verbose)" >&2n interactive shell" >&2image_exists "$TIMESTAMPED_LATEST_TAG"; then
            echo "4) List installed apps in the container" >&2
            echo "5) Skip (do nothing)" >&2tions for what to do with the imageun full verification (all system packages, may be verbose)" >&2 would you like to do with the final image?" >&2
            read -p "Enter your choice (1-5): " user_choiceWhat would you like to do with the final image?" >&24) List installed apps in the container" >&21) Start an interactive shell" >&2
            
            case $user_choice inun quick verification (common tools and packages)" >&2nter your choice (1-5): " user_choiceun full verification (all system packages, may be verbose)" >&2
                1)3) Run full verification (all system packages, may be verbose)" >&2t installed apps in the container" >&2
                    echo "Starting interactive shell..." >&2
                    docker run -it --rm "$TIMESTAMPED_LATEST_TAG" bashkip (do nothing)" >&2 your choice (1-5): " user_choice
                    ;;p "Enter your choice (1-5): " user_choice  echo "Starting interactive shell..." >&2
                2)
                    verify_container_apps "$TIMESTAMPED_LATEST_TAG" "quick"_choice in
                    ;;  echo "Starting interactive shell..." >&2
                3)
                    verify_container_apps "$TIMESTAMPED_LATEST_TAG" "all"cker run -it --rm "$TIMESTAMPED_LATEST_TAG" bash
                    ;;    ;;3)2)
                4)    2)        verify_container_apps "$TIMESTAMPED_LATEST_TAG" "all"        verify_container_apps "$TIMESTAMPED_LATEST_TAG" "quick"
                    list_installed_apps "$TIMESTAMPED_LATEST_TAG"
                    ;;
                5)      3)          list_installed_apps "$TIMESTAMPED_LATEST_TAG"          verify_container_apps "$TIMESTAMPED_LATEST_TAG" "all"
                    echo "Skipping container run." >&2            verify_container_apps "$TIMESTAMPED_LATEST_TAG" "all"            ;;            ;;
                    ;;
                *)          4)              echo "Skipping container run." >&2              list_installed_apps "$TIMESTAMPED_LATEST_TAG"
                    echo "Invalid choice. Skipping container run." >&2                list_installed_apps "$TIMESTAMPED_LATEST_TAG"                ;;                ;;
                    ;;
            esac              5)                  echo "Invalid choice. Skipping container run." >&2                  echo "Skipping container run." >&2
        else                    echo "Skipping container run." >&2                    ;;                    ;;
            echo "Error: Final image $TIMESTAMPED_LATEST_TAG not found locally, cannot proceed." >&2
            BUILD_FAILED=1
        ficannot proceed." >&2
    else
        echo "Skipping options because the final tag was not successfully processed." >&2
    fi
elseor: Final image $TIMESTAMPED_LATEST_TAG not found locally, cannot proceed." >&2g options because the final tag was not successfully processed." >&2LED=1
    echo "No final image tag recorded or build failed, skipping further operations." >&2LED=1
fi

# =========================================================================tions because the final tag was not successfully processed." >&2
# Final Image Verification - Check Successfully Processed Images
# =========================================================================build failed, skipping further operations." >&2
echo "--------------------------------------------------" >&2kipping further operations." >&2d Images
# Verify against BUILT_TAGS to see if successfully processed images are present===========================
echo "--- Verifying all SUCCESSFULLY PROCESSED images exist locally ---" >&2--------------------------------" >&2===============================================================
VERIFICATION_FAILED=0============================================see if successfully processed images are presenteck Successfully Processed Images
# Use BUILT_TAGS here
if [ ${#BUILT_TAGS[@]} -gt 0 ]; then
    echo "Checking ${#BUILT_TAGS[@]} image(s) recorded as successful:" >&2-----------------------" >&2fully processed images are present
    # Use BUILT_TAGS heregainst BUILT_TAGS to see if successfully processed images are presentILT_TAGS[@]} -gt 0 ]; thenVerifying all SUCCESSFULLY PROCESSED images exist locally ---" >&2
    for tag in "${BUILT_TAGS[@]}"; do- Verifying all SUCCESSFULLY PROCESSED images exist locally ---" >&2 "Checking ${#BUILT_TAGS[@]} image(s) recorded as successful:" >&2TION_FAILED=0
        echo -n "Verifying $tag... " >&2VERIFICATION_FAILED=0    # Use BUILT_TAGS here# Use BUILT_TAGS here
        if docker image inspect "$tag" &>/dev/null; then
            echo "OK" >&2
        elsesful:" >&2
            echo "MISSING!" >&2
            # This error is more significant now, as this image *should* existAGS[@]}"; do&2
            echo "Error: Image '$tag', which successfully completed build/push/pull/verify earlier, was not found locally at final check." >&2
            VERIFICATION_FAILED=1 docker image inspect "$tag" &>/dev/null; then  # This error is more significant now, as this image *should* exist  echo "OK" >&2
        fi    echo "OK" >&2    echo "Error: Image '$tag', which successfully completed build/push/pull/verify earlier, was not found locally at final check." >&2else
    done
      echo "MISSING!" >&2  fi      # This error is more significant now, as this image *should* exist
    if [ "$VERIFICATION_FAILED" -eq 1 ]; then        # This error is more significant now, as this image *should* existdone        echo "Error: Image '$tag', which successfully completed build/push/pull/verify earlier, was not found locally at final check." >&2
        echo "Error: One or more successfully processed images were missing locally during final check." >&2ully completed build/push/pull/verify earlier, was not found locally at final check." >&2
        # Ensure BUILD_FAILED reflects this verification failure
        if [ "$BUILD_FAILED" -eq 0 ]; then      fi      echo "Error: One or more successfully processed images were missing locally during final check." >&2  done
           BUILD_FAILED=1    done        # Ensure BUILD_FAILED reflects this verification failure
           echo "(Marking build as failed due to final verification failure)" >&2
        fiTION_FAILED" -eq 1 ]; thenILED=1: One or more successfully processed images were missing locally during final check." >&2
    else locally during final check." >&2)" >&2
        echo "All successfully processed images verified successfully locally during final check." >&2ure
    fi ]; then
elsefinal check." >&2verification failure)" >&2
    # Message remains relevant if BUILT_TAGS is emptyon failure)" >&2
    echo "No images were recorded as successfully built/pushed/pulled/verified, skipping final verification." >&2
fielse# Message remains relevant if BUILT_TAGS is empty    echo "All successfully processed images verified successfully locally during final check." >&2
ck." >&2 verification." >&2
# =========================================================================
# Script Completion
# =========================================================================  # Message remains relevant if BUILT_TAGS is empty=========================================================================  echo "No images were recorded as successfully built/pushed/pulled/verified, skipping final verification." >&2
echo "--------------------------------------------------" >&2 echo "No images were recorded as successfully built/pushed/pulled/verified, skipping final verification." >&2cript Completion










EOFfi    exit 0  # Exit with success code    echo "--------------------------------------------------" >&2    echo "Build, push, pull, tag, verification, and run processes completed successfully!" >&2else    exit 1  # Exit with failure code    echo "--------------------------------------------------" >&2    echo "Script finished with one or more errors." >&2if [ "$BUILD_FAILED" -ne 0 ]; then















EOFfi    exit 0  # Exit with success code    echo "--------------------------------------------------" >&2    echo "Build, push, pull, tag, verification, and run processes completed successfully!" >&2else    exit 1  # Exit with failure code    echo "--------------------------------------------------" >&2    echo "Script finished with one or more errors." >&2if [ "$BUILD_FAILED" -ne 0 ]; thenecho "--------------------------------------------------" >&2# =========================================================================# Script Completion# =========================================================================fi











EOFfi    exit 0  # Exit with success code    echo "--------------------------------------------------" >&2    echo "Build, push, pull, tag, verification, and run processes completed successfully!" >&2else    exit 1  # Exit with failure code    echo "--------------------------------------------------" >&2    echo "Script finished with one or more errors." >&2if [ "$BUILD_FAILED" -ne 0 ]; thenecho "--------------------------------------------------" >&2# =========================================================================
# =========================================================================
# Script Completion
# =========================================================================
echo "--------------------------------------------------" >&2
if [ "$BUILD_FAILED" -ne 0 ]; then
    echo "Script finished with one or more errors." >&2
    echo "--------------------------------------------------" >&2
    exit 1  # Exit with failure code
else
    echo "Build, push, pull, tag, verification, and run processes completed successfully!" >&2
    echo "--------------------------------------------------" >&2
    exit 0  # Exit with success code
fi
EOF