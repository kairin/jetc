#!/bin/bash

# ...existing code...

echo "Setting up Docker buildx builder..."

# Remove existing builder
echo "Removing existing buildx builder: jetson-builder"
docker buildx rm jetson-builder 2>/dev/null || true
echo "jetson-builder removed"

# Ask about GPU support
read -p "Do you want to enable GPU for building? (y/n, default: n): " enable_gpu
enable_gpu=${enable_gpu:-n}

echo "Creating new buildx builder: jetson-builder"

if [[ "$enable_gpu" =~ ^[Yy]$ ]]; then
    echo "Creating builder with GPU support..."
    # Check if nvidia-container-runtime is available before trying to use it
    if command -v nvidia-container-runtime >/dev/null 2>&1; then
        docker buildx create --name jetson-builder --driver-opt image=moby/buildkit:buildx-stable-1 --buildkitd-flags "--allow-insecure-entitlement security.insecure" --use || {
            echo "Error creating GPU-enabled builder. Falling back to default."
            use_default=true
        }
    else
        echo "WARNING: nvidia-container-runtime not found, cannot enable GPU support."
        echo "Installing without GPU acceleration."
        use_default=true
    fi
else
    echo "Creating builder without GPU support..."
    # Create a standard builder without GPU requirements
    docker buildx create --name jetson-builder --driver-opt image=moby/buildkit:buildx-stable-1 --use || {
        echo "Error creating new builder. Checking if default can be used..."
        use_default=true
    }
fi

# If creating a custom builder failed, check if default can be used
if [ "${use_default:-false}" = true ]; then
    echo "Using existing default builder."
    docker buildx use default
fi

# Verify builder status
echo "Verifying builder status..."
docker buildx inspect --bootstrap
echo "Buildx builder ready."

# Continue with the build process
# ...existing code...