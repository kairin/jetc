# COMMIT-TRACKING: UUID-20240729-004815-A3B1
# Description: Add container run helper script with standard configuration
# Author: Mr K
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Current directory
# │   └── jetcrun.sh             <- THIS FILE
# └── ...                        <- Other project files

jetson-containers run --gpus all -v /media/kkk:/workspace -it --rm --user root kairin/001:latest-20250412-230811-1 /bin/bash