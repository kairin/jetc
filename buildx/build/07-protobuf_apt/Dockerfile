# COMMIT-TRACKING: UUID-20240730-150000-SED1
# Description: Hardcode FROM line based on previous stage.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 07-protobuf_apt/     <- Current directory
# │   │       └── Dockerfile       <- THIS FILE
# └── ...                        <- Other project files
# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

#---
# name: protobuf:apt
# group: build
# depends: [python]
# test: [test.py, test.sh]
# notes: install protobuf from apt repo
#---
# Hardcoded base image from the previous stage
FROM kairin/001:06-rust

# confirm first that the protobuf:cpp package isn't already installed
RUN if [ -z "$(which protoc)" ]; then \
        apt-get update; \
	   apt-get install -y --no-install-recommends \
	       protobuf-compiler \
		  libprotoc-dev \
		  libprotobuf-dev; \
	   rm -rf /var/lib/apt/lists/*; \
	   apt-get clean; \
	   pip3 install --upgrade  protobuf; \
    fi

