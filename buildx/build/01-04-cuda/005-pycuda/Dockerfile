# Use ARG for dynamic base image injection
ARG TARGETPLATFORM=linux/arm64
ARG BASE_IMAGE
FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}

ARG PYCUDA_VERSION

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    python3-pip \
    python3-setuptools \
    python3-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Build PyCUDA from source
RUN set -ex && \
    echo "Building PyCUDA ${PYCUDA_VERSION}..." && \
    SRC=/opt/pycuda && \
    WHL=/opt/wheels && \
    mkdir -p $WHL && \
    \
    git clone --branch ${PYCUDA_VERSION} --depth 1 https://github.com/inducer/pycuda $SRC && \
    cd $SRC && \
    \
    # Configure PyCUDA (adjust paths if CUDA is not in /usr/local/cuda)
    python3 configure.py --cuda-root=/usr/local/cuda && \
    \
    # Build the wheel
    python3 setup.py bdist_wheel --dist-dir $WHL && \
    \
    # Install the wheel
    pip3 install --no-cache-dir $WHL/pycuda*.whl && \
    \
    # Cleanup
    cd / && rm -rf $SRC $WHL

# Copy and run test script
COPY test.py /tmp/pycuda/
RUN echo "Running PyCUDA test..." && \
    python3 /tmp/pycuda/test.py && \
    pip3 show pycuda && \
    rm -rf /tmp/pycuda

WORKDIR /

# --- Footer ---
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Buildx directory
# │   ├── build/                 <- Build stages directory
# │   │   └── 01-04-cuda/        <- Parent directory
# │   │       └── 005-pycuda/    <- Current directory
# │   │           └── Dockerfile <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Dockerfile for building PyCUDA.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250425-080000-42595D # Assuming same UUID for this set of changes
