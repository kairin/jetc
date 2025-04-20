<!-- COMMIT-TRACKING: UUID-20240731-093000-PLATALL -->
<!-- Description: Update README to reflect Dockerfile optimizations. -->
<!-- Author: GitHub Copilot -->

# Numba Dockerfile Optimizations

This README documents the changes made to the Dockerfile in this directory.

## Changes Applied

1.  **Updated Commit Tracking:** The `COMMIT-TRACKING` header UUID and description were updated.
2.  **Platform Enforcement:** Added `ARG TARGETPLATFORM=linux/arm64` and modified the `FROM` instruction to `FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}` to explicitly set the build platform for `Dockerfile`.
3.  **Consolidation:** The test script (`test.py`) logic was embedded directly into the `Dockerfile`. The CUDA target was removed from the build-time test to avoid driver dependency issues during the build phase.

These changes ensure consistency in commit tracking, enforce the target platform, and consolidate test logic into the Dockerfile while making the build-time test more robust.
