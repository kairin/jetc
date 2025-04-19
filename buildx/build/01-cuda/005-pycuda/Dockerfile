# COMMIT-TRACKING: UUID-20240730-220000-PLATALL
# Description: Consolidate commit-tracking headers and enforce --platform=linux/arm64 in FROM.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 01-cuda/             <- CUDA directory
# │   │       └── 005-pycuda/      <- Current directory
# │   │           └── Dockerfile   <- THIS FILE
# └── ...                        <- Other project files
#---
# name: pycuda
# group: cuda
# config: config.py
# requires: '>=32.6'
# depends: [cuda, python, numpy] # Handled by config.py
# test: (embedded in Dockerfile)
#---
# Use ARG for dynamic base image injection, with a default value
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
FROM --platform=linux/arm64 ${BASE_IMAGE}

ARG PYCUDA_VERSION

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    python3-pip \
    python3-setuptools \
    wheel \
    && rm -rf /var/lib/apt/lists/*

# Build PyCUDA from source
RUN set -ex && \
    echo "Building PyCUDA ${PYCUDA_VERSION}" && \
    \
    git clone --branch=${PYCUDA_VERSION} --depth=1 --recursive https://github.com/inducer/pycuda /opt/pycuda && \
    cd /opt/pycuda && \
    \
    python3 setup.py --verbose build_ext --inplace bdist_wheel --dist-dir /opt && \
    \
    cd /opt && \
    rm -rf /opt/pycuda && \
    \
    pip3 install --no-cache-dir /opt/pycuda*.whl && \
    \
    # Optional: Upload wheel
    ( twine upload --verbose /opt/pycuda*.whl || echo "failed to upload wheel to ${TWINE_REPOSITORY_URL}" ) && \
    rm -f /opt/pycuda*.whl

# Test PyCUDA
COPY pycuda/test.py /tmp/pycuda/
RUN echo "Running PyCUDA test..." && \
    python3 /tmp/pycuda/test.py && \
    pip3 show pycuda && \
    rm -rf /tmp/pycuda

# All test logic is already embedded in the Dockerfile.

WORKDIR /
