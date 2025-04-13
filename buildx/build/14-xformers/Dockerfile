#---
# name: xformers
# group: llm
# depends: [pytorch]
# requires: '>=34.1.0'
# test: test.py
# notes: https://github.com/facebookresearch/xformers
#---
ARG BASE_IMAGE=kairin/001:13-transformers
FROM ${BASE_IMAGE}

# Get CUDA version for dynamic version selection
ARG CUDA_VERSION
ARG FORCE_BUILD=off

# Disable triton for compatibility
ENV XFORMERS_FORCE_DISABLE_TRITON=1

# Clean up existing directory, determine version, and install or build
RUN set -ex \
    && rm -rf /opt/xformers \
    && CUDA_MAJOR=$(echo ${CUDA_VERSION} | cut -d. -f1) \
    && CUDA_MINOR=$(echo ${CUDA_VERSION} | cut -d. -f2) \
    && CUDA_NUM=$((CUDA_MAJOR * 10 + CUDA_MINOR)) \
    && if [ $CUDA_NUM -le 112 ]; then \
        echo "Setting xformers version 0.0.26 for CUDA <= 11.2" \
        && export XFORMERS_VERSION="0.0.26"; \
    elif [ $CUDA_NUM -lt 126 ]; then \
        echo "Setting xformers version 0.0.29 for CUDA < 12.6" \
        && export XFORMERS_VERSION="0.0.29"; \
    else \
        echo "Setting xformers version 0.0.30 for CUDA >= 12.6" \
        && export XFORMERS_VERSION="0.0.30"; \
    fi \
    && echo "Installing xformers version ${XFORMERS_VERSION}" \
    \
    # Try pip installation first \
    && (pip3 install --no-cache-dir xformers==${XFORMERS_VERSION} && echo "Successfully installed via pip") \
    || ( \
        echo "Pip installation failed, building from source" \
        # This part includes build.sh logic \
        && echo "Building xformers ${XFORMERS_VERSION}" \
        && git clone --branch=v${XFORMERS_VERSION} --depth=1 --recursive https://github.com/facebookresearch/xformers /opt/xformers \
           || git clone --depth=1 --recursive https://github.com/facebookresearch/xformers /opt/xformers \
        && cd /opt/xformers \
        && XFORMERS_MORE_DETAILS=1 MAX_JOBS=$(nproc) \
           python3 setup.py --verbose bdist_wheel --dist-dir /opt/xformers/wheels \
        && pip3 install /opt/xformers/wheels/*.whl \
        && (twine upload --verbose /opt/xformers/wheels/xformers*.whl || echo "failed to upload wheel") \
    ) \
    \
    # Add verification check \
    && echo "check_python_pkg xformers" >> /opt/list_app_checks.sh \
    && pip3 show xformers \
    && python3 -c 'import xformers; print(xformers.__version__)' \
    && rm -rf /root/.cache/pip