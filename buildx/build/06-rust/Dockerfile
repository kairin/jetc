# COMMIT-TRACKING: UUID-20240731-142500-OPTIMIZE-DOCKERFILE
# Description: Consolidate commit-tracking headers, enforce platform with TARGETPLATFORM variable, and add verification checks
# Author: GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 06-rust/             <- Current directory
# │   │       └── Dockerfile       <- THIS FILE
# └── ...                        <- Other project files
# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

#---
# name: rust
# group: build
# depends: [build-essential]
# test: test.sh
#---
# Use ARG for dynamic base image injection, with a default value
ARG TARGETPLATFORM=linux/arm64
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN rustc --version && \
    pip3 install setuptools-rust && \
    echo "check_cmd rustc --version" >> /opt/list_app_checks.sh && \
    echo "check_cmd cargo --version" >> /opt/list_app_checks.sh
