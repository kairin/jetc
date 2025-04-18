# COMMIT-TRACKING: UUID-20240608-181500-7B2C
# Description: Run jetson-containers with preset options for kairin/001 image
# Author: GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Current directory
# │   └── jetcrun.sh             <- THIS FILE
# └── ...                        <- Other project files

jetson-containers run --gpus all -v /media/kkk:/workspace -it --rm --user root $(autotag kairin/001:latest-20250412-230811-1) /bin/bash