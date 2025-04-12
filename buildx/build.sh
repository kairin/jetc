#!/bin/bash

# Load environment variables from the .env file
if [ -f .env ]; then
  set -a
  source .env
  set +a
else
  echo ".env file not found!" >&2
  exit 1
fi

# Ensure DOCKER_USERNAME is set
if [ -z "$DOCKER_USERNAME" ]; then
  echo "Error: DOCKER_USERNAME is not set. Please define it in the .env file." >&2
  exit 1
fi

# Get the current date and time formatted as YYYYMMDD-HHMMSS
CURRENT_DATE_TIME=$(date +"%Y%m%d-%H%M%S")

# Determine the current platform
ARCH=$(uname -m)

if [ "$ARCH" != "aarch64" ]; then
    echo "This script is only intended to build for aarch64 devices." >&2
    exit 1
fi

PLATFORM="linux/arm64"

# Array to store the tags of successfully built/pushed/pulled images
BUILT_TAGS=()
# Variable to store the tag of the most recently successfully built image (for chaining numbered builds)
LATEST_SUCCESSFUL_NUMBERED_TAG=""
# Variable to store the fixed tag of the very last successfully built folder image
FINAL_FOLDER_TAG=""
# Variable to store the final timestamped tag name
TIMESTAMPED_LATEST_TAG=""
# Flag to track if any build failed
BUILD_FAILED=0

# Check if the builder already exists
if ! docker buildx inspect jetson-builder &>/dev/null; then
  # Create the builder instance if it doesn't exist
  echo "Creating buildx builder: jetson-builder" >&2
  docker buildx create --name jetson-builder
fi

# Use the builder instance
docker buildx use jetson-builder

# Ask if the user wants to build with or without cache
read -p "Do you want to build with cache? (y/n): " use_cache
while [[ "$use_cache" != "y" && "$use_cache" != "n" ]]; do
  echo "Invalid input. Please enter 'y' for yes or 'n' for no." >&2
  read -p "Do you want to build with cache? (y/n): " use_cache
done

# Function to build, push, and pull a Docker image from a folder
# Arguments: $1 = folder path, $2 = base image tag (optional)
# Returns: The fixed tag name on success (echo), non-zero status on failure
build_folder_image() {
  local folder=$1
  local base_tag_arg=$2 # The tag to pass as BASE_IMAGE build-arg
  local image_name=$(basename "$folder" | tr '[:upper:]' '[:lower:]') # Ensure image_name is lowercase

  # --- Fixed Tag Generation ---
  local fixed_tag=$(echo "${DOCKER_USERNAME}/001:${image_name}" | tr '[:upper:]' '[:lower:]')
  echo "Generating fixed tag: $fixed_tag" >&2
  # --- End Tag Generation ---

  # Check if Dockerfile exists
  if [ ! -f "$folder/Dockerfile" ]; then
    echo "Warning: Dockerfile not found in $folder. Skipping." >&2
    return 1 # Indicate skip/failure
  fi

  # Construct build arguments
  local build_args=()
  if [ -n "$base_tag_arg" ]; then
      build_args+=(--build-arg "BASE_IMAGE=$base_tag_arg")
      echo "Using base image build arg: $base_tag_arg" >&2
  else
      echo "No base image build arg provided (likely the first image)." >&2
  fi

  # Print informational messages to stderr
  echo "--------------------------------------------------" >&2
  echo "Building and pushing image from folder: $folder" >&2
  echo "Image Name (derived): $image_name" >&2
  echo "Platform: $PLATFORM" >&2
  echo "Tag (Fixed): $fixed_tag" >&2
  echo "--------------------------------------------------" >&2

  # Build and push the image
  local cmd_args=("--platform" "$PLATFORM" "-t" "$fixed_tag" "${build_args[@]}" --push "$folder")
  if [ "$use_cache" != "y" ]; then
      cmd_args=("--no-cache" "${cmd_args[@]}")
  fi

  docker buildx build "${cmd_args[@]}"

  # Check if the build and push succeeded
  if [ $? -ne 0 ]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
    echo "Error: Failed to build and push image for $image_name ($folder)." >&2
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
    BUILD_FAILED=1 # Set the global failure flag
    return 1 # Indicate failure
  fi

  # Pull the image immediately after successful push
  echo "Pulling built image: $fixed_tag" >&2
  docker pull "$fixed_tag"
  if [ $? -ne 0 ]; then
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
      echo "Error: Failed to pull the built image $fixed_tag after push." >&2
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
      BUILD_FAILED=1 # Set the global failure flag
      return 1 # Indicate failure (even though build+push succeeded, we need it locally)
  fi

  # Add the fixed tag to our array ONLY if successful build, push, and pull
  BUILT_TAGS+=("$fixed_tag")

  # Output the fixed tag to stdout
  echo "$fixed_tag"
  return 0 # Indicate success
}

# --- Determine Build Order ---
echo "Determining build order..." >&2
BUILD_DIR="build"
mapfile -t numbered_dirs < <(find "$BUILD_DIR" -maxdepth 1 -mindepth 1 -type d -name '[0-9]*-*' | sort)
mapfile -t other_dirs < <(find "$BUILD_DIR" -maxdepth 1 -mindepth 1 -type d ! -name '[0-9]*-*' | sort)

# --- Build Process ---
echo "Starting build process..." >&2

# 1. Build Numbered Directories in Order
echo "--- Building Numbered Directories ---" >&2
if [ ${#numbered_dirs[@]} -eq 0 ]; then
    echo "No numbered directories found in $BUILD_DIR." >&2
else
    for dir in "${numbered_dirs[@]}"; do
      echo "Processing numbered directory: $dir" >&2
      # Pass the LATEST_SUCCESSFUL_NUMBERED_TAG as the base for the *next* build
      tag=$(build_folder_image "$dir" "$LATEST_SUCCESSFUL_NUMBERED_TAG")
      if [ $? -eq 0 ]; then
          LATEST_SUCCESSFUL_NUMBERED_TAG="$tag" # Update for the next numbered iteration
          FINAL_FOLDER_TAG="$tag"             # Update the overall last successful folder tag
          echo "Successfully built, pushed, and pulled numbered image: $LATEST_SUCCESSFUL_NUMBERED_TAG" >&2
      else
          echo "Build, push or pull failed for $dir. Subsequent dependent builds might fail." >&2
          # BUILD_FAILED is already set within build_folder_image
          # Optionally break here if one failure should stop everything:
          # break
      fi
    done
fi

# 2. Build Other Directories
echo "--- Building Other Directories ---" >&2
if [ ${#other_dirs[@]} -eq 0 ]; then
    echo "No non-numbered directories found in $BUILD_DIR." >&2
elif [ "$BUILD_FAILED" -ne 0 ]; then
    echo "Skipping other directories due to previous build failures." >&2
else
    # Use the tag from the LAST successfully built numbered image as the base for ALL others
    BASE_FOR_OTHERS="$LATEST_SUCCESSFUL_NUMBERED_TAG"
    echo "Using base image for others: $BASE_FOR_OTHERS" >&2

    for dir in "${other_dirs[@]}"; do
      echo "Processing other directory: $dir" >&2
      tag=$(build_folder_image "$dir" "$BASE_FOR_OTHERS")
      if [ $? -eq 0 ]; then
          FINAL_FOLDER_TAG="$tag" # Update the overall last successful folder tag
          echo "Successfully built, pushed, and pulled other image: $tag" >&2
      else
          echo "Build, push or pull failed for $dir." >&2
          # BUILD_FAILED is already set within build_folder_image
          # Optionally break here:
          # break
      fi
    done
fi

echo "--------------------------------------------------" >&2
echo "Folder build process complete!" >&2

# 3. Create Final Timestamped Tag
echo "--- Creating Final Timestamped Tag ---" >&2
if [ -n "$FINAL_FOLDER_TAG" ] && [ "$BUILD_FAILED" -eq 0 ]; then
    TIMESTAMPED_LATEST_TAG=$(echo "${DOCKER_USERNAME}/001:latest-${CURRENT_DATE_TIME}-1" | tr '[:upper:]' '[:lower:]')
    echo "Tagging $FINAL_FOLDER_TAG as $TIMESTAMPED_LATEST_TAG" >&2
    if docker tag "$FINAL_FOLDER_TAG" "$TIMESTAMPED_LATEST_TAG"; then
        echo "Pushing $TIMESTAMPED_LATEST_TAG" >&2
        if docker push "$TIMESTAMPED_LATEST_TAG"; then
            echo "Pulling final timestamped tag: $TIMESTAMPED_LATEST_TAG" >&2
            if docker pull "$TIMESTAMPED_LATEST_TAG"; then
                BUILT_TAGS+=("$TIMESTAMPED_LATEST_TAG") # Add to list only after successful pull
                echo "Successfully created, pushed, and pulled final timestamped tag." >&2
            else
                echo "Error: Failed to pull final timestamped tag $TIMESTAMPED_LATEST_TAG after push." >&2
                BUILD_FAILED=1 # Mark failure
            fi
        else
            echo "Error: Failed to push final timestamped tag $TIMESTAMPED_LATEST_TAG." >&2
            BUILD_FAILED=1 # Mark failure
        fi
    else
        echo "Error: Failed to tag $FINAL_FOLDER_TAG as $TIMESTAMPED_LATEST_TAG." >&2
        BUILD_FAILED=1 # Mark failure
    fi
else
    if [ "$BUILD_FAILED" -ne 0 ]; then
        echo "Skipping final timestamped tag creation due to previous errors." >&2
    else
        echo "Skipping final timestamped tag creation as no base image was successfully built/pushed/pulled." >&2
    fi
fi

echo "--------------------------------------------------" >&2
echo "Build, Push, Pull, and Tagging process complete!" >&2
echo "Total images successfully built/pushed/pulled: ${#BUILT_TAGS[@]}" >&2
if [ "$BUILD_FAILED" -ne 0 ]; then
    echo "Warning: One or more steps failed. See logs above." >&2
fi
echo "--------------------------------------------------" >&2


# --- Post-Build Steps ---

# Pulling is now done immediately after each successful build/push.
# The section below is no longer needed.
# if [ ${#BUILT_TAGS[@]} -gt 0 ]; then
#   echo "Pulling all successfully built/tagged images..." >&2
#   PULL_FAILED=0
#   for tag in "${BUILT_TAGS[@]}"; do
#     echo "Pulling image: $tag" >&2
#     docker pull "$tag"
#     if [ $? -ne 0 ]; then
#       echo "Error: Failed to pull the image $tag." >&2
#       PULL_FAILED=1
#     fi
#   done
#   if [ "$PULL_FAILED" -eq 0 ]; then
#       echo "All successfully built/tagged images pulled." >&2
#   else
#       echo "Warning: Failed to pull one or more images." >&2
#       # Optional: Set BUILD_FAILED=1 here if pull failure is critical
#   fi
# else
#   echo "No images were successfully built/tagged, skipping pull step." >&2
# fi
echo "(Image pulling now happens immediately after each successful build/push)" >&2

# Run the very last successfully built & timestamped image (optional)
if [ -n "$TIMESTAMPED_LATEST_TAG" ] && [ "$BUILD_FAILED" -eq 0 ]; then
    # Check if the timestamped tag is in the BUILT_TAGS array (it should be if tagging/pushing/pulling succeeded)
    tag_exists=0
    for t in "${BUILT_TAGS[@]}"; do [[ "$t" == "$TIMESTAMPED_LATEST_TAG" ]] && { tag_exists=1; break; }; done

    if [[ "$tag_exists" -eq 1 ]]; then
        echo "--------------------------------------------------" >&2
        echo "Attempting to run the final timestamped image: $TIMESTAMPED_LATEST_TAG" >&2
        echo "--------------------------------------------------" >&2
        # Ensure the image exists locally before running (redundant check if pull worked, but safe)
        if docker image inspect "$TIMESTAMPED_LATEST_TAG" &> /dev/null; then
            docker run -it --rm "$TIMESTAMPED_LATEST_TAG" bash
            if [ $? -ne 0 ]; then
              echo "Error: Failed to run the image $TIMESTAMPED_LATEST_TAG." >&2
              # Decide if this should cause the script to exit with failure
              # BUILD_FAILED=1
            fi
        else
            echo "Error: Final image $TIMESTAMPED_LATEST_TAG not found locally, cannot run." >&2
            BUILD_FAILED=1
        fi
    else
        echo "Skipping run step because the final timestamped tag ($TIMESTAMPED_LATEST_TAG) was not successfully pushed/pulled/recorded." >&2
    fi
else
    echo "No final timestamped image tag recorded or build/push/pull failed, skipping run step." >&2
fi


# Announce completion and final status
echo "--------------------------------------------------" >&2
if [ "$BUILD_FAILED" -ne 0 ]; then
    echo "Script finished with one or more errors." >&2
    echo "--------------------------------------------------" >&2
    exit 1 # Exit with failure code if any build failed
else
    echo "Build, push, pull, tag, and (optionally) run processes completed successfully!" >&2
    echo "--------------------------------------------------" >&2
    exit 0 # Exit with success code
fi