# COMMIT-TRACKING: UUID-20240803-180500-JRUN
# Description: Use dialog-based prompt and runtime option selection for container run, fallback to basic prompt if dialog not available.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Current directory
# │   └── jetcrun.sh             <- THIS FILE
# └── ...                        <- Other project files

#!/bin/bash

SCRIPT_DIR="$(dirname "$0")/scripts"
if [[ -f "$SCRIPT_DIR/check_install_dialog.sh" ]]; then
  source "$SCRIPT_DIR/check_install_dialog.sh"
fi

get_run_options() {
  local temp_file=$(mktemp)
  local IMAGE_NAME=""
  local ENABLE_X11="on"
  local ENABLE_GPU="on"
  local MOUNT_WORKSPACE="on"
  local USER_ROOT="on"

  if check_install_dialog; then
    dialog --backtitle "Jetson Container Run" \
      --title "Container Run Options" \
      --form "Enter container image and options:" 15 70 6 \
      "Image Name:" 1 1 "" 1 20 40 0 \
      2>"$temp_file"
    if [[ $? -ne 0 ]]; then
      rm -f "$temp_file"
      echo "Operation cancelled."
      exit 1
    fi
    IMAGE_NAME=$(sed -n 1p "$temp_file")
    dialog --backtitle "Jetson Container Run" \
      --title "Runtime Options" \
      --checklist "Select runtime options:" 12 60 4 \
      "X11" "Enable X11 forwarding" $ENABLE_X11 \
      "GPU" "Enable all GPUs" $ENABLE_GPU \
      "WORKSPACE" "Mount /media/kkk:/workspace" $MOUNT_WORKSPACE \
      "ROOT" "Run as root user" $USER_ROOT \
      2>"$temp_file"
    local checklist=$(cat "$temp_file")
    rm -f "$temp_file"
    [[ "$checklist" == *"X11"* ]] && ENABLE_X11="on" || ENABLE_X11="off"
    [[ "$checklist" == *"GPU"* ]] && ENABLE_GPU="on" || ENABLE_GPU="off"
    [[ "$checklist" == *"WORKSPACE"* ]] && MOUNT_WORKSPACE="on" || MOUNT_WORKSPACE="off"
    [[ "$checklist" == *"ROOT"* ]] && USER_ROOT="on" || USER_ROOT="off"
  else
    read -p "Enter the container image name (e.g., kairin/001:latest-YYYYMMDD-HHMMSS-N): " IMAGE_NAME
    read -p "Enable X11 forwarding? (y/n) [y]: " x11
    ENABLE_X11=${x11:-y}
    read -p "Enable all GPUs? (y/n) [y]: " gpu
    ENABLE_GPU=${gpu:-y}
    read -p "Mount /media/kkk:/workspace? (y/n) [y]: " ws
    MOUNT_WORKSPACE=${ws:-y}
    read -p "Run as root user? (y/n) [y]: " root
    USER_ROOT=${root:-y}
  fi

  if [[ -z "$IMAGE_NAME" ]]; then
    echo "Error: No image name provided. Exiting."
    exit 1
  fi

  RUN_OPTS=""
  [[ "$ENABLE_GPU" == "on" || "$ENABLE_GPU" == "y" ]] && RUN_OPTS+=" --gpus all"
  [[ "$MOUNT_WORKSPACE" == "on" || "$MOUNT_WORKSPACE" == "y" ]] && RUN_OPTS+=" -v /media/kkk:/workspace"
  [[ "$ENABLE_X11" == "on" || "$ENABLE_X11" == "y" ]] && RUN_OPTS+=" -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=$DISPLAY"
  [[ "$USER_ROOT" == "on" || "$USER_ROOT" == "y" ]] && RUN_OPTS+=" --user root"
  RUN_OPTS+=" -it --rm"

  export IMAGE_NAME
  export RUN_OPTS
}

get_run_options

jetson-containers run $RUN_OPTS "$IMAGE_NAME" /bin/bash
