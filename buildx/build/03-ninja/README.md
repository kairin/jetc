<!-- COMMIT-TRACKING: UUID-20240730-220000-PLATALL -->
<!-- Description: Update README to reflect Dockerfile optimizations. -->
<!-- Author: GitHub Copilot -->

# Ninja Dockerfile Optimizations

This README documents the changes made to the Dockerfile in this directory.

## Changes Applied

1.  **Updated Commit Tracking:** The `COMMIT-TRACKING` header UUID and description were updated.
2.  **Platform Enforcement:** Added `ARG TARGETPLATFORM=linux/arm64` and modified the `FROM` instruction to `FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}` to explicitly set the build platform for `Dockerfile`.

These changes ensure consistency in commit tracking and enforce the target platform during the build process.
