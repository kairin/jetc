# COMMIT-TRACKING: UUID-20250425-063724-CUDABUILD
# Description: Fixed COPY instruction to use subdirectories (001-cuda, etc.) instead of non-existent install.sh. Added verification checks.
# Author: Mr K / GitHub Copilot / kairin
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 01-04-cuda/          <- Current directory
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

# Change to a working directory for the build process
WORKDIR /tmp/cuda-build

# Copy each installation step directory and run its install script
# Ensure these directories and install.sh scripts exist in your build context
COPY 001-cuda/ /tmp/cuda-build/001-cuda/
RUN cd 001-cuda && chmod +x install.sh && ./install.sh

COPY 002-cuda-python/ /tmp/cuda-build/002-cuda-python/
RUN cd 002-cuda-python && chmod +x install.sh && ./install.sh

COPY 003-cudnn/ /tmp/cuda-build/003-cudnn/
RUN cd 003-cudnn && chmod +x install.sh && ./install.sh

COPY 004-cupy/ /tmp/cuda-build/004-cupy/
RUN cd 004-cupy && chmod +x install.sh && ./install.sh

COPY 005-pycuda/ /tmp/cuda-build/005-pycuda/
RUN cd 005-pycuda && chmod +x install.sh && ./install.sh

# Cleanup build directory
RUN rm -rf /tmp/cuda-build
WORKDIR /

ENV CUDA_HOME="/usr/local/cuda"
ENV NVCC_PATH="$CUDA_HOME/bin/nvcc"

# filepath: /media/kkk/Apps/jetc/buildx/build/01-cuda/Dockerfile
ENV NVCC_PATH="$CUDA_HOME/bin/nvcc"

# Define LD_LIBRARY_PATH first, inheriting from base or setting default empty
# This resolves potential linter warnings about using the variable before definition.
ENV LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-}

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
    DEBIAN_FRONTEND=noninteractive

# Prepend CUDA paths to the now-defined LD_LIBRARY_PATH
ENV LD_LIBRARY_PATH="${CUDA_HOME}/compat:${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}"

# Add verification checks for CUDA
RUN echo "# Check for CUDA" >> /tmp/cuda_checks.sh \
    && echo "check_cmd nvcc 'NVIDIA CUDA Compiler'" >> /tmp/cuda_checks.sh \
    && echo "check_cmd python3 'Python 3 Interpreter'" >> /tmp/cuda_checks.sh \
    && echo "check_python_pkg cupy 'CuPy'" >> /tmp/cuda_checks.sh \
    && echo "check_python_pkg pycuda 'PyCUDA'" >> /tmp/cuda_checks.sh \
    && echo "check_cmd nvidia-smi 'NVIDIA System Management Interface'" >> /tmp/cuda_checks.sh \
    && cat /tmp/cuda_checks.sh >> /opt/list_app_checks.sh

WORKDIR /
