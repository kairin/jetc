# COMMIT-TRACKING: UUID-20240731-100000-h5py
# Description: Consolidate commit-tracking headers and enforce --platform=linux/arm64 in FROM. Embed test.py. Add verification check.
# Author: GitHub Copilot
# Base image: jetc-base:latest
# Build args: BASE_IMAGE=jetc-base:latest
# Test: Embedded test script.

# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 01-h5py/             <- Current directory
# │   │       └── Dockerfile       <- THIS FILE
# └── ...                        <- Other project files
# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

#---
# name: h5py
# group: core
# depends: [python, numpy]
# test: Embedded test script
#---

ARG BASE_IMAGE=jetc-base:latest
ARG TARGETPLATFORM=linux/arm64

FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}

# Install h5py with dependencies and version check
RUN set -ex && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        libhdf5-serial-dev \
        hdf5-tools \
        libhdf5-dev && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean && \
    if python3 -c "import sys; exit(0 if sys.version_info < (3,9) else 1)"; then \
        echo "Python < 3.9 => installing h5py<3.12" && \
        H5PY_SETUP_REQUIRES=0 pip3 install "h5py<3.12"; \
        H5PY_VERSION=$(pip3 show h5py | grep ^Version | cut -d' ' -f2); \
    else \
        echo "Python >= 3.9 => installing h5py>=3.12" && \
        H5PY_SETUP_REQUIRES=0 pip3 install "h5py>=3.12"; \
        H5PY_VERSION=$(pip3 show h5py | grep ^Version | cut -d' ' -f2); \
    fi && \
    echo "check_python_package h5py ${H5PY_VERSION}" >> /opt/list_app_checks.sh

# Test h5py installation by embedding test.py
RUN <<EOF > /tmp/test_h5py.py
#!/usr/bin/env python3
# COMMIT-TRACKING: UUID-20240731-100000-h5py
# Description: Test h5py installation (embedded in Dockerfile).
# Author: GitHub Copilot

import h5py
import numpy as np
import sys
import os

print(f"h5py version: {h5py.__version__}")
print(f"HDF5 version: {h5py.version.hdf5_version}")

# Create a dummy file
file_path = "/tmp/test_h5py_file.hdf5"
try:
    with h5py.File(file_path, 'w') as f:
        # Create a dataset
        dset = f.create_dataset("mydataset", (100,), dtype='i')
        dset[...] = np.arange(100)

        # Create a group
        grp = f.create_group("mygroup")
        grp.create_dataset("another_dataset", data=np.random.rand(10, 10))

        # Add attributes
        f.attrs['file_attribute'] = 'test attribute'
        dset.attrs['dataset_attribute'] = 12345

    print(f"Successfully created HDF5 file: {file_path}")

    # Verify reading the file
    with h5py.File(file_path, 'r') as f:
        print("Reading back data:")
        print(f"Dataset 'mydataset': {f['mydataset'][:10]}...") # Print first 10 elements
        print(f"Group 'mygroup' contents: {list(f['mygroup'].keys())}")
        print(f"File attribute: {f.attrs['file_attribute']}")
        print(f"Dataset attribute: {f['mydataset'].attrs['dataset_attribute']}")

    print("h5py test successful.")
    sys.exit(0)

except Exception as e:
    print(f"Error during h5py test: {e}", file=sys.stderr)
    sys.exit(1)

finally:
    # Clean up the dummy file
    if os.path.exists(file_path):
        os.remove(file_path)
        print(f"Cleaned up {file_path}")

EOF
RUN python3 /tmp/test_h5py.py && rm /tmp/test_h5py.py