<!-- COMMIT-TRACKING: UUID-20240730-180000-LNT1 -->
<!-- Description: Update README to reflect Dockerfile optimizations. -->
<!-- Author: GitHub Copilot -->

# Numpy Dockerfile Optimizations

This README documents the changes made to the Dockerfile in this directory.

## Changes Applied

1.  **Updated Commit Tracking:** The `COMMIT-TRACKING` header UUID and description were updated.
2.  **Platform Enforcement:** Added `ARG TARGETPLATFORM=linux/arm64` and modified the `FROM` instruction to `FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}` to explicitly set the build platform for `Dockerfile`.
3.  **Consolidation:** Logic previously in `config.py` (handling different numpy versions based on CUDA) and the test script (`test.py`) were embedded directly into the `Dockerfile`.

These changes ensure consistency in commit tracking, enforce the target platform, and consolidate build/test logic into a single file.
