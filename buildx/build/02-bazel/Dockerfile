# COMMIT-TRACKING: UUID-20240730-180000-LNT1
# Description: Add default value to ARG BASE_IMAGE to satisfy linter.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 02-bazel/            <- Current directory
# │   │       └── Dockerfile       <- THIS FILE
# └── ...                        <- Other project files
# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

#---
# name: bazel
# group: build
# depends: [build-essential]
# test: test.sh
#---
# Use ARG for dynamic base image injection, with a default value
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
FROM ${BASE_IMAGE}


# https://github.com/bazelbuild/bazelisk
RUN BAZELISK_RELEASE=$(wget -qO- https://api.github.com/repos/bazelbuild/bazelisk/releases/latest | grep -Po '"tag_name": "\K.*?(?=")') && \
    BAZELISK_URL="https://github.com/bazelbuild/bazelisk/releases/download/$BAZELISK_RELEASE/bazelisk-linux-arm64" && \
    echo "BAZELISK_RELEASE=$BAZELISK_RELEASE" && echo "BAZELISK_URL=$BAZELISK_URL" && \
    wget --quiet --show-progress --progress=bar:force:noscroll --no-check-certificate $BAZELISK_URL -O /usr/local/bin/bazel && \
    chmod +x /usr/local/bin/bazel

# have bazelisk download latest bazel
RUN bazel --version

# from source method
#ARG BAZEL_VERSION

#RUN mkdir bazel && \
#    cd bazel && \
#    curl -fSsL -O https://github.com/bazelbuild/bazel/releases/download/$BAZEL_VERSION/bazel-$BAZEL_VERSION-dist.zip && \
#    unzip bazel-$BAZEL_VERSION-dist.zip && \
#    bash ./compile.sh
