#!/usr/bin/env bash
set -ex

echo "Building onnxruntime ${ONNXRUNTIME_VERSION} (branch=${ONNXRUNTIME_BRANCH}, flags=${ONNXRUNTIME_FLAGS})"

# Check TensorRT installation
if [ ! -d "/usr/lib/$(uname -m)-linux-gnu" ]; then
    echo "TensorRT libraries not found in /usr/lib/$(uname -m)-linux-gnu"
    exit 1
fi

# Ensure TensorRT libraries are in LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/lib/$(uname -m)-linux-gnu:$LD_LIBRARY_PATH

# Verify TensorRT core library
if [ ! -f "/usr/lib/$(uname -m)-linux-gnu/libnvinfer.so" ]; then
    echo "TensorRT core library not found"
    exit 1
fi

# Check for NVDLA library but don't fail if it's missing
if [ ! -f "/usr/lib/$(uname -m)-linux-gnu/libnvdla_compiler.so" ]; then
    echo "Warning: TensorRT NVDLA compiler library not found, but continuing with build"
fi

# Clean any previous installation
pip3 uninstall -y onnxruntime || echo "onnxruntime was not previously installed"

# Clone repository
git clone --depth=1 --branch ${ONNXRUNTIME_BRANCH} https://github.com/microsoft/onnxruntime /opt/onnxruntime
cd /opt/onnxruntime
git submodule update --init --recursive

# Fix eigen download URL if needed
sed -i 's|archive/3.4/eigen-3.4.zip;ee201b07085203ea7bd8eb97cbcb31b07cfa3efb|archive/3.4.0/eigen-3.4.0.zip;ef24286b7ece8737c99fa831b02941843546c081|' cmake/deps.txt || echo "cmake/deps.txt not found"

# Setup build environment
install_dir="/opt/onnxruntime/install"
pip3 install "cmake<4"

# Build onnxruntime
./build.sh --config Release --update --parallel --build --build_wheel --build_shared_lib \
        --skip_tests --skip_submodule_sync ${ONNXRUNTIME_FLAGS} \
        --cmake_extra_defines CMAKE_CXX_FLAGS="-Wno-unused-variable -I/usr/local/cuda/include" \
        --cmake_extra_defines CMAKE_CUDA_ARCHITECTURES="${CUDA_ARCHITECTURES}" \
        --cmake_extra_defines CMAKE_INSTALL_PREFIX=${install_dir} \
        --cmake_extra_defines onnxruntime_BUILD_UNIT_TESTS=OFF \
        --cuda_home /usr/local/cuda --cudnn_home /usr/lib/$(uname -m)-linux-gnu \
        --use_tensorrt --tensorrt_home /usr/lib/$(uname -m)-linux-gnu

# Install the built package
cd build/Linux/Release
make install

# Copy wheel to /opt for later use
cp dist/onnxruntime*.whl /opt

# Install the wheel
cd /
pip3 install /opt/onnxruntime*.whl
python3 -c 'import onnxruntime; print(onnxruntime.__version__);'

# Upload artifacts if credentials are available
twine upload --verbose /opt/onnxruntime*.whl || echo "failed to upload wheel to ${TWINE_REPOSITORY_URL}"
tarpack upload onnxruntime-gpu-${ONNXRUNTIME_VERSION} ${install_dir} || echo "failed to upload tarball"

# Install to system path
cd ${install_dir}
cp -r * /usr/local/

# Cleanup to reduce image size
cd /
rm -rf /tmp/onnxruntime /opt/onnxruntime/build
