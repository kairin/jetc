# COMMIT-TRACKING: UUID-20240729-004815-A3B1
# COMMIT-TRACKING: UUID-20240730-101530-B4C2
# Description: Add container run helper script with standard configuration. Make image name dynamic via argument or prompt.
# Author: Mr K
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Current directory
# │   └── jetcrun.sh             <- THIS FILE
# └── ...                        <- Other project files

# Check if an image name was provided as an argument
if [ -z "$1" ]; then
  # If no argument, prompt the user for the image name
  read -p "Enter the container image name (e.g., kairin/001:latest-YYYYMMDD-HHMMSS-N): " IMAGE_NAME
else
  # Use the provided argument as the image name
  IMAGE_NAME="$1"
fi

# Check if an image name was actually provided or entered
if [ -z "$IMAGE_NAME" ]; then
  echo "Error: No image name provided. Exiting."
  exit 1
fi

# Run the container with the specified image name
jetson-containers run --gpus all -v /media/kkk:/workspace -it --rm --user root "$IMAGE_NAME" /bin/bash

