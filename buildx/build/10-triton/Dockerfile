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
# Description: Fixed missing dependencies and consolidated build process
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

ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
FROM --platform=linux/arm64 ${BASE_IMAGE}

ARG TRITON_VERSION="3.3.0" \
    TRITON_BRANCH="release/3.3.x" \
    FORCE_BUILD=off

# Install required build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    python3-dev \
    python3-pip \
    python3-wheel \
    python3-setuptools \
    twine \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy build scripts
COPY build.sh install.sh /tmp/triton/

# Pass ARGs as environment variables to scripts
RUN chmod +x /tmp/triton/build.sh /tmp/triton/install.sh && \
    export TRITON_VERSION=${TRITON_VERSION} && \
    export TRITON_BRANCH=${TRITON_BRANCH} && \
    if [ "$FORCE_BUILD" == "on" ]; then \
        echo "Forcing build of triton ${TRITON_VERSION}"; \
        /tmp/triton/build.sh; \
    else \
        (pip3 install triton==${TRITON_VERSION} && echo "Installed triton ${TRITON_VERSION} from PyPI") || \
        (echo "Building triton ${TRITON_VERSION} from source" && /tmp/triton/build.sh); \
    fi && \
    python3 -c 'import triton; print(f"Triton version: {triton.__version__}")' && \
    rm -rf /tmp/triton
