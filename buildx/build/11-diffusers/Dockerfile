# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

#---
# name: diffusers
# group: diffusion
# config: config.py
# depends: [pytorch, torchvision, transformers, onnx]
# requires: '>=34.1.0'
# test: test.py
# notes: https://github.com/huggingface/diffusers
#---
ARG BASE_IMAGE=kairin/001:10-bitsandbytes
FROM ${BASE_IMAGE}

# Set a default version if not provided
ARG DIFFUSERS_VERSION=0.24.0
ARG FORCE_BUILD=off

ENV DIFFUSERS_FORCE_DISABLE_TRITON=1

COPY build.sh install.sh /tmp/DIFFUSERS/

# Clean up existing directory and ensure DIFFUSERS_VERSION is properly exported
RUN rm -rf /opt/diffusers && \
    export DIFFUSERS_VERSION=${DIFFUSERS_VERSION} && \
    (bash -x /tmp/DIFFUSERS/install.sh || bash -x /tmp/DIFFUSERS/build.sh) && \
    echo "check_python_pkg diffusers" >> /opt/list_app_checks.sh && \
    rm -rf /root/.cache/pip