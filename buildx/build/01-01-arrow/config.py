# COMMIT-TRACKING: UUID-20240731-100000-PROTOFIX
# Description: Remove redundant apt install/remove of protobuf-dev packages. Rely on BUNDLED source.
# Author: GitHub Copilot
from jetson_containers import L4T_VERSION, CUDA_ARCHITECTURES

def build_arrow(version, branch, default=False):
    arrow = package.copy()
    
    arrow['name'] = f'arrow:{version}'
    arrow['build_args'] = {'ARROW_BRANCH': branch}
    
    if default:
        arrow['alias'] = 'arrow'
        
    return arrow
    
package = [
    build_arrow('19.0.1', 'apache-arrow-19.0.1', default=True),
    build_arrow('14.0.1', 'apache-arrow-14.0.1', default=False),
    build_arrow('12.0.1', 'apache-arrow-12.0.1'),
    build_arrow('5.0.0', 'apache-arrow-5.0.0'),
]

# COMMIT-TRACKING: UUID-20240731-110000-NOORC
# Description: Disable ARROW_ORC build option due to configuration errors.
# Author: GitHub Copilot

# COMMIT-TRACKING: UUID-20240731-103000-MAKEJ4
# Description: Reduce make parallelism to -j4 to mitigate potential resource exhaustion.
# Author: GitHub Copilot

# --- Footer ---
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Buildx directory
# │   ├── build/                 <- Build stages directory
# │   │   └── 01-01-arrow/       <- Current directory
# │   │       └── config.py      <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Configuration script for the Apache Arrow build stage.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250425-080000-42595D
