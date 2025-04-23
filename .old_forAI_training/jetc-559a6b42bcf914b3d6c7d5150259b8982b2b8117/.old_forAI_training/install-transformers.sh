#!/usr/bin/env bash
set -ex

# Consolidate pip installations to reduce layers
pip3 install --no-cache-dir accelerate sentencepiece optimum

# Skip the complex version detection - use ARG value directly from Dockerfile
echo "Installing transformers ${TRANSFORMERS_VERSION} (from ${TRANSFORMERS_PACKAGE})"
pip3 install --no-cache-dir ${TRANSFORMERS_PACKAGE}

# Apply patch only if needed (Ubuntu 20.04)
if [ $(lsb_release -rs) = "20.04" ]; then
    PYTHON_ROOT=$(pip3 show transformers | grep Location: | cut -d' ' -f2)
    sed -i -e 's|torch.distributed.is_initialized|torch.distributed.is_available|g' \
        ${PYTHON_ROOT}/transformers/modeling_utils.py
fi

# Clean up
rm -rf /root/.cache/pip