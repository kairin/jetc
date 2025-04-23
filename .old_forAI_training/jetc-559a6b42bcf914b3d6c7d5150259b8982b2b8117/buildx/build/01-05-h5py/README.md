<!-- COMMIT-TRACKING: UUID-20240731-100000-h5py -->
<!-- Description: Update README to reflect consolidated Dockerfile optimizations. -->
<!-- Author: GitHub Copilot -->

# H5Py Dockerfile Optimizations

This README documents the changes made to the Dockerfile in this directory.

## Changes Applied

1. **Consolidated Implementation:** Merged best practices from multiple h5py implementations.
2. **Python Version Check:** Added conditional logic to install appropriate h5py version based on Python version.
3. **Dependencies:** Added required HDF5 development libraries.
4. **Platform Enforcement:** Used `ARG TARGETPLATFORM=linux/arm64` and `FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}`.
5. **Embedded Test:** Comprehensive test script directly embedded in the Dockerfile.
6. **Verification Checks:** Added `check_python_package h5py ${H5PY_VERSION}` to verification system.
