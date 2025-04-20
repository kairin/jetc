#!/bin/bash
# COMMIT-TRACKING: UUID-20240803-180500-JRUN
# COMMIT-TRACKING: UUID-20240804-091500-DLGF
# COMMIT-TRACKING: UUID-20240804-175200-IMGV
# COMMIT-TRACKING: UUID-20240804-182500-X11F
# Description: Fix duplicate X11 mount points when running with jetson-containers.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Current directory
# │   └── jetcrun.sh             <- THIS FILE
# └── ...                        <- Other project files

# Ensure we're running with bash
if [ -z "$BASH_VERSION" ]; then
  echo "Error: This script requires bash. Please run with bash ./jetcrun.sh"
  exit 1
fi

# Get script directory more robustly
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")/scripts

# Embedded dialog check function in case external file can't be sourced
check_dialog_installed() {
  if ! command -v dialog >/dev/null 2>&1; then
    echo "Dialog not found. Falling back to basic prompts."
    return 1
  fi
  return 0
}

# Try to source external check_install_dialog.sh, fallback to embedded function
if [ -f "$SCRIPT_DIR/check_install_dialog.sh" ]; then
  # shellcheck disable=SC1090
  . "$SCRIPT_DIR/check_install_dialog.sh" || {
    echo "Warning: Could not source check_install_dialog.sh, using embedded function"
  }
fi

get_run_options() {
  local temp_file
  temp_file=$(mktemp)
  
  # Initialize variables with default values
  IMAGE_NAME=""
  ENABLE_X11="on"
  ENABLE_GPU="on"
  MOUNT_WORKSPACE="on"
  USER_ROOT="on"
  
  # Load previous settings and available images from .env file
  ENV_FILE="$(dirname "$(readlink -f "$0")")/.env"
  AVAILABLE_IMAGES=""
  if [ -f "$ENV_FILE" ]; then
    # Source the .env file to get previous settings
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    # Use the default values from .env if they exist
    [ -n "$DEFAULT_IMAGE_NAME" ] && IMAGE_NAME="$DEFAULT_IMAGE_NAME"
    [ -n "$DEFAULT_ENABLE_X11" ] && ENABLE_X11="$DEFAULT_ENABLE_X11"
    [ -n "$DEFAULT_ENABLE_GPU" ] && ENABLE_GPU="$DEFAULT_ENABLE_GPU"
    [ -n "$DEFAULT_MOUNT_WORKSPACE" ] && MOUNT_WORKSPACE="$DEFAULT_MOUNT_WORKSPACE"
    [ -n "$DEFAULT_USER_ROOT" ] && USER_ROOT="$DEFAULT_USER_ROOT"
    
    # Load available images from .env
    AVAILABLE_IMAGES="${AVAILABLE_IMAGES:-$DEFAULT_IMAGE_NAME}" # Start with at least the default image
  fi
  
  # Convert semicolon-separated AVAILABLE_IMAGES to array
  IFS=';' read -r -a image_array <<< "$AVAILABLE_IMAGES"
  
  # Add default base image if not already in the list
  if [ -n "$DEFAULT_BASE_IMAGE" ] && ! [[ "$AVAILABLE_IMAGES" == *"$DEFAULT_BASE_IMAGE"* ]]; then
    image_array+=("$DEFAULT_BASE_IMAGE")
  fi
  
  # Add the current default image if not already in the list
  if [ -n "$DEFAULT_IMAGE_NAME" ] && ! [[ "$AVAILABLE_IMAGES" == *"$DEFAULT_IMAGE_NAME"* ]]; then
    image_array+=("$DEFAULT_IMAGE_NAME")
  fi

  # Try the external function first, fallback to embedded one
  if command -v check_install_dialog >/dev/null 2>&1; then
    DIALOG_AVAILABLE=$(check_install_dialog && echo "yes" || echo "no")
  else
    DIALOG_AVAILABLE=$(check_dialog_installed && echo "yes" || echo "no")
  fi

  if [ "$DIALOG_AVAILABLE" = "yes" ]; then
    # Create a temporary file for the menu selection
    menu_file=$(mktemp)
    
    # If we have available images, show image selection menu
    if [ ${#image_array[@]} -gt 0 ]; then
      # Build menu items for dialog
      menu_items=()
      for ((i=0; i<${#image_array[@]}; i++)); do
        # Set the current default image as selected
        status="off"
        if [ "${image_array[$i]}" = "$IMAGE_NAME" ]; then
          status="on"
        fi
        menu_items+=("${image_array[$i]}" "Use this image" "$status")
      done
      
      # Add option for custom image
      menu_items+=("custom" "Enter a custom image name" "off")
      
      # Show image selection dialog
      dialog --backtitle "Jetson Container Run" \
        --title "Select Container Image" \
        --radiolist "Choose an image or enter a custom one:" 20 80 10 \
        "${menu_items[@]}" 2>"$menu_file"
      
      if [ $? -eq 0 ]; then
        selection=$(cat "$menu_file")
        if [ "$selection" = "custom" ]; then
          # User selected custom image option, prompt for image name
          dialog --backtitle "Jetson Container Run" \
            --title "Custom Container Image" \
            --inputbox "Enter container image name:" 8 60 \
            2>"$menu_file"
          
          if [ $? -eq 0 ]; then
            IMAGE_NAME=$(cat "$menu_file")
            # Check if we should add this to available images
            dialog --backtitle "Jetson Container Run" \
              --title "Save Custom Image" \
              --yesno "Add this image to your saved images list?" 6 60
            if [ $? -eq 0 ]; then
              # Add to image array if not already there
              if ! [[ " ${image_array[*]} " =~ " ${IMAGE_NAME} " ]]; then
                image_array+=("$IMAGE_NAME")
              fi
            fi
          else
            rm -f "$menu_file"
            echo "Operation cancelled."
            exit 1
          fi
        else
          IMAGE_NAME="$selection"
        fi
      else
        rm -f "$menu_file"
        echo "Operation cancelled."
        exit 1
      fi
      rm -f "$menu_file"
    else
      # No available images, directly prompt for image name
      dialog --backtitle "Jetson Container Run" \
        --title "Container Image" \
        --inputbox "Enter container image name:" 8 60 "$IMAGE_NAME" \
        2>"$temp_file"
      if [ $? -ne 0 ]; then
        rm -f "$temp_file"
        echo "Operation cancelled."
        exit 1
      fi
      IMAGE_NAME=$(cat "$temp_file" | tr -d '\n')
    fi
    
    # Continue with runtime options as before
    dialog --backtitle "Jetson Container Run" \
      --title "Runtime Options" \
      --checklist "Select runtime options:" 12 60 4 \
      "X11" "Enable X11 forwarding" $ENABLE_X11 \
      "GPU" "Enable all GPUs" $ENABLE_GPU \
      "WORKSPACE" "Mount /media/kkk:/workspace" $MOUNT_WORKSPACE \
      "ROOT" "Run as root user" $USER_ROOT \
      2>"$temp_file"
    local checklist
    checklist=$(cat "$temp_file")
    rm -f "$temp_file"
    case "$checklist" in *"X11"*) ENABLE_X11="on";; *) ENABLE_X11="off";; esac
    case "$checklist" in *"GPU"*) ENABLE_GPU="on";; *) ENABLE_GPU="off";; esac
    case "$checklist" in *"WORKSPACE"*) MOUNT_WORKSPACE="on";; *) MOUNT_WORKSPACE="off";; esac
    case "$checklist" in *"ROOT"*) USER_ROOT="on";; *) USER_ROOT="off";; esac
  else
    # Text-based selection for available images
    if [ ${#image_array[@]} -gt 0 ]; then
      echo "Available container images:"
      for ((i=0; i<${#image_array[@]}; i++)); do
        echo "[$((i+1))] ${image_array[$i]}"
      done
      echo "[c] Enter a custom image name"
      
      read -r -p "Select an option [1-${#image_array[@]}/c]: " img_choice
      
      if [[ "$img_choice" == "c" ]]; then
        read -r -p "Enter the container image name: " IMAGE_NAME
        read -r -p "Add this image to your saved images list? (y/n) [n]: " save_img
        if [[ "${save_img:-n}" == "y" ]]; then
          # Add to image array if not already there
          if ! [[ " ${image_array[*]} " =~ " ${IMAGE_NAME} " ]]; then
            image_array+=("$IMAGE_NAME")
          fi
        fi
      elif [[ "$img_choice" =~ ^[0-9]+$ ]] && [ "$img_choice" -ge 1 ] && [ "$img_choice" -le ${#image_array[@]} ]; then
        IMAGE_NAME="${image_array[$((img_choice-1))]}"
      else
        echo "Invalid selection. Using default or prompting for manual entry."
        read -r -p "Enter the container image name (e.g., kairin/001:latest-YYYYMMDD-HHMMSS-N): " IMAGE_NAME
      fi
    else
      read -r -p "Enter the container image name (e.g., kairin/001:latest-YYYYMMDD-HHMMSS-N): " IMAGE_NAME
    fi
    
    echo "Image name from prompt: '$IMAGE_NAME'"
    read -r -p "Enable X11 forwarding? (y/n) [y]: " x11
    ENABLE_X11=${x11:-y}
    read -r -p "Enable all GPUs? (y/n) [y]: " gpu
    ENABLE_GPU=${gpu:-y}
    read -r -p "Mount /media/kkk:/workspace? (y/n) [y]: " ws
    MOUNT_WORKSPACE=${ws:-y}
    read -r -p "Run as root user? (y/n) [y]: " root
    USER_ROOT=${root:-y}
  fi

  # Strengthen validation with better error message
  if [ -z "$IMAGE_NAME" ] || [ "$IMAGE_NAME" = '""' ] || [ "$IMAGE_NAME" = "''" ]; then
    echo "Error: No valid image name provided or empty name was entered. Exiting."
    exit 1
  fi

  # Save image name and available images to .env file for future reference
  ENV_FILE="$(dirname "$(readlink -f "$0")")/.env"
  if [ -f "$ENV_FILE" ]; then
    # Update all settings in .env file
    for setting in "IMAGE_NAME=$IMAGE_NAME" "ENABLE_X11=$ENABLE_X11" "ENABLE_GPU=$ENABLE_GPU" "MOUNT_WORKSPACE=$MOUNT_WORKSPACE" "USER_ROOT=$USER_ROOT"; do
      name="${setting%%=*}"
      value="${setting#*=}"
      default_name="DEFAULT_$name"
      
      if grep -q "^$default_name=" "$ENV_FILE"; then
        # Replace existing line
        sed -i "s|^$default_name=.*|$default_name=$value|" "$ENV_FILE"
      else
        # Add new line
        echo "# Last used $name setting" >> "$ENV_FILE"
        echo "$default_name=$value" >> "$ENV_FILE"
      fi
    done
    
    # Save the image as DEFAULT_BASE_IMAGE if requested or if it doesn't exist
    if ! grep -q "^DEFAULT_BASE_IMAGE=" "$ENV_FILE"; then
      echo "# Default base image for builds" >> "$ENV_FILE"
      echo "DEFAULT_BASE_IMAGE=$IMAGE_NAME" >> "$ENV_FILE"
    fi
    
    # Update AVAILABLE_IMAGES
    AVAILABLE_IMAGES=$(IFS=';'; echo "${image_array[*]}")
    if grep -q "^AVAILABLE_IMAGES=" "$ENV_FILE"; then
      # Replace existing line
      sed -i "s|^AVAILABLE_IMAGES=.*|AVAILABLE_IMAGES=$AVAILABLE_IMAGES|" "$ENV_FILE"
    else
      # Add new line
      echo "# Available container images (semicolon-separated)" >> "$ENV_FILE"
      echo "AVAILABLE_IMAGES=$AVAILABLE_IMAGES" >> "$ENV_FILE"
    fi
    
    echo "Settings saved to .env file for future use."
  else
    echo "Warning: .env file not found, cannot save settings for future reference."
  fi

  RUN_OPTS=""
  [ "$ENABLE_GPU" = "on" ] || [ "$ENABLE_GPU" = "y" ] && RUN_OPTS="$RUN_OPTS --gpus all"
  [ "$MOUNT_WORKSPACE" = "on" ] || [ "$MOUNT_WORKSPACE" = "y" ] && RUN_OPTS="$RUN_OPTS -v /media/kkk:/workspace"
  
  # Store X11 preference but don't add to options yet
  X11_ENABLED="false"
  [ "$ENABLE_X11" = "on" ] || [ "$ENABLE_X11" = "y" ] && X11_ENABLED="true"
  
  [ "$USER_ROOT" = "on" ] || [ "$USER_ROOT" = "y" ] && RUN_OPTS="$RUN_OPTS --user root"
  RUN_OPTS="$RUN_OPTS -it --rm"

  # Make sure to capture the image name in the main script context
  echo "IMAGE_NAME=$IMAGE_NAME" > /tmp/jetcrun_vars.sh
  echo "RUN_OPTS=$RUN_OPTS" >> /tmp/jetcrun_vars.sh
  echo "X11_ENABLED=$X11_ENABLED" >> /tmp/jetcrun_vars.sh

  export IMAGE_NAME
  export RUN_OPTS
  export X11_ENABLED
}

get_run_options

# Source the variables to ensure they're available in main script context
[ -f /tmp/jetcrun_vars.sh ] && source /tmp/jetcrun_vars.sh && rm -f /tmp/jetcrun_vars.sh

# Add debug line
echo "After function, image name is: '$IMAGE_NAME'"

# Verify IMAGE_NAME is set before running container
if [ -z "$IMAGE_NAME" ] || [ "$IMAGE_NAME" = '""' ] || [ "$IMAGE_NAME" = "''" ]; then
  echo "Error: Something went wrong - image name is empty. Cannot run container."
  exit 1
fi

# Prepare command based on whether we're using jetson-containers or direct docker run
USE_JETSON_CONTAINERS=true
FINAL_RUN_OPTS="$RUN_OPTS"

if [ "$USE_JETSON_CONTAINERS" = true ]; then
  # When using jetson-containers, don't add X11 arguments as they're handled internally
  echo "Using jetson-containers for container execution"
  RUN_CMD="jetson-containers run"
  
  # Add X11 flag for jetson-containers if needed
  if [ "$X11_ENABLED" = "true" ]; then
    # jetson-containers already handles X11 forwarding internally
    echo "X11 forwarding will be handled by jetson-containers"
  fi
else
  # For direct Docker execution, add X11 settings explicitly
  echo "Using direct Docker execution"
  RUN_CMD="docker run"
  if [ "$X11_ENABLED" = "true" ]; then
    FINAL_RUN_OPTS="$FINAL_RUN_OPTS -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=$DISPLAY"
  fi
fi

echo "Running container with image: $IMAGE_NAME"
echo "Run options: $FINAL_RUN_OPTS"

# Add confirmation step
echo ""
echo "The container will be run with the following options:"
echo "  - Image: $IMAGE_NAME"
echo "  - Options: $FINAL_RUN_OPTS"
echo "  - Command: $RUN_CMD"
read -p "Do you want to continue with these options? (y/n) [y]: " confirm
confirm=${confirm:-y}
if [[ $confirm != [Yy]* ]]; then
  echo "Operation cancelled."
  exit 0
fi

# Check if the image exists locally
if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
  # Modify image name to add -py3 suffix for pulling
  PULL_IMAGE="${IMAGE_NAME}-py3"
  echo "Image $IMAGE_NAME not found locally. Pulling $PULL_IMAGE..."
  if docker pull "$PULL_IMAGE"; then
    echo "Pull completed successfully."
    # Tag the pulled image with the original name for consistency
    docker tag "$PULL_IMAGE" "$IMAGE_NAME"
  else
    echo "Error: Failed to pull image $PULL_IMAGE"
    exit 1
  fi
fi

# Run the container with the appropriate command
echo "Starting container..."
$RUN_CMD $FINAL_RUN_OPTS "$IMAGE_NAME" /bin/bash
