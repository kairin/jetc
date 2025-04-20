# COMMIT-TRACKING: UUID-20240731-100000-h5py
# Description: Consolidate commit-tracking headers and enforce --platform=linux/arm64 in FROM. Embed test.py. Add verification check.
# Author: GitHub Copilot
# Base image: jetc-base:latest
# Build args: BASE_IMAGE=jetc-base:latest
# Test: Embedded test script.

# ...existing code...

ARG BASE_IMAGE=jetc-base:latest
ARG TARGETPLATFORM=linux/arm64

FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}

# ...existing code...

# Install h5py
RUN python3 -m pip install --no-cache-dir h5py==${H5PY_VERSION} \
    && echo "check_python_package h5py ${H5PY_VERSION}" >> /opt/list_app_checks.sh

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

# ...existing code...