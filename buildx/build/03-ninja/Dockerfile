# COMMIT-TRACKING: UUID-20240730-170000-DYN1
# Description: Revert to dynamic BASE_IMAGE ARG.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 03-ninja/            <- Current directory
# │   │       └── Dockerfile       <- THIS FILE
# └── ...                        <- Other project files
# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

#---
# name: ninja
# group: build
# depends: [python]
# test: [test.sh]
#---
# Use ARG for dynamic base image injection
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    unzip wget curl jq

RUN LATEST_VERSION=$(curl -s https://api.github.com/repos/ninja-build/ninja/releases/latest | jq -r .tag_name) && \
    wget -q "https://github.com/ninja-build/ninja/releases/download/${LATEST_VERSION}/ninja-linux-aarch64.zip" && \
    unzip -o ninja-linux-aarch64.zip -d /usr/bin/ && \
    rm ninja-linux-aarch64.zip && \
    chmod +x /usr/bin/ninja && \
    apt-get -y remove jq && \
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*
