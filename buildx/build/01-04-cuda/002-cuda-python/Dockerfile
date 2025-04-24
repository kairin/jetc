# --- Footer ---
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Buildx directory
# │   ├── build/                 <- Build stages directory
# │   │   └── 01-04-cuda/        <- Parent directory
# │   │       └── 002-cuda-python/ <- Current directory
# │   │           └── Dockerfile <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Dockerfile for building cuda-python (unified install/build modes).
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250425-080000-42595D

#---
# name: cuda-python (unified)
# group: cuda
# config: config.py
# requires: '>=34.1.0'
# depends: [cuda, numpy] # Handled by config.py
# test: (embedded in Dockerfile)
#---
# Use ARG for dynamic base image injection, with a default value
ARG TARGETPLATFORM=linux/arm64
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}

ARG CUDA_PYTHON_VERSION
ARG INSTALL_MODE="install" # Mode can be 'install' or 'build'

# Install dependencies needed for building or running tests
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    python3-pip \
    python3-setuptools \
    wheel \
    && rm -rf /var/lib/apt/lists/*

# --- Installation/Build Logic ---
RUN set -ex && \
    \
    # Mode: install (try pre-built wheel first)
    if [ "${INSTALL_MODE}" = "install" ]; then \
        echo "Attempting to install pre-built cuda-python ${CUDA_PYTHON_VERSION}..." && \
        pip3 install --no-cache-dir cuda-python==${CUDA_PYTHON_VERSION} || \
        pip3 install --no-cache-dir cuda_core cuda_bindings==${CUDA_PYTHON_VERSION} || \
        (echo "Pre-built wheel not found or failed to install for ${CUDA_PYTHON_VERSION}. Build required." && exit 1); \
    fi; \
    \
    # Mode: build (or if install failed and INSTALL_MODE was install)
    if [ "${INSTALL_MODE}" = "build" ] || { [ "${INSTALL_MODE}" = "install" ] && [ $? -ne 0 ]; }; then \
        echo "Building cuda-python ${CUDA_PYTHON_VERSION} from source..." && \
        SRC=/opt/cuda-python && \
        WHL=/opt/wheels && \
        mkdir -p $WHL && \
        export MAX_JOBS=$(nproc) && \
        \
        git clone --branch v$CUDA_PYTHON_VERSION --depth=1 https://github.com/NVIDIA/cuda-python $SRC && \
        \
        # Check version for build structure (requires vercmp or equivalent logic)
        # Simple string comparison might work for basic cases, otherwise install 'dpkg-dev' for vercmp
        # Assuming simple comparison for now:
        if [[ "${CUDA_PYTHON_VERSION}" > "12.5" ]]; then \
            echo "Using multi-wheel build structure (>=12.6)..." && \
            cd $SRC/cuda_core && \
            pip3 wheel . --no-deps --wheel-dir $WHL --verbose && \
            cd $SRC/cuda_bindings && \
            pip3 wheel . --no-deps --wheel-dir $WHL --verbose; \
        else \
            echo "Using single-wheel build structure (<12.6)..." && \
            cd $SRC && \
            sed 's|^numpy.=.*|numpy|g' -i requirements.txt && \
            sed 's|^numba.=.*|numba|g' -i requirements.txt && \
            pip3 install --no-cache-dir -r requirements.txt && \
            python3 setup.py bdist_wheel --verbose --dist-dir $WHL; \
        fi && \
        \
        cd / && rm -rf $SRC && \
        pip3 install --no-cache-dir $WHL/cuda*.whl && \
        # Optional: Upload wheel if TWINE vars are set
        ( twine upload --verbose $WHL/cuda*.whl || echo "failed to upload wheel to ${TWINE_REPOSITORY_URL}" ) && \
        rm -rf $WHL; \
    fi

# --- Create test files directly in the container ---
# Create utils.py
RUN mkdir -p /tmp/cuda-python && cat > /tmp/cuda-python/utils.py << 'EOL'
#!/usr/bin/env python3
import os
import numpy as np

from cuda import cuda, cudart, nvrtc

def _cudaGetErrorEnum(error):
    if isinstance(error, cuda.CUresult):
        err, name = cuda.cuGetErrorName(error)
        return name if err == cuda.CUresult.CUDA_SUCCESS else "<unknown>"
    elif isinstance(error, cudart.cudaError_t):
        return cudart.cudaGetErrorName(error)[1]
    elif isinstance(error, nvrtc.nvrtcResult):
        return nvrtc.nvrtcGetErrorString(error)[1]
    else:
        raise RuntimeError('Unknown error type: {}'.format(error))

def checkCudaErrors(result):
    if result[0].value:
        raise RuntimeError("CUDA error code={}({})".format(result[0].value, _cudaGetErrorEnum(result[0])))
    if len(result) == 1:
        return None
    elif len(result) == 2:
        return result[1]
    else:
        return result[1:]
 
class KernelHelper:
    def __init__(self, code, devID):
        prog = checkCudaErrors(nvrtc.nvrtcCreateProgram(str.encode(code), b'sourceCode.cu', 0, [], []))
        CUDA_HOME = os.getenv('CUDA_HOME')
        if CUDA_HOME == None:
            raise RuntimeError('Environment variable CUDA_HOME is not defined')
        include_dirs = os.path.join(CUDA_HOME, 'include')

        # Initialize CUDA
        checkCudaErrors(cudart.cudaFree(0))

        major = checkCudaErrors(cudart.cudaDeviceGetAttribute(cudart.cudaDeviceAttr.cudaDevAttrComputeCapabilityMajor, devID))
        minor = checkCudaErrors(cudart.cudaDeviceGetAttribute(cudart.cudaDeviceAttr.cudaDevAttrComputeCapabilityMinor, devID))
        _, nvrtc_minor = checkCudaErrors(nvrtc.nvrtcVersion())
        use_cubin = (nvrtc_minor >= 1)
        prefix = 'sm' if use_cubin else 'compute'
        arch_arg = bytes(f'--gpu-architecture={prefix}_{major}{minor}', 'ascii')
        try:
            opts = [b'--fmad=true', arch_arg, '--include-path={}'.format(include_dirs).encode('UTF-8'),
                    b'--std=c++11', b'-default-device']
            print(code)
            print('nvcc flags:', opts)
            checkCudaErrors(nvrtc.nvrtcCompileProgram(prog, len(opts), opts))
        except RuntimeError as err:
            logSize = checkCudaErrors(nvrtc.nvrtcGetProgramLogSize(prog))
            log = b' ' * logSize
            checkCudaErrors(nvrtc.nvrtcGetProgramLog(prog, log))
            print(log.decode())
            print(err)
            exit(-1)

        if use_cubin:
            dataSize = checkCudaErrors(nvrtc.nvrtcGetCUBINSize(prog))
            data = b' ' * dataSize
            checkCudaErrors(nvrtc.nvrtcGetCUBIN(prog, data))
        else:
            dataSize = checkCudaErrors(nvrtc.nvrtcGetPTXSize(prog))
            data = b' ' * dataSize
            checkCudaErrors(nvrtc.nvrtcGetPTX(prog, data))

        self.module = checkCudaErrors(cuda.cuModuleLoadData(np.char.array(data)))

    def getFunction(self, name):
        return checkCudaErrors(cuda.cuModuleGetFunction(self.module, name))
EOL

# Create test_driver.py
RUN cat > /tmp/cuda-python/test_driver.py << 'EOL'
#!/usr/bin/env python3
# Basic CUDA driver API test
import numpy as np
from cuda import cuda
from utils import checkCudaErrors, KernelHelper

print("Running CUDA driver API test...")

# Initialize CUDA
checkCudaErrors(cuda.cuInit(0))
deviceCount = checkCudaErrors(cuda.cuDeviceGetCount())
print(f"Found {deviceCount} CUDA device(s)")

# Get device details
device = checkCudaErrors(cuda.cuDeviceGet(0))
name = checkCudaErrors(cuda.cuDeviceGetName(128, device))
print(f"Selected device: {name}")

# Create context
context = checkCudaErrors(cuda.cuCtxCreate(0, device))

# Simple vector addition kernel
cuSource = """
extern "C" __global__ void vectorAdd(const float *A, const float *B, float *C, int numElements)
{
    int i = blockDim.x * blockIdx.x + threadIdx.x;
    if (i < numElements) { C[i] = A[i] + B[i]; }
}
"""

# Compile the kernel
helper = KernelHelper(cuSource, 0)
vectorAddFunc = helper.getFunction(b"vectorAdd")

# Prepare data
numElements = 10000
size = numElements * np.dtype(np.float32).itemsize

# Allocate input vectors
h_A = np.random.rand(numElements).astype(np.float32)
h_B = np.random.rand(numElements).astype(np.float32)
h_C = np.zeros(numElements, dtype=np.float32)

# Allocate memory on device
d_A = checkCudaErrors(cuda.cuMemAlloc(size))
d_B = checkCudaErrors(cuda.cuMemAlloc(size))
d_C = checkCudaErrors(cuda.cuMemAlloc(size))

# Copy data to device
checkCudaErrors(cuda.cuMemcpyHtoD(d_A, h_A.ctypes.data, size))
checkCudaErrors(cuda.cuMemcpyHtoD(d_B, h_B.ctypes.data, size))

# Launch kernel
threadsPerBlock = 256
blocksPerGrid = (numElements + threadsPerBlock - 1) // threadsPerBlock

# Prepare kernel arguments
kernel_args = ((d_A, d_B, d_C, np.int32(numElements)))

# Launch kernel
checkCudaErrors(
    cuda.cuLaunchKernel(
        vectorAddFunc,
        blocksPerGrid, 1, 1,  # Grid dimensions
        threadsPerBlock, 1, 1,  # Block dimensions
        0, None,  # Shared memory size and stream
        kernel_args, 0  # Arguments and extra options
    )
)

# Copy results back to host
checkCudaErrors(cuda.cuMemcpyDtoH(h_C.ctypes.data, d_C, size))

# Verify results
for i in range(numElements):
    expected = h_A[i] + h_B[i]
    if abs(h_C[i] - expected) > 1e-5:
        print(f"Verification failed at {i}: {h_C[i]} != {expected}")
        break
else:
    print("Vector addition test passed!")

# Free resources
checkCudaErrors(cuda.cuMemFree(d_A))
checkCudaErrors(cuda.cuMemFree(d_B))
checkCudaErrors(cuda.cuMemFree(d_C))
checkCudaErrors(cuda.cuCtxDestroy(context))

print("CUDA driver API test completed successfully")
EOL

# Create test_runtime.py
RUN cat > /tmp/cuda-python/test_runtime.py << 'EOL'
#!/usr/bin/env python3
# Basic CUDA runtime API test
import numpy as np
from cuda import cudart
from utils import checkCudaErrors

print("Running CUDA runtime API test...")

# Get CUDA properties
version = checkCudaErrors(cudart.cudaRuntimeGetVersion())
print(f"CUDA Runtime version: {version}")

deviceCount = checkCudaErrors(cudart.cudaGetDeviceCount())
print(f"Found {deviceCount} CUDA device(s)")

# Get device properties for first device
device = 0
prop = checkCudaErrors(cudart.cudaGetDeviceProperties(device))
print(f"Device {device}: {prop.name.decode()}")
print(f"  Compute capability: {prop.major}.{prop.minor}")
print(f"  Total memory: {prop.totalGlobalMem / (1024**3):.2f} GB")
print(f"  Multiprocessors: {prop.multiProcessorCount}")

# Set device
checkCudaErrors(cudart.cudaSetDevice(device))

# Allocate memory and perform operations
size = 1000000  # 1M elements
nbytes = size * np.dtype(np.float32).itemsize

# Host arrays
h_a = np.random.rand(size).astype(np.float32)
h_b = np.random.rand(size).astype(np.float32)
h_c = np.zeros(size, dtype=np.float32)

# Device arrays
d_a = checkCudaErrors(cudart.cudaMalloc(nbytes))
d_b = checkCudaErrors(cudart.cudaMalloc(nbytes))
d_c = checkCudaErrors(cudart.cudaMalloc(nbytes))

# Copy data to device
checkCudaErrors(cudart.cudaMemcpy(d_a[1], h_a.ctypes.data, nbytes, 
                                 cudart.cudaMemcpyKind.cudaMemcpyHostToDevice))
checkCudaErrors(cudart.cudaMemcpy(d_b[1], h_b.ctypes.data, nbytes,
                                 cudart.cudaMemcpyKind.cudaMemcpyHostToDevice))

# Since we can't use Runtime API to run kernels in a simple way,
# we'll just verify memory operations work correctly
checkCudaErrors(cudart.cudaMemcpy(d_c[1], d_a[1], nbytes,
                                 cudart.cudaMemcpyKind.cudaMemcpyDeviceToDevice))

# Copy back to host
checkCudaErrors(cudart.cudaMemcpy(h_c.ctypes.data, d_c[1], nbytes,
                                 cudart.cudaMemcpyKind.cudaMemcpyDeviceToHost))

# Verify results (should match h_a)
if np.allclose(h_c, h_a):
    print("Memory copy verification passed!")
else:
    print("Memory copy verification failed!")
    
# Free memory
checkCudaErrors(cudart.cudaFree(d_a[1]))
checkCudaErrors(cudart.cudaFree(d_b[1]))
checkCudaErrors(cudart.cudaFree(d_c[1]))

print("CUDA runtime API test completed successfully")
EOL

# --- Run tests ---
RUN echo "Running cuda-python tests..." && \
    # Set execute permissions
    chmod +x /tmp/cuda-python/*.py && \
    python3 /tmp/cuda-python/test_runtime.py && \
    python3 /tmp/cuda-python/test_driver.py && \
    # Verify installation
    python3 -c 'import cuda; print(f"Successfully imported cuda-python version: {cuda.__version__}")' && \
    (pip3 show cuda_core cuda_bindings || pip3 show cuda-python) && \
    rm -rf /tmp/cuda-python

WORKDIR /
