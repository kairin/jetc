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
# │   │       └── 004-cupy/        <- Current directory
# │   │           └── Dockerfile   <- THIS FILE
# └── ...                        <- Other project files
#---
# name: cupy (unified)
# group: cuda
# config: config.py
# requires: '>=32.6'
# depends: [cuda, python, numpy] # Handled by config.py
# test: (embedded in Dockerfile)
#---
# Use ARG for dynamic base image injection, with a default value
ARG TARGETPLATFORM=linux/arm64
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}

ARG CUPY_VERSION
ARG CUPY_NVCC_GENERATE_CODE
ARG INSTALL_MODE="install" # Mode can be 'install' or 'build'

# Install dependencies needed for building or running tests
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    python3-pip \
    python3-setuptools \
    wheel \
    && rm -rf /var/lib/apt/lists/*

# --- Installation/Build Logic ---
RUN set -ex && \
    \
    # Mode: install (try pre-built wheel first)
    if [ "${INSTALL_MODE}" = "install" ]; then \
        echo "Attempting to install pre-built CuPy ${CUPY_VERSION}..." && \
        # Note: CuPy version might need adjustment based on CUDA version.
        # The config.py determines the target CUPY_VERSION, pip handles compatibility.
        pip3 install --no-cache-dir cupy-cuda${CUDA_VERSION_MAJOR}${CUDA_VERSION_MINOR}==${CUPY_VERSION#v} || \
        (echo "Pre-built wheel not found or failed to install for ${CUPY_VERSION}. Build required." && exit 1); \
    fi; \
    \
    # Mode: build (or if install failed and INSTALL_MODE was install)
    if [ "${INSTALL_MODE}" = "build" ] || { [ "${INSTALL_MODE}" = "install" ] && [ $? -ne 0 ]; }; then \
        echo "Building CuPy ${CUPY_VERSION} from source..." && \
        WHL=/opt/wheels && \
        mkdir -p $WHL && \
        \
        git clone --branch ${CUPY_VERSION} --depth 1 --recursive https://github.com/cupy/cupy cupy_src && \
        cd cupy_src && \
        \
        # Set build environment variables
        export CUPY_NVCC_GENERATE_CODE=${CUPY_NVCC_GENERATE_CODE} && \
        export CFLAGS="$CFLAGS -I/usr/local/cuda/include" && \
        export LDFLAGS="$LDFLAGS -L/usr/local/cuda/lib64" && \
        \
        pip3 install --no-cache-dir fastrlock && \
        python3 setup.py bdist_wheel --verbose --dist-dir $WHL && \
        \
        cd .. && rm -rf cupy_src && \
        \
        pip3 install --no-cache-dir $WHL/cupy*.whl && \
        # Optional: Upload wheel
        ( twine upload --verbose $WHL/cupy*.whl || echo "failed to upload wheel to ${TWINE_REPOSITORY_URL}" ) && \
        rm -rf $WHL; \
    fi

# --- Test Execution ---
COPY test.py /tmp/cupy/
RUN echo "Running CuPy test..." && \
    python3 /tmp/cupy/test.py && \
    pip3 show cupy && \
    rm -rf /tmp/cupy

WORKDIR /
