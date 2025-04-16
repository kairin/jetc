#!/bin/bash

# =========================================================================
# IMPORTANT: This build system requires Docker with buildx extension.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

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

# Check for multiple build.sh files
echo -e "\nChecking for build.sh files:"
echo "Finding all build.sh files in the repository:"
find $(git rev-parse --show-toplevel 2>/dev/null || echo ".") -name "build.sh" -type f | while read -r file; do
    echo "Found: $file"
    echo "  Last modified: $(stat -c %y "$file")"
    echo "  Size: $(stat -c %s "$file") bytes"
    echo "  First line: $(head -n 1 "$file")"
done

# Check Docker system information
echo -e "\nDocker System Info:"
docker system info | grep -E 'Architecture|Operating|CPUs|Total Memory|Kernel Version'

# Check available disk space
echo -e "\nDocker Disk Usage:"
docker system df

# Check environment variables that might affect Docker
echo -e "\nDocker-related Environment Variables:"
env | grep -i 'docker\|container\|nvidia' || echo "No Docker-related environment variables found"

# Test a simple buildx build
echo -e "\nTesting a simple buildx build:"
temp_dir=$(mktemp -d)
cat > "$temp_dir/Dockerfile" << 'EOF'
FROM alpine:latest
RUN echo "Buildx test successful" > /test.txt
CMD ["cat", "/test.txt"]
EOF

(cd "$temp_dir" && docker buildx build --progress=plain --load -t buildx-test . && docker run --rm buildx-test) || echo "Simple buildx test failed"
rm -rf "$temp_dir"

# Check for build failures in logs
echo -e "\nRecent Docker errors (if any):"
journalctl -u docker --since "1 hour ago" | grep -i 'error\|fail' | tail -n 10 || echo "No recent Docker errors found or journalctl not available"

echo "===== Debug Info Complete ====="
