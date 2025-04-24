# --- Footer ---
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Buildx directory
# │   ├── build/                 <- Build stages directory
# │   │   └── 01-04-cuda/        <- Parent directory
# │   │       └── 005-pycuda/    <- Current directory
# │   │           └── config.py  <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Configuration script for the PyCUDA build stage.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250425-080000-42595D

from jetson_containers import PYTHON_VERSION, package
from packaging.version import Version

package['build_args'] = {
    # v2022.1 is the last version to support Python 3.6
    'PYCUDA_VERSION': 'v2022.1' if PYTHON_VERSION == Version('3.6') else 'main',
}
# 'test' key is implicitly handled by the build system structure and not needed here.
