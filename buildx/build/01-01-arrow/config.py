# COMMIT-TRACKING: UUID-20240729-004815-A3B1
# Description: Update commit tracking header UUID for consistency.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 01-01-arrow/         <- Current directory
# │   │       └── config.py        <- THIS FILE
# └── ...                        <- Other project files
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
