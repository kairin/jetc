<!-- COMMIT-TRACKING: UUID-20240801-190002-README -->
<!-- Description: Update README to reflect Dockerfile optimizations. -->
<!-- Author: GitHub Copilot -->

# OpenCV Dockerfile Optimizations

This README documents the changes made to the Dockerfile in this directory.

## Changes Applied

1. **Updated Commit Tracking:** The `COMMIT-TRACKING` header UUID and description were updated.
2. **Platform Enforcement:** Added `ARG TARGETPLATFORM=linux/arm64` and modified the `FROM` instruction to `FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}`.
3. **Consolidation:** Embedded the `test_opencv.py` script logic directly into the Dockerfile.
4. **Verification Checks:** Added `check_python_pkg cv2` and `check_python_pkg onnxruntime` to `/opt/list_app_checks.sh`.
