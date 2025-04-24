# COMMIT-TRACKING: UUID-20240731-100500-bazel-fix
# Description: Install build-essential instead of g++ to potentially resolve dependency issues.
# Author: GitHub Copilot
# Base image: jetc-base:latest
# Build args: BASE_IMAGE=jetc-base:latest
# Test: Embedded test script.

# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 02-bazel/            <- Current directory
# │   │       └── Dockerfile       <- THIS FILE
# └── ...                        <- Other project files
# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

#---
# name: bazel
# group: build
# depends: [build-essential]
# test: test.sh
#---
# Use ARG for dynamic base image injection, with a default value
ARG BASE_IMAGE=jetc-base:latest
ARG TARGETPLATFORM=linux/arm64

FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}

ARG BAZEL_VERSION="7.2.1"
ARG BAZEL_SHA256="511a7f6a4a8a3f3d7792a426c0b7581a141a5137444e11311851d7841141d055"

# Install Bazel
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        unzip \
        zip \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fSL https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-installer-linux-$(dpkg --print-architecture).sh -o bazel-installer.sh \
    && echo "${BAZEL_SHA256}  bazel-installer.sh" | sha256sum -c - \
    && bash bazel-installer.sh \
    && rm bazel-installer.sh \
    && echo "check_cmd bazel --version" >> /opt/list_app_checks.sh

# Test Bazel installation by embedding test.sh logic
RUN <<'EOF' > /tmp/test_bazel.sh
#!/usr/bin/env bash
set -e
echo "testing bazel..."
bazel --version
echo "bazel OK"
EOF
RUN bash /tmp/test_bazel.sh && rm /tmp/test_bazel.sh

WORKDIR /
