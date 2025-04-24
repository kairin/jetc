# COMMIT-TRACKING: UUID-20240730-180000-LNT1
# Description: Add default value to ARG BASE_IMAGE to satisfy linter.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 10-onnxruntime/      <- Current directory
# │   │       └── Dockerfile       <- THIS FILE
# └── ...                        <- Other project files
#---
# name: onnxruntime
# group: core
# config: config.py
# depends: [cmake, cuda, cudnn, python, numpy, onnx]
# test: test.py
#---
# Use ARG for dynamic base image injection, with a default value
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
FROM --platform=linux/arm64 ${BASE_IMAGE}

ARG ONNXRUNTIME_VERSION \
    ONNXRUNTIME_BRANCH \
    ONNXRUNTIME_FLAGS \
    FORCE_BUILD=off

COPY install.sh build.sh /tmp/onnxruntime/

RUN /tmp/onnxruntime/install.sh || /tmp/onnxruntime/build.sh
