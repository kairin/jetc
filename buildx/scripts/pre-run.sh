#!/bin/bash

# COMMIT-TRACKING: UUID-20240730-230000-DINJ
# Description: Preparation script to check dependencies before running build
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Current directory
# │   └── pre-run.sh             <- THIS FILE
# └── ...                        <- Other project files

set -e

echo "=== Checking build prerequisites ==="

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed or not in PATH"
    echo "Please install Docker first: https://docs.docker.com/engine/install/"
    exit 1
fi

# Check Docker buildx
if ! docker buildx version &> /dev/null; then
    echo "ERROR: Docker buildx not available"
    echo "Please install Docker buildx: https://docs.docker.com/buildx/working-with-buildx/"
    exit 1
fi

# Check NVIDIA Container Runtime
if ! docker info 2>&1 | grep -q "Runtimes:.*nvidia"; then
    echo "WARNING: NVIDIA Container Runtime may not be configured in Docker"
    echo "This is required for GPU support in containers"
    echo "See: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"
fi

# Ensure scripts are executable
chmod +x buildx/build.sh
chmod +x buildx/scripts/*.sh
chmod +x buildx/jetcrun.sh

# Create .env file if it doesn't exist
if [ ! -f buildx/.env ]; then
    echo "Creating default .env file..."
    cat > buildx/.env << EOL
# Docker registry username
DOCKER_USERNAME=kairin

# Default base image
DEFAULT_BASE_IMAGE=kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu
EOL
    echo "Created default .env file. Please edit with your settings."
fi

# Check dialog package
if ! command -v dialog &> /dev/null; then
    echo "Installing dialog package for interactive menus..."
    sudo apt-get update -y && sudo apt-get install -y dialog
fi

echo "=== Prerequisites check complete ==="
echo "You can now run: ./buildx/build.sh"
