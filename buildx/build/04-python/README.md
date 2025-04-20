<!-- COMMIT-TRACKING: UUID-20240730-180000-LNT1 -->
<!-- Description: Update README to reflect Dockerfile optimizations. -->
<!-- Author: GitHub Copilot -->

# Python Dockerfile Optimizations

This README documents the changes made to the Dockerfile and related files in this directory.

## Changes Applied

1.  **Updated Commit Tracking:** The `COMMIT-TRACKING` header UUID and description were updated in `Dockerfile` and `install.sh`.
2.  **Platform Enforcement:** Added `ARG TARGETPLATFORM=linux/arm64` and modified the `FROM` instruction to `FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}` in `Dockerfile` to explicitly set the build platform.
3.  **Config Update:** Added Python 3.13 and 3.14 support in `config.py`.

These changes ensure consistency in commit tracking, enforce the target platform during the build process, and update Python version support.
