#---
# name: opencv
# group: core
# config: config.py
# depends: [cuda, cudnn, python, numpy]
# test: test.py
# notes: install or build OpenCV (with CUDA) from Jetson pip server
#---
ARG BASE_IMAGE=kairin/001:08-protobuf_cpp
FROM ${BASE_IMAGE}

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