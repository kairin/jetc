# COMMIT-TRACKING: UUID-20240730-150000-SED1
# Description: Hardcode FROM line based on previous stage.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 08-protobuf_cpp/     <- Current directory
# │   │       └── Dockerfile       <- THIS FILE
# └── ...                        <- Other project files
# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

#---
# name: protobuf:cpp
# alias: protobuf
# group: build
# config: config.py
# depends: [build-essential, python]
# test: [test.py, test.sh]
# notes: install protobuf using pip
#---
# Hardcoded base image from the previous stage
FROM kairin/001:07-protobuf_apt

RUN apt-get update && apt-get install -y --no-install-recommends python3-pip

# Install the latest protobuf using pip
RUN pip install --upgrade protobuf
