# COMMIT-TRACKING: UUID-20240730-170000-DYN1
# Description: Revert to dynamic BASE_IMAGE ARG.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 11-diffusers/        <- Current directory
# │   │       └── Dockerfile       <- THIS FILE
# └── ...                        <- Other project files
# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

#---
# name: diffusers
# group: diffusion
# config: config.py
# depends: [pytorch, huggingface_hub]
# requires: '>=34.1.0'
# test: test.py
# notes: disabled on JetPack 4
#---
# Use ARG for dynamic base image injection, with a default value
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
FROM ${BASE_IMAGE}

# Set a default version if not provided
ARG DIFFUSERS_VERSION=0.24.0
ARG FORCE_BUILD=off

ENV DIFFUSERS_FORCE_DISABLE_TRITON=1

COPY build.sh install.sh /tmp/DIFFUSERS/

# Clean up existing directory and ensure DIFFUSERS_VERSION is properly exported
RUN rm -rf /opt/diffusers && \
    export DIFFUSERS_VERSION=${DIFFUSERS_VERSION} && \
    (bash -x /tmp/DIFFUSERS/install.sh || bash -x /tmp/DIFFUSERS/build.sh) && \
    echo "check_python_pkg diffusers" >> /opt/list_app_checks.sh && \
    rm -rf /root/.cache/pip