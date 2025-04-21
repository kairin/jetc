#!/bin/bash

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
  AVAILABLE_IMAGES_STR="" # Renamed to avoid conflict with array name
  DEFAULT_BASE_IMAGE="" # Ensure it's initialized
  DEFAULT_IMAGE_NAME="" # Ensure it's initialized
  
  if [ -f "$ENV_FILE" ]; then
    echo "Loading settings from $ENV_FILE..."
    # Source the .env file to get previous settings and available images
    # Use grep and eval for safer sourcing of specific variables if needed,
    # or ensure .env content is trusted. For simplicity, using source.
    set -a # Automatically export variables
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a # Stop exporting
    
    # Use the default values from .env if they exist
    IMAGE_NAME="${DEFAULT_IMAGE_NAME:-}" # Use last used image as initial selection
    ENABLE_X11="${DEFAULT_ENABLE_X11:-on}"
    ENABLE_GPU="${DEFAULT_ENABLE_GPU:-on}"
    MOUNT_WORKSPACE="${DEFAULT_MOUNT_WORKSPACE:-on}"
    USER_ROOT="${DEFAULT_USER_ROOT:-on}"
    
    # Load available images string from .env
    AVAILABLE_IMAGES_STR="${AVAILABLE_IMAGES:-}" # Load the semicolon-separated string
    echo "  Loaded AVAILABLE_IMAGES: $AVAILABLE_IMAGES_STR"
    echo "  Loaded DEFAULT_IMAGE_NAME: $DEFAULT_IMAGE_NAME"
    echo "  Loaded DEFAULT_BASE_IMAGE: $DEFAULT_BASE_IMAGE"
  else
    echo "Warning: .env file not found at $ENV_FILE. Cannot load previous settings or available images."
  fi
  
  # Convert semicolon-separated AVAILABLE_IMAGES_STR to array, removing duplicates and empty entries
  declare -A seen_images # Use associative array for quick duplicate check
  declare -a image_array=() # Final array of unique images
  
  # Add DEFAULT_BASE_IMAGE first if it exists and is not empty
  if [[ -n "$DEFAULT_BASE_IMAGE" ]] && [[ ! ${seen_images["$DEFAULT_BASE_IMAGE"]} ]]; then
      image_array+=("$DEFAULT_BASE_IMAGE")
      seen_images["$DEFAULT_BASE_IMAGE"]=1
      echo "  Added DEFAULT_BASE_IMAGE to list: $DEFAULT_BASE_IMAGE"
  fi
  
  # Add DEFAULT_IMAGE_NAME (last used) if it exists, is not empty, and not already added
  if [[ -n "$DEFAULT_IMAGE_NAME" ]] && [[ ! ${seen_images["$DEFAULT_IMAGE_NAME"]} ]]; then
      image_array+=("$DEFAULT_IMAGE_NAME")
      seen_images["$DEFAULT_IMAGE_NAME"]=1
      echo "  Added DEFAULT_IMAGE_NAME to list: $DEFAULT_IMAGE_NAME"
  fi
  
  # Process AVAILABLE_IMAGES_STR from .env
  IFS=';' read -r -a env_images <<< "$AVAILABLE_IMAGES_STR"
  for img in "${env_images[@]}"; do
      if [[ -n "$img" ]] && [[ ! ${seen_images["$img"]} ]]; then
          image_array+=("$img")
          seen_images["$img"]=1
          echo "  Added image from AVAILABLE_IMAGES: $img"
      fi
  done
  
  # Ensure the currently selected IMAGE_NAME (likely DEFAULT_IMAGE_NAME) is in the list
  if [[ -n "$IMAGE_NAME" ]] && [[ ! ${seen_images["$IMAGE_NAME"]} ]]; then
      image_array+=("$IMAGE_NAME")
      seen_images["$IMAGE_NAME"]=1
      echo "  Added current IMAGE_NAME to list: $IMAGE_NAME"
  fi

  echo "Final unique image list for selection: ${image_array[*]}"

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
      default_selected=0
      for ((i=0; i<${#image_array[@]}; i++)); do
        # Set the current IMAGE_NAME as selected by default
        status="off"
        if [ "${image_array[$i]}" = "$IMAGE_NAME" ]; then
          status="on"
          default_selected=1
        fi
        # Use index+1 as tag, image name as item, status as state
        menu_items+=("$((i+1))" "${image_array[$i]}" "$status")
      done

      # If IMAGE_NAME wasn't in the list initially, ensure something is selected
      # Or, if IMAGE_NAME was empty, select the first item.
      if [[ "$default_selected" -eq 0 ]] && [[ ${#menu_items[@]} -gt 0 ]]; then
          # Select the first item if nothing else matched
          menu_items[2]="on" # Set status of the first item to 'on'
          IMAGE_NAME="${menu_items[1]}" # Update IMAGE_NAME to the first item's name
          echo "  Defaulting selection to first image: $IMAGE_NAME"
      fi
      
      # Add option for custom image
      menu_items+=("custom" "Enter a custom image name" "off")
      
      # Show image selection dialog using radiolist with tags
      dialog --backtitle "Jetson Container Run" \
        --title "Select Container Image" \
        --radiolist "Choose an image or enter a custom one (use Space to select):" 20 80 ${#image_array[@]} \
        "${menu_items[@]}" 2>"$menu_file"
      
      exit_status=$?
      selection_tag=$(cat "$menu_file")
      rm -f "$menu_file"

      if [ $exit_status -eq 0 ]; then
        if [ "$selection_tag" = "custom" ]; then
          # User selected custom image option, prompt for image name
          dialog --backtitle "Jetson Container Run" \
            --title "Custom Container Image" \
            --inputbox "Enter container image name:" 8 60 \
            2>"$menu_file"
          
          exit_status=$?
          custom_image_name=$(cat "$menu_file")
          rm -f "$menu_file"

          if [ $exit_status -eq 0 ]; then
            IMAGE_NAME="$custom_image_name"
            # Check if we should add this to available images
            dialog --backtitle "Jetson Container Run" \
              --title "Save Custom Image" \
              --yesno "Add '$IMAGE_NAME' to your saved images list?" 6 60
            if [ $? -eq 0 ]; then
              # Add to image array if not already there
              if ! [[ " ${image_array[*]} " =~ " ${IMAGE_NAME} " ]]; then
                image_array+=("$IMAGE_NAME")
                echo "  Added custom image to list: $IMAGE_NAME"
              fi
            fi
          else
            echo "Operation cancelled."
            exit 1
          fi
        else
          # User selected an existing image via its tag (index+1)
          # Find the image name corresponding to the selected tag
          selected_index=$((selection_tag - 1))
          if [[ "$selected_index" -ge 0 ]] && [[ "$selected_index" -lt ${#image_array[@]} ]]; then
              IMAGE_NAME="${image_array[$selected_index]}"
              echo "  Selected image: $IMAGE_NAME"
          else
              echo "Error: Invalid selection tag '$selection_tag'. Exiting."
              exit 1
          fi
        fi
      else
        echo "Operation cancelled."
        exit 1
      fi
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
      
      # Default to the index of the current IMAGE_NAME if found, otherwise 'c' or 1
      default_choice="c"
      for ((i=0; i<${#image_array[@]}; i++)); do
          if [[ "${image_array[$i]}" == "$IMAGE_NAME" ]]; then
              default_choice="$((i+1))"
              break
          fi
      done
      if [[ "$default_choice" == "c" ]] && [[ ${#image_array[@]} -gt 0 ]]; then
          default_choice="1" # Default to first item if current IMAGE_NAME not found
      fi

      read -r -p "Select an option [1-${#image_array[@]}/c] (default: $default_choice): " img_choice
      img_choice=${img_choice:-$default_choice} # Use default if empty
      
      if [[ "$img_choice" == "c" ]]; then
        read -r -p "Enter the container image name: " custom_image_name
        # Basic validation for custom name
        if [[ -z "$custom_image_name" ]]; then
            echo "Error: Custom image name cannot be empty."
            exit 1
        fi
        IMAGE_NAME="$custom_image_name"
        read -r -p "Add '$IMAGE_NAME' to your saved images list? (y/n) [n]: " save_img
        if [[ "${save_img:-n}" == "y" ]]; then
          # Add to image array if not already there
          if ! [[ " ${image_array[*]} " =~ " ${IMAGE_NAME} " ]]; then
            image_array+=("$IMAGE_NAME")
            echo "  Added custom image to list: $IMAGE_NAME"
          fi
        fi
      elif [[ "$img_choice" =~ ^[0-9]+$ ]] && [ "$img_choice" -ge 1 ] && [ "$img_choice" -le ${#image_array[@]} ]; then
        IMAGE_NAME="${image_array[$((img_choice-1))]}"
        echo "  Selected image: $IMAGE_NAME"
      else
        echo "Invalid selection '$img_choice'. Exiting."
        exit 1
        # Fallback removed, force valid selection or exit
        # echo "Invalid selection. Using default or prompting for manual entry."
        # read -r -p "Enter the container image name (e.g., kairin/001:latest-YYYYMMDD-HHMMSS-N): " IMAGE_NAME
      fi
    else
      # No images in list, prompt directly
      read -r -p "No saved images found. Enter the container image name: " IMAGE_NAME
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
    
    # Update AVAILABLE_IMAGES - ensure unique and non-empty
    declare -A final_seen_images
    declare -a final_image_array=()
    for img in "${image_array[@]}"; do
        if [[ -n "$img" ]] && [[ ! ${final_seen_images["$img"]} ]]; then
            final_image_array+=("$img")
            final_seen_images["$img"]=1
        fi
    done
    AVAILABLE_IMAGES_SAVE_STR=$(IFS=';'; echo "${final_image_array[*]}") # Use the cleaned array

    if grep -q "^AVAILABLE_IMAGES=" "$ENV_FILE"; then
      # Replace existing line, use different sed delimiter
      sed -i "s|^AVAILABLE_IMAGES=.*|AVAILABLE_IMAGES=$AVAILABLE_IMAGES_SAVE_STR|" "$ENV_FILE"
    else
      # Add new line
      echo "" >> "$ENV_FILE" # Ensure newline
      echo "# Available container images (semicolon-separated)" >> "$ENV_FILE"
      echo "AVAILABLE_IMAGES=$AVAILABLE_IMAGES_SAVE_STR" >> "$ENV_FILE"
    fi
    
    echo "Settings saved to $ENV_FILE for future use."
  else
    echo "Warning: .env file not found, cannot save settings for future reference."
  fi

  RUN_OPTS=""
  [ "$ENABLE_GPU" = "on" ] || [ "$ENABLE_GPU" = "y" ] && RUN_OPTS="$RUN_OPTS --gpus all"
  [ "$MOUNT_WORKSPACE" = "on" ] || [ "$MOUNT_WORKSPACE" = "y" ] && RUN_OPTS="$RUN_OPTS -v /media/kkk:/workspace -v /run/jtop.sock:/run/jtop.sock"
  
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
  RUN_CMD="jetson-containers run --user kkk" # change here remove user kkk to get back root
  
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

# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Current directory
# │   └── jetcrun.sh             <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Interactive script to launch Jetson containers with selectable images and runtime options. Reads and updates .env for persistent config.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250422-064000-JRUN
# COMMIT-TRACKING: UUID-20240803-180500-JRUN
# COMMIT-TRACKING: UUID-20240804-091500-DLGF
# COMMIT-TRACKING: UUID-20240804-175200-IMGV
# COMMIT-TRACKING: UUID-20240804-182500-X11F
# COMMIT-TRACKING: UUID-20250421-020700-REFA
