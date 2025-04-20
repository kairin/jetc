# COMMIT-TRACKING: UUID-20240731-153000-protobufapt
# Description: Consolidate commit-tracking headers, enforce --platform=linux/arm64 in FROM, embed test script, and add verification checks.
# Author: GitHub Copilot
# Base image: Referenced via ARG BASE_IMAGE
# Build args: BASE_IMAGE, TARGETPLATFORM=linux/arm64
# Test: Embedded test script.
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 07-protobuf_apt/     <- Current directory
# │   │       └── Dockerfile       <- THIS FILE
# └── ...                        <- Other project files
# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

#---
# name: protobuf:apt
# group: build
# depends: [build-essential]
# test: embedded # Was test.sh
# notes: install protobuf from apt repo
#---
# Use ARG for dynamic base image injection, with a default value
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
ARG TARGETPLATFORM=linux/arm64
FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}

# confirm first that the protobuf:cpp package isn't already installed
RUN if [ -z "$(which protoc)" ]; then \
        apt-get update; \
	   apt-get install -y --no-install-recommends \
	       protobuf-compiler \
		  libprotoc-dev \
		  libprotobuf-dev; \
	   rm -rf /var/lib/apt/lists/*; \
	   apt-get clean; \
	   pip3 install --upgrade protobuf; \
    fi \
    && echo "check_cmd protoc" >> /opt/list_app_checks.sh \
    && echo "check_python_package protobuf" >> /opt/list_app_checks.sh

# Embed and run test script
RUN <<EOF > /tmp/test_protobuf.sh && chmod +x /tmp/test_protobuf.sh
#!/usr/bin/env bash
# COMMIT-TRACKING: UUID-20240731-153000-protobufapt
# Description: Test protobuf installation (embedded in Dockerfile).
# Author: GitHub Copilot

set -e

echo "getting protobuf API implementation..."
echo "PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION = \$PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION"
echo ""

echo "getting protobuf Python package info..."
pip3 show protobuf || { echo "pip3 show protobuf failed"; exit 1; }
echo ""

echo "getting protobuf compiler version..."
protoc --version || { echo "protoc --version failed"; exit 1; }
echo ""

echo "Protobuf test successful."
EOF
RUN /tmp/test_protobuf.sh && rm /tmp/test_protobuf.sh

