#!/bin/bash

# Function to log messages
log_message() {
  local message="$1"
  echo "$message" | tee -a "${MAIN_LOG}"
}

# Function to handle build errors
handle_build_error() {
  local folder="$1"
  local error_code="$2"
  echo "Build process for $folder exited with code $error_code" | tee -a "${ERROR_LOG}"
  echo "Continuing with next build..." | tee -a "${MAIN_LOG}"
}

# Function to set the base image
set_base_image() {
  local new_image="$1"
  CURRENT_BASE_IMAGE="$new_image"
  echo "Next base image will be: $CURRENT_BASE_IMAGE" | tee -a "${MAIN_LOG}"
}

# Function to update available images in .env
update_available_images_in_env() {
  local new_image="$1"
  if [ -f "$ENV_FILE" ]; then
    if grep -q "^AVAILABLE_IMAGES=" "$ENV_FILE"; then
      sed -i "s|^AVAILABLE_IMAGES=.*|&;$new_image|" "$ENV_FILE"
    else
      echo "AVAILABLE_IMAGES=$new_image" >> "$ENV_FILE"
    fi
  fi
}
