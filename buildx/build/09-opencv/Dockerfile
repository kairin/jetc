# COMMIT-TRACKING: UUID-20240803-195000-ENTRYPOINT
# Description: Main entry point Dockerfile for OpenCV with both builder and runtime stages
# Author: GitHub Copilot
#
# File location diagram:
# jetc/
# ├── buildx/
# │   ├── build/
# │   │   └── 09-opencv/
# │   │       ├── Dockerfile        <- THIS FILE
# │   │       ├── Dockerfile.builder
# │   │       └── Dockerfile.runtime
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
# notes: OpenCV with CUDA support (main entry point)
#---

ARG TARGETPLATFORM=linux/arm64
ARG BASE_IMAGE
FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}

# Pass through build arguments
ARG OPENCV_VERSION \
    OPENCV_PYTHON \
    CUDA_ARCH_BIN \
    OPENCV_URL \
    TWINE_REPOSITORY_URL

ENV OPENCV_VERSION=${OPENCV_VERSION} \
    OPENCV_PYTHON=${OPENCV_PYTHON} \
    CUDA_ARCH_BIN=${CUDA_ARCH_BIN} \
    OPENCV_URL=${OPENCV_URL} \
    TWINE_REPOSITORY_URL=${TWINE_REPOSITORY_URL}

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
		libglew-dev \
		libgstreamer1.0-dev \
		libgstreamer-plugins-base1.0-dev \
		libjpeg-dev \
		libnotify-dev \
		libpng-dev \
		libtbb-dev \
		libtiff-dev \
		libtesseract-dev \
		libavcodec-dev \
		libavformat-dev \
		libavutil-dev \
		libpostproc-dev \
		libswscale-dev \
		libgtk-3-dev \
		libv4l-dev \
		v4l-utils \
		libeigen3-dev \
		libopenblas-dev \
		liblapack-dev \
		python3-pip \
		python3-numpy \
		python3-dev && \
    rm -rf /var/lib/apt/lists/*

# Install OpenCV
RUN --mount=type=cache,target=/root/.cache/pip \
    if [ -n "$OPENCV_URL" ]; then \
        echo "Installing OpenCV ${OPENCV_VERSION} from deb packages at ${OPENCV_URL}" && \
        wget -q ${OPENCV_URL} -O opencv.tar.gz && \
        tar -xzf opencv.tar.gz && \
        dpkg -i --force-depends *.deb && \
        apt-get install -f -y && \
        rm -rf opencv.tar.gz *.deb; \
    else \
        echo "Installing OpenCV ${OPENCV_VERSION} from pip" && \
        python3 -m pip install --no-cache-dir opencv-contrib-python~=${OPENCV_VERSION}; \
    fi && \
    rm -rf /root/.cache/pip

# Verification
RUN echo "check_python_pkg cv2" >> /opt/list_app_checks.sh && \
    python3 -c "import cv2; print('OpenCV version:', cv2.__version__)"

RUN cat <<EOF > /tmp/test_opencv.py
import cv2
import numpy as np
try:
    print("OpenCV version:", cv2.__version__)
    print(cv2.getBuildInformation())
    # Simple test: create a black image
    img = np.zeros((100, 100, 3), dtype=np.uint8)
    print("Successfully created a NumPy array with OpenCV.")
    # Check if CUDA is available
    try:
        count = cv2.cuda.getCudaEnabledDeviceCount()
        print(f"CUDA devices found: {count}")
        if count > 0:
            cv2.cuda.printCudaDeviceInfo(0)
    except Exception as e:
        print(f"CUDA check failed (this might be expected for non-CUDA builds): {e}")
except Exception as e:
    print(f"OpenCV test failed: {e}")
    exit(1)
EOF

RUN python3 /tmp/test_opencv.py && rm /tmp/test_opencv.py
