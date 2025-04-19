#---
# name: triton
# group: ml
# depends: [pytorch]
# config: config.py
# requires: '>=35'
# test: test.py
# notes: The OpenAI `triton` (https://github.com/triton-lang/triton) wheel that's built is saved in the container under `/opt`. Based on https://cloud.tencent.com/developer/article/2317398, https://zhuanlan.zhihu.com/p/681714973, https://zhuanlan.zhihu.com/p/673525339
#---

# COMMIT-TRACKING: UUID-20240730-150000-SED1
# Description: Hardcode FROM line based on previous stage.
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

# Hardcoded base image from the previous stage
FROM kairin/001:10-onnxruntime

ARG TRITON_VERSION \
    TRITON_BRANCH \
    FORCE_BUILD=off

COPY build.sh install.sh /tmp/triton/

RUN apt-get update && apt-get install -y --no-install-recommends some-dependency && \
    pip3 install --no-cache-dir triton && \ 
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN /tmp/triton/install.sh || /tmp/triton/build.sh
