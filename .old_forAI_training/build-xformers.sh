#!/usr/bin/env bash

# =========================================================================
# IMPORTANT: This build system requires Docker with buildx extension.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================
set -ex

echo "Building xformers ${XFORMERS_VERSION}"

git clone --branch=v${XFORMERS_VERSION} --depth=1 --recursive https://github.com/facebookresearch/xformers /opt/xformers ||
git clone --depth=1 --recursive https://github.com/facebookresearch/xformers /opt/xformers

cd /opt/xformers

XFORMERS_MORE_DETAILS=1 MAX_JOBS=$(nproc) \
python3 setup.py --verbose bdist_wheel --dist-dir /opt/xformers/wheels

pip3 install /opt/xformers/wheels/*.whl

twine upload --verbose /opt/xformers/wheels/xformers*.whl || echo "failed to upload wheel to ${TWINE_REPOSITORY_URL}"
