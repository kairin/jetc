# COMMIT-TRACKING: UUID-20240730-100000-B4D1
# Description: Update cuda_python function for unified Dockerfile and embedded tests.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 01-cuda/             <- CUDA directory
# │   │       └── cuda-python/     <- Current directory
# │   │           └── config.py    <- THIS FILE
# └── ...                        <- Other project files
from jetson_containers import L4T_VERSION, CUDA_VERSION, update_dependencies, package
from packaging.version import Version

def cuda_python(version, cuda=None):
    pkg = package.copy()

    pkg['name'] = f"cuda-python:{version}"
    pkg['dockerfile'] = 'Dockerfile' # Point to unified Dockerfile
    # pkg['test'] = [...] # Removed, tests embedded in Dockerfile

    if not cuda:
        cuda = version

    if len(cuda.split('.')) > 2:
        cuda = cuda[:-2]

    pkg['depends'] = update_dependencies(pkg['depends'], f"cuda:{cuda}")

    if len(version.split('.')) < 3:
        version = version + '.0'

    pkg['build_args'] = {
        'CUDA_PYTHON_VERSION': version,
        'INSTALL_MODE': 'install' # Default: try to install pre-built wheel
    }

    builder = pkg.copy()
    builder['name'] = builder['name'] + '-builder'
    builder['dockerfile'] = 'Dockerfile' # Point to unified Dockerfile
    builder['build_args'] = {
        'CUDA_PYTHON_VERSION': version,
        'INSTALL_MODE': 'build' # Builder forces build from source
    }

    if Version(version) == CUDA_VERSION:
        pkg['alias'] = 'cuda-python'
        builder['alias'] = 'cuda-python:builder'

    return pkg, builder

if L4T_VERSION.major <= 32:
    package = None
else:
    if L4T_VERSION.major >= 36:    # JetPack 6
        package = [
            cuda_python('12.2'),
            cuda_python('12.4'),
            cuda_python('12.6'),
            cuda_python('12.8'),
            cuda_python('13.0'),
        ]
    elif L4T_VERSION.major >= 34:  # JetPack 5
        package = [
            cuda_python('11.4'),
            #cuda_python('11.7', '11.4'),
        ]
