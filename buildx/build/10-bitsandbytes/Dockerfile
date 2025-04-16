# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

#---
# name: bitsandbytes
# group: llm
# config: config.py
# requires: '>=35'
# depends: [transformers, triton]
# test: test.py
# notes: fork of https://github.com/TimDettmers/bitsandbytes for Jetson
# name: bitsandbytes
# group: ml
# depends: [cuda, python]
#---
ARG BASE_IMAGE=kairin/001:09-opencv
FROM ${BASE_IMAGE}

# Define arguments with default values
ARG CUDA_INSTALLED_VERSION=11.8
ARG CUDA_MAKE_LIB=cuda11x
ARG BITSANDBYTES_VERSION=0.45.4
ARG BITSANDBYTES_REPO=bitsandbytes-foundation/bitsandbytes
ARG BITSANDBYTES_BRANCH=main
ARG PIP_WHEEL_DIR=/tmp/wheels

# Install dependencies first to leverage Docker caching
RUN set -ex \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        python3-pip \
        python3-setuptools \
        git \
        cmake \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create wheel directory
RUN mkdir -p ${PIP_WHEEL_DIR}

# Add check to remove target directory if it exists
RUN set -ex \
    && echo "### CUDA_INSTALLED_VERSION: ${CUDA_INSTALLED_VERSION}" \
    && echo "### CUDA_MAKE_LIB: ${CUDA_MAKE_LIB}" \
    && echo "Building bitsandbytes ${BITSANDBYTES_VERSION} from source" \
    && rm -rf /opt/bitsandbytes \
    && git clone --branch=${BITSANDBYTES_BRANCH} --recursive --depth=1 "https://github.com/${BITSANDBYTES_REPO}" /opt/bitsandbytes \
    && cd /opt/bitsandbytes \
    && if [ "${CUDA_INSTALLED_VERSION}" -lt 126 ]; then \
        CUDA_VERSION=${CUDA_INSTALLED_VERSION} make -C /opt/bitsandbytes -j$(nproc) "${CUDA_MAKE_LIB}" && \
        CUDA_VERSION=${CUDA_INSTALLED_VERSION} make -C /opt/bitsandbytes -j$(nproc) "${CUDA_MAKE_LIB}_nomatmul"; \
    else \
        cmake -DCOMPUTE_BACKEND=cuda -S . && \
        CUDA_VERSION=${CUDA_INSTALLED_VERSION} make -C . -j$(nproc); \
    fi \
    && python3 setup.py --verbose build_ext --inplace -j$(nproc) bdist_wheel --dist-dir ${PIP_WHEEL_DIR} \
    && ls -l ${PIP_WHEEL_DIR} \
    && pip3 install ${PIP_WHEEL_DIR}/bitsandbytes*.whl \
    # Add verification check
    && echo "check_python_pkg bitsandbytes" >> /opt/list_app_checks.sh \
    # Clean up to reduce image size
    && rm -rf ${PIP_WHEEL_DIR}/* \
    && rm -rf /root/.cache/pip