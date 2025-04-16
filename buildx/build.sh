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

echo "Setting up Docker buildx builder..."
echo "Removing existing buildx builder: jetson-builder"
docker buildx rm jetson-builder 2>/dev/null || true
echo "jetson-builder removed"

# Check if NVIDIA runtime is available
has_nvidia=0
if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
    has_nvidia=1
    echo "NVIDIA GPU detected on system"
fi

read -p "Do you want to enable GPU for building? (y/n, default: ${has_nvidia:+y}${has_nvidia:-n}): " enable_gpu_input
enable_gpu=${enable_gpu_input:-${has_nvidia:+y}${has_nvidia:-n}}

echo "Creating new buildx builder: jetson-builder"
if [[ "$enable_gpu" =~ ^[Yy]$ ]]; then
    echo "Creating builder with GPU support..."
    # Use the extended builder creation with GPU support
    docker buildx create --name jetson-builder \
        --driver docker-container \
        --driver-opt image=moby/buildkit:latest \
        --driver-opt network=host \
        --driver-opt env.DOCKER_BUILDKIT=1 \
        --driver-opt env.BUILDKIT_STEP_LOG_MAX_SIZE=-1 \
        --bootstrap --use || {
        echo "Failed to create buildx builder with GPU support. Falling back to regular builder."
        enable_gpu="n"
    }
    
    # Verify GPU availability to buildkit if GPU was requested
    if [[ "$enable_gpu" =~ ^[Yy]$ ]]; then
        echo "Verifying GPU availability to buildkit..."
        if ! docker run --rm --gpus all ubuntu nvidia-smi &> /dev/null; then
            echo "Warning: NVIDIA GPU might not be accessible to Docker containers!"
            echo "Builds may proceed without GPU acceleration."
        else
            echo "GPU is accessible to Docker containers."
        fi
    fi
else
    echo "Creating builder without GPU support..."
    # Use the specific version and runtime that was working previously
    docker buildx create --name jetson-builder \
        --driver docker-container \
        --driver-opt image=moby/buildkit:buildx-stable-1 \
        --driver-opt env.DOCKER_DEFAULT_RUNTIME=runc \
        --driver-opt env.BUILDKIT_STEP_LOG_MAX_SIZE=-1 \
        --bootstrap --use || {
        echo "Error creating new builder. Trying fallback method..."
        # Fallback to simpler creation method
        docker buildx create --name jetson-builder --bootstrap --use || {
            echo "Error creating new builder. Checking if default can be used..."
            if docker buildx ls | grep -q "default"; then
                echo "Using existing default builder."
                docker buildx use default
            else
                echo "Error: Failed to set up any buildx builder."
                exit 1
            fi
        }
    }
    
    # Add diagnostic output for troubleshooting
    echo "Builder configuration:"
    docker buildx inspect --bootstrap
fi

# Extra verification and configuration
echo "Verifying builder status..."
docker buildx inspect

# Add this for compatibility with any scripts that might expect 'jetson-builder'
if ! docker buildx ls | grep -q "jetson-builder"; then
    echo "Warning: 'jetson-builder' not found in buildx builders. Some scripts may fail."
    echo "Current builders:"
    docker buildx ls
else
    echo "Buildx builder ready."
fi

# Export builder name for other scripts to use
export BUILDX_BUILDER="$(docker buildx inspect --bootstrap | grep Name | awk '{print $2}')"
echo "Using buildx builder: $BUILDX_BUILDER"

# ...existing code...