#!/bin/bash
# COMMIT-TRACKING: UUID-20240803-180500-JRUN
# COMMIT-TRACKING: UUID-20240804-091500-DLGF
# COMMIT-TRACKING: UUID-20240804-175200-IMGV
# Description: Fix image name validation to prevent empty image name being passed to container run command.
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

  # Try the external function first, fallback to embedded one
  if command -v check_install_dialog >/dev/null 2>&1; then
    DIALOG_AVAILABLE=$(check_install_dialog && echo "yes" || echo "no")
  else
    DIALOG_AVAILABLE=$(check_dialog_installed && echo "yes" || echo "no")
  fi

  if [ "$DIALOG_AVAILABLE" = "yes" ]; then
    dialog --backtitle "Jetson Container Run" \
      --title "Container Run Options" \
      --form "Enter container image and options:" 15 70 6 \
      "Image Name:" 1 1 "" 1 20 40 0 \
      2>"$temp_file"
    if [ $? -ne 0 ]; then
      rm -f "$temp_file"
      echo "Operation cancelled."
      exit 1
    fi
    IMAGE_NAME=$(cat "$temp_file" | tr -d '\n')
    # Add debug output to help troubleshoot
    echo "Image name from dialog: '$IMAGE_NAME'"
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
    read -r -p "Enter the container image name (e.g., kairin/001:latest-YYYYMMDD-HHMMSS-N): " IMAGE_NAME
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

  RUN_OPTS=""
  [ "$ENABLE_GPU" = "on" ] || [ "$ENABLE_GPU" = "y" ] && RUN_OPTS="$RUN_OPTS --gpus all"
  [ "$MOUNT_WORKSPACE" = "on" ] || [ "$MOUNT_WORKSPACE" = "y" ] && RUN_OPTS="$RUN_OPTS -v /media/kkk:/workspace"
  [ "$ENABLE_X11" = "on" ] || [ "$ENABLE_X11" = "y" ] && RUN_OPTS="$RUN_OPTS -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=$DISPLAY"
  [ "$USER_ROOT" = "on" ] || [ "$USER_ROOT" = "y" ] && RUN_OPTS="$RUN_OPTS --user root"
  RUN_OPTS="$RUN_OPTS -it --rm"

  # Make sure to capture the image name in the main script context
  echo "IMAGE_NAME=$IMAGE_NAME" > /tmp/jetcrun_vars.sh
  echo "RUN_OPTS=$RUN_OPTS" >> /tmp/jetcrun_vars.sh

  export IMAGE_NAME
  export RUN_OPTS
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

echo "Running container with image: $IMAGE_NAME"
echo "Run options: $RUN_OPTS"

# Check if the image exists locally
if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
  echo "Image $IMAGE_NAME not found locally. Pulling..."
  docker pull "$IMAGE_NAME" || {
    echo "Error: Failed to pull image $IMAGE_NAME"
    exit 1
  }
fi

# Run the container with jetson-containers
echo "Starting container with jetson-containers run..."
jetson-containers run $RUN_OPTS "$IMAGE_NAME" /bin/bash
