# COMMIT-TRACKING: UUID-20240730-220000-PLATALL
# Description: Consolidate commit-tracking headers and enforce --platform=linux/arm64 in FROM.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 05-h5py/             <- Current directory
# │   │       └── Dockerfile       <- THIS FILE
# └── ...                        <- Other project files
# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

#---
# name: h5py
# group: core
# depends: [python, numpy]
# test: test.py
#---
# Use ARG for dynamic base image injection, with a default value
ARG TARGETPLATFORM=linux/arm64
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}

RUN set -ex && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        libhdf5-serial-dev \
        hdf5-tools \
        libhdf5-dev && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean && \
    if python3 -c "import sys; exit(0 if sys.version_info < (3,9) else 1)"; then \
        echo "Python < 3.9 => installing h5py<3.12" && \
        H5PY_SETUP_REQUIRES=0 pip3 install "h5py<3.12"; \
    else \
        echo "Python >= 3.9 => intalling h5py>=3.12" && \
        H5PY_SETUP_REQUIRES=0 pip3 install "h5py>=3.12"; \
    fi
