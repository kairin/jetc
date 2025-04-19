#---
# name: triton
# group: ml
# depends: [pytorch]
# config: config.py
# requires: '>=35'
# test: test.py
# notes: The OpenAI `triton` (https://github.com/triton-lang/triton) wheel that's built is saved in the container under `/opt`. Based on https://cloud.tencent.com/developer/article/2317398, https://zhuanlan.zhihu.com/p/681714973, https://zhuanlan.zhihu.com/p/673525339
#---

# COMMIT-TRACKING: UUID-20240730-170000-DYN1
# Description: Revert to dynamic BASE_IMAGE ARG.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Parent directory
# │   └── build/                 <- Parent directory
# │       └── 10-triton/         <- Current directory
# │           └── Dockerfile     <- THIS FILE
# └── ...                        <- Other project files

# Use ARG for dynamic base image injection, with a default value
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
FROM --platform=linux/arm64 ${BASE_IMAGE}

ARG TRITON_VERSION \
    TRITON_BRANCH \
    FORCE_BUILD=off

COPY build.sh install.sh /tmp/triton/

RUN apt-get update && apt-get install -y --no-install-recommends some-dependency && \
    pip3 install --no-cache-dir triton && \ 
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN /tmp/triton/install.sh || /tmp/triton/build.sh
