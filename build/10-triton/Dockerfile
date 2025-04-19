# COMMIT-TRACKING: UUID-20240730-101500-A1B2
# Description: Remove trailing '==' from 'pip3 install triton' command.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── build/                     <- Current directory
# │   └── 10-triton/             <- Current directory
# │       └── Dockerfile         <- THIS FILE
# └── ...                        <- Other project files

ARG BASE_IMAGE
FROM ${BASE_IMAGE}

# Install dependencies for Triton
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3-pip \
        # Add other build dependencies like cmake, llvm, etc. if needed for Triton build
        && \
    # Install Triton - remove trailing '=='
    pip3 install --no-cache-dir triton \
    && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Verify installation (optional)
# RUN python3 -c "import triton; print(triton.__version__)"

# Note: If Triton installation is complex and uses an install.sh script,
# the fix might need to be applied within that script instead.
# Example if using install.sh:
# COPY install.sh /tmp/install.sh
# RUN chmod +x /tmp/install.sh && /tmp/install.sh
