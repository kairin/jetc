# COMMIT-TRACKING: UUID-20240730-220000-PLATALL
# Description: Consolidate commit-tracking headers and enforce --platform=linux/arm64 in FROM.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 01-cuda/             <- Current directory
# │   │       └── Dockerfile       <- THIS FILE
# └── ...                        <- Other project files
#---
# name: cuda-base
# group: cuda
# notes: installs core CUDA components and sets up environment
# depends: [build-essential]
#---
# Use ARG for dynamic base image injection, with a default value
ARG TARGETPLATFORM=linux/arm64
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}

ARG CUDA_URL \
    CUDA_DEB \
    CUDA_PACKAGES \
    CUDA_ARCH_LIST \
    DISTRO

COPY cuda/install.sh /tmp/cuda/install.sh
RUN /tmp/cuda/install.sh

ENV CUDA_HOME="/usr/local/cuda"
ENV NVCC_PATH="$CUDA_HOME/bin/nvcc"

ENV NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=all \
    CUDAARCHS=${CUDA_ARCH_LIST} \
    CUDA_ARCHITECTURES=${CUDA_ARCH_LIST} \
    CUDA_HOME="/usr/local/cuda" \
    CUDNN_LIB_PATH="/usr/lib/aarch64-linux-gnu" \
    CUDNN_LIB_INCLUDE_PATH="/usr/include" \
    CMAKE_CUDA_COMPILER=${NVCC_PATH} \
    CUDA_NVCC_EXECUTABLE=${NVCC_PATH} \
    CUDACXX=${NVCC_PATH} \
    TORCH_NVCC_FLAGS="-Xfatbin -compress-all" \
    CUDA_BIN_PATH="${CUDA_HOME}/bin" \
    CUDA_TOOLKIT_ROOT_DIR="${CUDA_HOME}" \
    PATH="$CUDA_HOME/bin:${PATH}" \
    LD_LIBRARY_PATH="${CUDA_HOME}/compat:${CUDA_HOME}/lib64:${LD_LIBRARY_PATH:-}" \
    DEBIAN_FRONTEND=noninteractive

# Add verification checks for CUDA
RUN echo "# Check for CUDA" >> /tmp/cuda_checks.sh \
    && echo "check_cmd nvcc 'NVIDIA CUDA Compiler'" >> /tmp/cuda_checks.sh \
    && echo "check_cmd nvidia-smi 'NVIDIA System Management Interface'" >> /tmp/cuda_checks.sh \
    && cat /tmp/cuda_checks.sh >> /opt/list_app_checks.sh

WORKDIR /
