#!/bin/bash

# =========================================================================
# IMPORTANT: This build system requires Docker with buildx extension.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================
set -e

echo "Building diffusers ${DIFFUSERS_VERSION:-latest}"

# Clean existing directory
rm -rf /opt/diffusers

# Clone with version tag if specified
if [ -n "$DIFFUSERS_VERSION" ] && [ "$DIFFUSERS_VERSION" != "latest" ]; then
    git clone --branch="v${DIFFUSERS_VERSION}" --depth=1 --recursive https://github.com/huggingface/diffusers /opt/diffusers || \
    git clone --recursive https://github.com/huggingface/diffusers /opt/diffusers
else
    git clone --recursive https://github.com/huggingface/diffusers /opt/diffusers
fi

# Install from source
cd /opt/diffusers
pip3 install -e .