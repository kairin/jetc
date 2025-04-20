# COMMIT-TRACKING: UUID-20240803-193000-BUILDER
# Description: Dockerfile to build OpenCV C++ libs (.deb) and Python wheel (.whl) from source.
# Author: GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 09-opencv/           <- Current directory
# │   │       └── Dockerfile.builder <- THIS FILE
# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

ARG TARGETPLATFORM=linux/arm64
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu" # Default kept for reference
FROM --platform=$TARGETPLATFORM ${BASE_IMAGE} AS builder

ARG OPENCV_VERSION \
    OPENCV_PYTHON \
    CUDA_ARCH_BIN \
    TWINE_REPOSITORY_URL

ENV OPENCV_VERSION=${OPENCV_VERSION} \
    OPENCV_PYTHON=${OPENCV_PYTHON} \
    CUDA_ARCH_BIN=${CUDA_ARCH_BIN} \
    TWINE_REPOSITORY_URL=${TWINE_REPOSITORY_URL} \
    DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
		build-essential \
		cmake \
		git \
		pkg-config \
		wget \
		ca-certificates \
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
		python3-dev \
		python3-setuptools \
		python3-wheel \
		python3-twine && \
	python3 -m pip install --no-cache-dir --upgrade pip && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt

# Clone repositories (shallow clone)
RUN git clone --depth 1 --branch ${OPENCV_VERSION} --recursive https://github.com/opencv/opencv && \
    git clone --depth 1 --branch ${OPENCV_VERSION} --recursive https://github.com/opencv/opencv_contrib && \
    git clone --depth 1 --branch ${OPENCV_PYTHON} --recursive https://github.com/opencv/opencv-python

# Checkout specific versions (redundant with branch clone, but safe)
RUN cd /opt/opencv-python/opencv && git checkout --recurse-submodules ${OPENCV_VERSION} && \
    cd /opt/opencv-python/opencv_contrib && git checkout --recurse-submodules ${OPENCV_VERSION} && \
    cd /opt/opencv-python/opencv_extra && git checkout --recurse-submodules ${OPENCV_VERSION}

# Apply patches
COPY patches.diff /tmp/opencv/patches.diff
RUN cd /opt/opencv-python && git apply /tmp/opencv/patches.diff || echo "failed to apply git patches"

# Symlink cuDNN version header
RUN ln -sf /usr/include/$(uname -i)-linux-gnu/cudnn_version*.h /usr/include/$(uname -i)-linux-gnu/cudnn_version.h

# Apply FP16 patches
RUN sed -i 's|weight != 1.0|(float)weight != 1.0f|' /opt/opencv/modules/dnn/src/cuda4dnn/primitives/normalize_bbox.hpp && \
    sed -i 's|nms_iou_threshold > 0|(float)nms_iou_threshold > 0.0f|' /opt/opencv/modules/dnn/src/cuda4dnn/primitives/region.hpp && \
    sed -i 's|weight != 1.0|(float)weight != 1.0f|' /opt/opencv-python/opencv/modules/dnn/src/cuda4dnn/primitives/normalize_bbox.hpp && \
    sed -i 's|nms_iou_threshold > 0|(float)nms_iou_threshold > 0.0f|' /opt/opencv-python/opencv/modules/dnn/src/cuda4dnn/primitives/region.hpp

# Set common CMake args
ENV CMAKE_BUILD_PARALLEL_LEVEL=$(nproc)
ENV OPENCV_BUILD_ARGS="\
   -DCPACK_BINARY_DEB=ON \
   -DBUILD_EXAMPLES=OFF \
   -DBUILD_opencv_python2=OFF \
   -DBUILD_opencv_python3=ON \
   -DBUILD_opencv_java=OFF \
   -DCMAKE_BUILD_TYPE=RELEASE \
   -DCMAKE_INSTALL_PREFIX=/usr/local \
   -DCUDA_ARCH_BIN=${CUDA_ARCH_BIN} \
   -DCUDA_ARCH_PTX= \
   -DCUDA_FAST_MATH=ON \
   -DCUDNN_INCLUDE_DIR=/usr/include/$(uname -i)-linux-gnu \
   -DEIGEN_INCLUDE_PATH=/usr/include/eigen3 \
   -DWITH_EIGEN=ON \
   -DENABLE_NEON=ON \
   -DOPENCV_DNN_CUDA=ON \
   -DOPENCV_ENABLE_NONFREE=ON \
   -DOPENCV_GENERATE_PKGCONFIG=ON \
   -DOpenGL_GL_PREFERENCE=GLVND \
   -DWITH_CUBLAS=ON \
   -DWITH_CUDA=ON \
   -DWITH_CUDNN=ON \
   -DWITH_GSTREAMER=ON \
   -DWITH_LIBV4L=ON \
   -DWITH_GTK=ON \
   -DWITH_OPENGL=OFF \
   -DWITH_OPENCL=OFF \
   -DWITH_IPP=OFF \
   -DWITH_TBB=ON \
   -DBUILD_TIFF=ON \
   -DBUILD_PERF_TESTS=OFF \
   -DBUILD_TESTS=OFF"

# Build Python Wheel
WORKDIR /opt/opencv-python
ENV ENABLE_CONTRIB=1
ENV CMAKE_ARGS="${OPENCV_BUILD_ARGS} -DOPENCV_EXTRA_MODULES_PATH=/opt/opencv-python/opencv_contrib/modules"
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 setup.py bdist_wheel --verbose && \
    rm -rf /root/.cache/pip

# Build C++ Libraries (.deb)
WORKDIR /opt/opencv/build
RUN cmake \
    ${OPENCV_BUILD_ARGS} \
    -DOPENCV_EXTRA_MODULES_PATH=/opt/opencv_contrib/modules \
    ../ && \
    make -j$(nproc) && \
    make install && \
    make package

# Create artifacts directory and copy outputs
RUN mkdir -p /artifacts && \
    cp /opt/opencv-python/dist/*.whl /artifacts/ && \
    cp /opt/opencv/build/*.deb /artifacts/ && \
    # Optionally upload wheel
    if [[ -n "$TWINE_REPOSITORY_URL" ]]; then \
        twine upload --verbose /artifacts/opencv_contrib_python*.whl || echo "failed to upload wheel to ${TWINE_REPOSITORY_URL}"; \
    else \
        echo "TWINE_REPOSITORY_URL not set, skipping twine upload"; \
    fi && \
    # Optionally upload debs (using a placeholder for tarpack)
    # tarpack upload OpenCV-${OPENCV_VERSION} /artifacts/ || echo "failed to upload tarball"
    echo "Artifacts generated in /artifacts:" && ls -l /artifacts

# Final stage to collect artifacts
FROM scratch AS artifacts_stage
COPY --from=builder /artifacts /
