<!-- COMMIT-TRACKING: UUID-20240731-100000-bazel -->
<!-- Description: Update README to reflect Dockerfile optimizations. -->
<!-- Author: GitHub Copilot -->

# Bazel Dockerfile Optimizations

This README documents the changes made to the Dockerfile in this directory.

## Changes Applied

1.  **Created Dockerfile:** Added a new Dockerfile for Bazel installation.
2.  **Added Commit Tracking:** Included the standard `COMMIT-TRACKING` header.
3.  **Platform Enforcement:** Added `ARG TARGETPLATFORM=linux/arm64` and used `FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}`.
4.  **Installation:** Added steps to download, verify, and install Bazel `${BAZEL_VERSION}`.
5.  **Consolidation:** Embedded the test script (`test.sh`) logic directly into the Dockerfile.
6.  **Verification Checks:** Added `check_cmd bazel --version` to `/opt/list_app_checks.sh`.
