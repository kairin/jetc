#!/usr/bin/env bash
# triton
set -ex

# Validate environment variables
if [ -z "${TRITON_VERSION}" ]; then
    echo "Error: TRITON_VERSION is not set"
    exit 1
fi

if [ -z "${TRITON_BRANCH}" ]; then
    echo "Error: TRITON_BRANCH is not set"
    exit 1
fi

echo "============ Building triton ${TRITON_VERSION} (branch=${TRITON_BRANCH}) ============"

pip3 uninstall -y triton

# Fix git clone command to properly handle branch parameter
git clone --recursive https://github.com/triton-lang/triton /opt/triton
cd /opt/triton
git checkout ${TRITON_BRANCH}
git submodule update --init --recursive

sed -i \
    -e 's|LLVMAMDGPUCodeGen||g' \
    -e 's|LLVMAMDGPUAsmParser||g' \
    -e 's|-Werror|-Wno-error|g' \
    CMakeLists.txt
    
sed -i 's|^download_and_copy_ptxas|#|g' python/setup.py

mkdir -p third_party/cuda
ln -sf /usr/local/cuda/bin/ptxas $(pwd)/third_party/cuda/ptxas

pip3 wheel --wheel-dir=/opt --no-deps ./python

cd /
rm -rf /opt/triton 

pip3 install /opt/triton*.whl

pip3 show triton
python3 -c 'import triton'

twine upload --skip-existing --verbose /opt/triton*.whl || echo "failed to upload wheel to ${TWINE_REPOSITORY_URL}"
