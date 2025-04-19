# COMMIT-TRACKING: UUID-20240730-101500-A1B2
# Description: Add --break-system-packages flag to pip install numba for PEP 668 compatibility.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── build/                     <- Current directory
# │   └── 01-01-numba/           <- Current directory
# │       └── Dockerfile         <- THIS FILE
# └── ...                        <- Other project files

ARG BASE_IMAGE
FROM ${BASE_IMAGE}

# Install numba
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3-pip \
        llvm-14 \
        libedit-dev && \
    # Add --break-system-packages flag here
    pip3 install --no-cache-dir --break-system-packages numba && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Verify installation (optional)
RUN python3 -c "import numba; print(numba.__version__)"
