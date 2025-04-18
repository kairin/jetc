# COMMIT-TRACKING: UUID-20240729-004815-A3B1
# Description: Clarify UUID reuse policy in instructions
# Author: Mr K
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── setup_buildx.sh    <- THIS FILE
# └── ...                        <- Other project files

#!/bin/bash

# =========================================================================
# Function: Setup Docker buildx builder
# Returns: 0 if successful, 1 if not
# =========================================================================
setup_buildx_builder() {
  # Check and initialize buildx builder with NVIDIA container runtime
  if ! docker buildx inspect jetson-builder &>/dev/null; then
    echo "Creating buildx builder: jetson-builder with NVIDIA container runtime" >&2
    docker buildx create --name jetson-builder --driver-opt env.DOCKER_DEFAULT_RUNTIME=nvidia --driver-opt env.NVIDIA_VISIBLE_DEVICES=all --use
    if [ $? -ne 0 ]; then
      echo "Failed to create buildx builder" >&2
      return 1
    fi
  else
    # Ensure we're using the right builder
    docker buildx use jetson-builder
    if [ $? -ne 0 ]; then
      echo "Failed to use existing buildx builder" >&2
      return 1
    fi
    echo "Using existing buildx builder: jetson-builder" >&2
  fi
  
  return 0
}
