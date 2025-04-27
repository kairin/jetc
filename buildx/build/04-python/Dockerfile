# COMMIT-TRACKING: UUID-20240806-120000-OPTM
# Description: Consolidate commit-tracking headers and enforce --platform=linux/arm64 in FROM.
# Author: GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 04-python/           <- Current directory
# │   │       └── Dockerfile       <- THIS FILE
# └── ...                        <- Other project files
# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

#---
# name: python
# group: build
# config: config.py
# depends: [build-essential]
# test: test.sh
#---
# Use ARG for dynamic base image injection, with a default value
ARG TARGETPLATFORM=linux/arm64
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}

ARG PYTHON_VERSION_ARG

ENV PYTHON_VERSION=${PYTHON_VERSION_ARG} \
    PYTHONFAULTHANDLER=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=utf-8 \
    PYTHONHASHSEED=random \
    PIP_NO_CACHE_DIR=true \
    PIP_CACHE_PURGE=true \
    PIP_ROOT_USER_ACTION=ignore \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100 \
    PIP_WHEEL_DIR=/opt/wheels \
    PIP_VERBOSE=1 \
    TWINE_NON_INTERACTIVE=1 \
    DEBIAN_FRONTEND=noninteractive \
    PATH=/opt/venv/bin:$PATH

#PYTHONPATH=/opt/venv/lib/python${PYTHON_VERSION_ARG}/site-packages:/usr/lib/python3/dist-packages:$PYTHONPATH \

COPY install.sh /tmp/install_python.sh 
RUN /tmp/install_python.sh
