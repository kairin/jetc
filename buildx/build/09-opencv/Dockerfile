# COMMIT-TRACKING: UUID-20240730-170000-DYN1
# Description: Revert to dynamic BASE_IMAGE ARG.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 09-opencv/           <- Current directory
# │   │       └── Dockerfile       <- THIS FILE
# └── ...                        <- Other project files
# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

#---
# name: opencv
# group: core
# config: config.py
# depends: [build-essential, python, numpy, cmake, cuda, cudnn]
# test: test.py
# notes: install or build OpenCV (with CUDA) from Jetson pip server
#---
# Use ARG for dynamic base image injection, with a default value
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
FROM --platform=linux/arm64 ${BASE_IMAGE}

ARG OPENCV_VERSION \
    OPENCV_PYTHON \
    OPENCV_URL \
    CUDA_ARCH_BIN \
    FORCE_BUILD=off

ENV OPENCV_VERSION=${OPENCV_VERSION} \
    OPENCV_URL=${OPENCV_URL}
    
COPY build.sh install.sh install_deps.sh install_deb.sh patches.diff /tmp/opencv/

# Combine RUN commands to reduce layers and clean up in the same layer
RUN cd /tmp/opencv && \
    (./install.sh || ./build.sh || (echo "BUILD FAILED (OpenCV ${OPENCV_VERSION})" && exit 1)) && \
    pip3 install --no-cache-dir onnxruntime-gpu && \
    echo "check_python_pkg onnxruntime" >> /opt/list_app_checks.sh && \
    echo "check_python_pkg cv2" >> /opt/list_app_checks.sh && \
    # Remove build artifacts to reduce image size
    rm -rf /root/.cache/pip && \
    rm -rf /tmp/opencv/*.tar.gz /tmp/opencv/build || true