#---
# name: flash-attention
# group: llm
# config: config.py
# depends: [pytorch]
# requires: '>=35'
# test: test.py
#---
ARG BASE_IMAGE=kairin/001:14-xformers
FROM ${BASE_IMAGE}

# Build Arguments
ARG FLASH_ATTENTION_VERSION=2.7.4.post2
ARG FORCE_BUILD=off
ARG MAX_JOBS=6

# Install Dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-pip python3-setuptools git cmake build-essential && \
    pip3 install --upgrade pip setuptools wheel && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy the patch file for version 2.7.4.post2
COPY patches/2.7.4.post2.diff /tmp/flash-attention/patch.diff

# Clone and Build FlashAttention
RUN set -ex && \
    echo "Building FlashAttention ${FLASH_ATTENTION_VERSION}" && \
    git clone --depth=1 --branch=v${FLASH_ATTENTION_VERSION} https://github.com/Dao-AILab/flash-attention /opt/flash-attention || \
    git clone --depth=1 https://github.com/Dao-AILab/flash-attention /opt/flash-attention && \
    cd /opt/flash-attention && \
    echo "Applying patch for version ${FLASH_ATTENTION_VERSION}" && \
    git apply /tmp/flash-attention/patch.diff && \
    git status && \
    export CMAKE_BUILD_PARALLEL_LEVEL=${MAX_JOBS} && \
    python3 setup.py --verbose bdist_wheel --dist-dir /opt && \
    pip3 install /opt/flash_attn*.whl

# Test Installation
RUN python3 -c "import flash_attn; print('FlashAttention installed successfully.')"
