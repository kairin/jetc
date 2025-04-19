# COMMIT-TRACKING: UUID-20240730-150000-SED1
# Description: Hardcode FROM line based on previous stage.
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
# depends: [cuda, cudnn, python, numpy]
# test: test.py
# notes: install or build OpenCV (with CUDA) from Jetson pip server
#---
# Hardcoded base image from the previous stage
FROM kairin/001:08-protobuf_cpp

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