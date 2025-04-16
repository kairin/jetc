#!/bin/bash

# ...existing code...

# Check if user is logged into Docker
if ! docker info 2>/dev/null | grep -q "Username"; then
    printf "Warning: You may not be logged into Docker. Images may fail to push if credentials are required.\n"
    printf "Continue anyway? (y/n): "
    # Force flush stdout before reading input
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Build cancelled."
        exit 1
    fi
    echo "Continuing with build..."
fi

# ...existing code...

# When this part appears in the script, modify it to handle builder creation properly
echo "Setting up Docker buildx builder..."
echo "Removing existing buildx builder: jetson-builder"
docker buildx rm jetson-builder 2>/dev/null || true
echo "jetson-builder removed"

read -p "Do you want to enable GPU for building? (y/n, default: n): " enable_gpu
enable_gpu=${enable_gpu:-n}

echo "Creating new buildx builder: jetson-builder"
if [[ "$enable_gpu" =~ ^[Yy]$ ]]; then
    echo "Creating builder with GPU support..."
    # Use the existing GPU-enabled builder creation command
    docker buildx create --name jetson-builder --driver docker-container --driver-opt image=moby/buildkit:latest --use || {
        echo "Failed to create buildx builder with GPU support. Falling back to regular builder."
        enable_gpu="n"
    }
else
    echo "Creating builder without GPU support..."
    # Explicitly disable NVIDIA runtime for non-GPU builds
    docker buildx create --name jetson-builder \
        --driver docker-container \
        --driver-opt image=moby/buildkit:buildx-stable-1 \
        --driver-opt env.DOCKER_DEFAULT_RUNTIME=runc \
        --driver-opt env.BUILDKIT_STEP_LOG_MAX_SIZE=-1 \
        --bootstrap --use || {
        echo "Error creating new builder. Checking if default can be used..."
        if docker buildx ls | grep -q "default"; then
            echo "Using existing default builder."
            docker buildx use default
        else
            echo "Error: Failed to set up any buildx builder."
            exit 1
        fi
    }
fi

echo "Verifying builder status..."
docker buildx inspect

echo "Buildx builder ready."
# ...existing code...