# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

#---
# name: transformers
# config: config.py
# group: llm
# depends: [pytorch, torchvision, huggingface_hub, rust]
# test: [test_version.py, huggingface-benchmark.py]
# docs: docs.md
# notes: for quantization support in Transformers, use the bitsandbytes, AutoGPTQ, or AutoAWQ containers.
#---
# Use ARG for dynamic base image injection
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

# Set default values for build arguments
ARG TRANSFORMERS_PACKAGE=transformers
ARG TRANSFORMERS_VERSION=4.36.2

ENV TRANSFORMERS_PACKAGE=${TRANSFORMERS_PACKAGE} \
    TRANSFORMERS_VERSION=${TRANSFORMERS_VERSION}

# Single installation step with error handling
RUN set -ex \
    && echo "Installing ${TRANSFORMERS_PACKAGE} version ${TRANSFORMERS_VERSION}" \
    && pip3 install --no-cache-dir accelerate sentencepiece optimum \
    && pip3 install --no-cache-dir ${TRANSFORMERS_PACKAGE} \
    && if [ $(lsb_release -rs) = "20.04" ]; then \
         PYTHON_ROOT=$(pip3 show transformers | grep Location: | cut -d' ' -f2); \
         sed -i -e 's|torch.distributed.is_initialized|torch.distributed.is_available|g' \
             ${PYTHON_ROOT}/transformers/modeling_utils.py; \
       fi \
    && echo "check_python_pkg transformers" >> /opt/list_app_checks.sh \
    && pip3 show transformers \
    && python3 -c 'import transformers; print(transformers.__version__)' \
    && rm -rf /root/.cache/pip

# Copy benchmark utility
COPY huggingface-benchmark.py /usr/local/bin
RUN chmod +x /usr/local/bin/huggingface-benchmark.py \
    && echo "check_cmd huggingface-benchmark 'huggingface-benchmark.py --help'" >> /opt/list_app_checks.sh