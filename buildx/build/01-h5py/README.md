<!-- COMMIT-TRACKING: UUID-20240731-100000-h5py -->
<!-- Description: Update README to reflect Dockerfile optimizations. -->
<!-- Author: GitHub Copilot -->

# H5Py Dockerfile Optimizations

This README documents the changes made to the Dockerfile in this directory.

## Changes Applied

1.  **Updated Commit Tracking:** The `COMMIT-TRACKING` header UUID, description, and author were updated.
2.  **Platform Enforcement:** Added `ARG TARGETPLATFORM=linux/arm64` and modified the `FROM` instruction to `FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}` to explicitly set the build platform.
3.  **Consolidation:** The test script (`test.py`) logic was embedded directly into the Dockerfile.
4.  **Verification Checks:** Added `check_python_package h5py ${H5PY_VERSION}` to `/opt/list_app_checks.sh`.
