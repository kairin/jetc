# COMMIT-TRACKING: UUID-20240801-155000-NINJA
# Description: Consolidate commit-tracking headers and enforce --platform=linux/arm64 in FROM. Embed test.sh and add verification check.
# Author: GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 03-ninja/            <- Current directory
# │   │       └── Dockerfile       <- THIS FILE
# └── ...                        <- Other project files
# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

#---
# name: ninja
# group: build
# depends: [python]
# test: [test.sh]
#---
# Use ARG for dynamic base image injection, with a default value
ARG TARGETPLATFORM=linux/arm64
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    unzip wget curl jq

RUN LATEST_VERSION=$(curl -s https://api.github.com/repos/ninja-build/ninja/releases/latest | jq -r .tag_name) && \
    wget -q "https://github.com/ninja-build/ninja/releases/download/${LATEST_VERSION}/ninja-linux-aarch64.zip" && \
    unzip -o ninja-linux-aarch64.zip -d /usr/bin/ && \
    rm ninja-linux-aarch64.zip && \
    chmod +x /usr/bin/ninja && \
    apt-get -y remove jq && \
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/* && \
    echo "check_cmd ninja --version" >> /opt/list_app_checks.sh

# Test Ninja installation by embedding test.sh logic
RUN <<EOF > /tmp/test_ninja.sh
#!/bin/bash
# Check if ninja command is available
if ! command -v ninja &> /dev/null
then
    echo "Ninja is not installed or not in the PATH."
    exit 1
fi

# Create a simple build.ninja file to test Ninja
echo -e "rule echo\n  command = echo Hello, Ninja!\nbuild test: echo" > build.ninja

# Run Ninja to test the build
if ninja
then
    echo "Ninja is installed and working correctly."
    # Clean up
    rm -f build.ninja
    exit 0
else
    echo "Ninja failed to run correctly."
    # Clean up
    rm -f build.ninja
    exit 1
fi
EOF
RUN bash /tmp/test_ninja.sh && rm /tmp/test_ninja.sh
