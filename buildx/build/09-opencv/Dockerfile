# COMMIT-TRACKING: UUID-20240801-190001-PLATFORM
# Description: Consolidate commit-tracking headers and enforce --platform=linux/arm64 in FROM. Embedded test script logic and added verification checks.
# Author: GitHub Copilot
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
# test: embedded
# notes: install or build OpenCV (with CUDA) from Jetson pip server
#---
ARG TARGETPLATFORM=linux/arm64
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}

ARG OPENCV_VERSION \
    OPENCV_PYTHON \
    OPENCV_URL \
    CUDA_ARCH_BIN \
    FORCE_BUILD=off

ENV OPENCV_VERSION=${OPENCV_VERSION} \
    OPENCV_URL=${OPENCV_URL}

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        git \
        python3-pip \
        python3-dev \
        libatlas-base-dev \
        libjpeg-dev \
        libpng-dev \
        libtiff-dev \
        libavcodec-dev \
        libavformat-dev \
        libswscale-dev \
        libv4l-dev \
        libxvidcore-dev \
        libx264-dev \
        libgtk-3-dev \
        libopenblas-dev \
        liblapack-dev \
        libeigen3-dev && \
    python3 -m pip install --no-cache-dir numpy && \
    rm -rf /var/lib/apt/lists/*

RUN if [ "$FORCE_BUILD" = "on" ]; then \
        echo "Forcing build of OpenCV ${OPENCV_VERSION}" && exit 1; \
    elif [ -n "$OPENCV_URL" ]; then \
        echo "Installing OpenCV ${OPENCV_VERSION} from deb packages" && \
        wget -q ${OPENCV_URL} -O opencv.tar.gz && \
        tar -xzf opencv.tar.gz && \
        dpkg -i --force-depends *.deb && \
        apt-get install -f -y && \
        rm -rf opencv.tar.gz *.deb; \
    else \
        echo "Installing OpenCV ${OPENCV_VERSION} from pip" && \
        python3 -m pip install --no-cache-dir opencv-contrib-python~=${OPENCV_VERSION}; \
    fi

RUN echo "check_python_pkg cv2" >> /opt/list_app_checks.sh && \
    echo "check_python_pkg onnxruntime" >> /opt/list_app_checks.sh && \
    python3 -c "import cv2; print('OpenCV version:', cv2.__version__)" && \
    rm -rf /root/.cache/pip

RUN cat <<EOF > /tmp/test_opencv.py
import cv2
print("OpenCV version:", cv2.__version__)
EOF
RUN python3 /tmp/test_opencv.py && rm /tmp/test_opencv.py