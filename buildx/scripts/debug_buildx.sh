#!/bin/bash

echo "===== Docker Buildx Environment Debug Info ====="
echo "Docker Version:"
docker --version

echo -e "\nBuildx Version:"
docker buildx version

echo -e "\nAvailable Builders:"
docker buildx ls

echo -e "\nNVIDIA Runtime Check:"
if command -v nvidia-container-runtime >/dev/null 2>&1; then
    echo "✅ nvidia-container-runtime is available"
    echo "Location: $(which nvidia-container-runtime)"
    echo "Version: $(nvidia-container-runtime --version 2>&1 || echo 'Version check failed')"
else
    echo "❌ nvidia-container-runtime is NOT available in PATH"
fi

echo -e "\nNVIDIA Docker Check:"
if command -v nvidia-docker >/dev/null 2>&1; then
    echo "✅ nvidia-docker is available"
else
    echo "❌ nvidia-docker is NOT available in PATH"
fi

echo -e "\nNVIDIA Container CLI Check:"
if command -v nvidia-container-cli >/dev/null 2>&1; then
    echo "✅ nvidia-container-cli is available"
else
    echo "❌ nvidia-container-cli is NOT available in PATH"
fi

echo -e "\nNVIDIA SMI Check:"
if command -v nvidia-smi >/dev/null 2>&1; then
    echo "✅ nvidia-smi is available"
    echo "GPU Info:"
    nvidia-smi --query-gpu=gpu_name,driver_version,memory.total --format=csv
else
    echo "❌ nvidia-smi is NOT available or no GPU detected"
fi

echo -e "\nDocker Info:"
docker info | grep -i runtime

echo -e "\nDocker Daemon Configuration:"
if [ -f /etc/docker/daemon.json ]; then
    echo "Content of /etc/docker/daemon.json:"
    cat /etc/docker/daemon.json
else
    echo "No /etc/docker/daemon.json file found"
fi

echo "===== Debug Info Complete ====="
