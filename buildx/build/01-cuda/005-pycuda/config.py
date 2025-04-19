# COMMIT-TRACKING: UUID-20240730-100000-B4D1
# Description: Add header, confirm test key removal (implicitly done by structure).
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 01-cuda/             <- CUDA directory
# │   │       └── pycuda/          <- Current directory
# │   │           └── config.py    <- THIS FILE
# └── ...                        <- Other project files
from jetson_containers import PYTHON_VERSION, package
from packaging.version import Version

package['build_args'] = {
    # v2022.1 is the last version to support Python 3.6
    'PYCUDA_VERSION': 'v2022.1' if PYTHON_VERSION == Version('3.6') else 'main',
}
# 'test' key is implicitly handled by the build system structure and not needed here.
