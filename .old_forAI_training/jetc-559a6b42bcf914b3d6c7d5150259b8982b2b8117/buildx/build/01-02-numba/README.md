<!-- COMMIT-TRACKING: UUID-20240731-111500-HEREDOCFIX -->
<!-- Description: Update README to reflect heredoc syntax fix. -->
<!-- Author: GitHub Copilot -->

# Numba Dockerfile Optimizations

This README documents the changes made to the Dockerfile in this directory.

## Changes Applied (Previous - UUID-20240731-093000-PLATALL)

1.  **Updated Commit Tracking:** The `COMMIT-TRACKING` header UUID and description were updated.
2.  **Platform Enforcement:** Added `ARG TARGETPLATFORM=linux/arm64` and modified the `FROM` instruction to `FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}` to explicitly set the build platform for `Dockerfile`.
3.  **Consolidation:** The test script (`test.py`) logic was embedded directly into the `Dockerfile`. The CUDA target was removed from the build-time test to avoid driver dependency issues during the build phase.

## Changes Applied (Current - UUID-20240731-111500-HEREDOCFIX)

1.  **Heredoc Syntax Fix:** Corrected a syntax error in the `RUN` command that uses a heredoc (`<<EOF`) to create the embedded test script. Removed an extraneous shell command (`&& print(...)`) that was causing the build to fail.
2.  **Updated Commit Tracking:** Updated headers in `Dockerfile` and this `README.md`.

These changes fix the build error caused by incorrect heredoc usage and ensure consistency in commit tracking.
