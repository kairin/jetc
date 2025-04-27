# COMMIT-TRACKING: UUID-20240730-220000-PLATALL
# Description: Consolidate commit-tracking headers and enforce --platform=linux/arm64 in FROM.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 15-flash-attention/  <- Current directory
# │   │       └── Dockerfile       <- THIS FILE
# └── ...                        <- Other project files
# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

#---
# name: flash-attention
# group: llm
# config: config.py
# depends: [pytorch, cmake]
# requires: '>=35'
# test: test.py
#---
# Use ARG for dynamic base image injection, with a default value
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
FROM --platform=linux/arm64 ${BASE_IMAGE}

# Build Arguments
ARG MAX_JOBS=6
ENV FLASH_ATTN_CUDA_ARCHS=87

# Single consolidated RUN command for speed and efficiency
RUN set -ex \
    # Install dependencies \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        python3-pip python3-setuptools git cmake build-essential \
    && pip3 install --no-cache-dir --upgrade pip setuptools wheel \
    \
    # Clone specific version \
    && rm -rf /opt/flash-attention \
    && git clone --depth=1 --branch=v2.5.8 https://github.com/Dao-AILab/flash-attention /opt/flash-attention \
    && cd /opt/flash-attention \
    \
    # Create a simpler patch for CUDA architecture on Jetson \
    && echo 'export FLASH_ATTN_CUDA_ARCHS="87"' > /opt/flash-attention/setup_jetson.sh \
    && chmod +x /opt/flash-attention/setup_jetson.sh \
    && source /opt/flash-attention/setup_jetson.sh \
    \
    # Modify setup.py to force SM87 architecture for Jetson Orin \
    && sed -i 's/cuda_archs = \[\]/cuda_archs = \["87"\]/' setup.py \
    && grep -q "csrc/fused_softmax/compile.sh" . && sed -i 's/--threads $max_jobs/-gencode arch=compute_87,code=sm_87/' csrc/fused_softmax/compile.sh || true \
    && grep -q "csrc/fused_dense_lib/compile.sh" . && sed -i 's/--threads $max_jobs/-gencode arch=compute_87,code=sm_87/' csrc/fused_dense_lib/compile.sh || true \
    \
    # Build with optimized parallelism \
    && mkdir -p /opt/wheels \
    && export CMAKE_BUILD_PARALLEL_LEVEL=${MAX_JOBS} \
    && python3 setup.py --verbose bdist_wheel --dist-dir /opt/wheels \
    && pip3 install /opt/wheels/flash_attn*.whl \
    \
    # Verify installation (matching test.py output format) \
    && python3 -c "import flash_attn; print('FlashAttention version', flash_attn.__version__)" \
    && echo "check_python_pkg flash_attn" >> /opt/list_app_checks.sh \
    \
    # Cleanup \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /root/.cache/pip \
    && rm -rf /opt/flash-attention/build