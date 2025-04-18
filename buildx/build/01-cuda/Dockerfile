#---
# name: cuda-base
# group: cuda
# notes: installs core CUDA components and sets up environment
# depends: [build-essential]
#---
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ARG CUDA_URL \
    CUDA_DEB \
    CUDA_PACKAGES \
    CUDA_ARCH_LIST \
    DISTRO="ubuntu2004"
    
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
    LD_LIBRARY_PATH="${CUDA_HOME}/compat:${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}" \
    DEBIAN_FRONTEND=noninteractive

# Add verification checks for CUDA
RUN echo "# Check for CUDA" >> /tmp/cuda_checks.sh \
    && echo "check_cmd nvcc 'NVIDIA CUDA Compiler'" >> /tmp/cuda_checks.sh \
    && echo "check_cmd nvidia-smi 'NVIDIA System Management Interface'" >> /tmp/cuda_checks.sh \
    && cat /tmp/cuda_checks.sh >> /opt/list_app_checks.sh

WORKDIR /
