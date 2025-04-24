# --- Footer ---
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Buildx directory
# │   ├── build/                 <- Build stages directory
# │   │   └── 01-04-cuda/        <- Parent directory
# │   │       └── 003-cudnn/     <- Current directory
# │   │           └── Dockerfile <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Dockerfile for installing cuDNN.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250425-080000-42595D

# Use ARG for dynamic base image injection, with a default value
ARG TARGETPLATFORM=linux/arm64
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}

ARG CUDNN_URL \
    CUDNN_DEB \
    CUDNN_PACKAGES

# Install cuDNN from debian package
RUN set -ex && \
    echo "Installing cuDNN ${CUDNN_DEB}..." && \
    \
    apt-get update && \
    apt-get install -y --no-install-recommends wget ca-certificates && \
    \
    mkdir -p /tmp/cudnn && cd /tmp/cudnn && \
    wget --quiet --show-progress --progress=bar:force:noscroll ${CUDNN_URL} && \
    dpkg -i *.deb && \
    cp /var/${CUDNN_DEB}/cudnn-*-keyring.gpg /usr/share/keyrings/ && \
    apt-get update && \
    apt-get install -y --no-install-recommends ${CUDNN_PACKAGES} && \
    \
    dpkg --list | grep cudnn && \
    dpkg -P ${CUDNN_DEB} && \
    rm -rf /tmp/cudnn && \
    rm -rf /var/lib/apt/lists/* && apt-get clean

# Test cuDNN samples
RUN set -ex && \
    echo "Testing cuDNN samples..." && \
    \
    # Check if samples were installed
    if [ -d /usr/src/cudnn_samples* ]; then \
        CUDNN_SAMPLES_DIR=$(ls -d /usr/src/cudnn_samples* | head -n 1) && \
        echo "Found cuDNN samples under ${CUDNN_SAMPLES_DIR}" && \
        cd ${CUDNN_SAMPLES_DIR}/mnistCUDNN && \
        apt-get update && apt-get install -y --no-install-recommends libfreeimage3 libfreeimage-dev && \
        make clean && make -j$(nproc) && \
        \
        # Download test data if needed by the sample
        echo "Downloading MNIST dataset..." && \
        ./download_mnist.sh && \
        \
        echo "Running mnistCUDNN sample..." && \
        ./mnistCUDNN && \
        \
        echo "mnistCUDNN sample OK" && \
        rm -rf /var/lib/apt/lists/* && apt-get clean; \
    else \
        echo "cuDNN samples directory not found, skipping sample test." ; \
    fi

# All test logic is already embedded in the Dockerfile.

# Add verification checks
RUN echo "# Check for cuDNN" >> /opt/list_app_checks.sh && \
    echo "check_file /usr/include/cudnn.h 'cuDNN header'" >> /opt/list_app_checks.sh && \
    echo "check_file /usr/lib/$(uname -m)-linux-gnu/libcudnn.so 'cuDNN library'" >> /opt/list_app_checks.sh

WORKDIR /