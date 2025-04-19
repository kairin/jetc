# COMMIT-TRACKING: UUID-20240730-100000-B4D1
# Description: Add header, implement INSTALL_MODE for install/build, remove test key.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 01-cuda/             <- CUDA directory
# │   │       └── cupy/            <- Current directory
# │   │           └── config.py    <- THIS FILE
# └── ...                        <- Other project files
from jetson_containers import L4T_VERSION, CUDA_ARCHITECTURES, package

# latest cupy versions to support Python 3.8 (for JetPack 5)
# and Python 3.6 (for JetPack 4), respectively
if L4T_VERSION.major >= 36:
    CUPY_VERSION = 'main'
elif L4T_VERSION.major >= 34:
    CUPY_VERSION = 'v12.1.0'
else:
    CUPY_VERSION = 'v9.6.0'

# set CUPY_NVCC_GENERATE_CODE in the form of:
#   "arch=compute_53,code=sm_53;arch=compute_62,code=sm_62;arch=compute_72,code=sm_72;arch=compute_87,code=sm_87"
CUPY_NVCC_GENERATE_CODE = [f"arch=compute_{x},code=sm_{x}" for x in CUDA_ARCHITECTURES]
CUPY_NVCC_GENERATE_CODE = ';'.join(CUPY_NVCC_GENERATE_CODE)

# Base package definition (tries install first)
pkg = package.copy()
pkg['dockerfile'] = 'Dockerfile'
# pkg['test'] = 'test.py' # Removed
pkg['build_args'] = {
    'CUPY_VERSION': CUPY_VERSION,
    'CUPY_NVCC_GENERATE_CODE': CUPY_NVCC_GENERATE_CODE,
    'INSTALL_MODE': 'install', # Try pre-built wheel first
}

# Builder package definition (forces build)
builder = package.copy()
builder['name'] = 'cupy:builder'
builder['dockerfile'] = 'Dockerfile'
# builder['test'] = 'test.py' # Removed
builder['build_args'] = {
    'CUPY_VERSION': CUPY_VERSION,
    'CUPY_NVCC_GENERATE_CODE': CUPY_NVCC_GENERATE_CODE,
    'INSTALL_MODE': 'build', # Force build from source
}

package = [pkg, builder]