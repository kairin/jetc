<!-- COMMIT-TRACKING: UUID-20240801-155000-NINJA -->
<!-- Description: Update README to reflect Dockerfile optimizations. -->
<!-- Author: GitHub Copilot -->

# Ninja Dockerfile Optimizations

This README documents the changes made to the Dockerfile in this directory.

## Changes Applied

1. **Updated Commit Tracking:** The `COMMIT-TRACKING` header UUID and description were updated to reflect the latest changes.

2. **Platform Enforcement:** The Dockerfile already had `ARG TARGETPLATFORM=linux/arm64` and `FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}` to explicitly set the build platform.

3. **Consolidation:** Embedded the `test.sh` script logic directly into the Dockerfile using a heredoc approach, eliminating the need for a separate test script file.

4. **Verification Checks:** Added `check_cmd ninja --version` to `/opt/list_app_checks.sh` to ensure the Ninja build system is correctly installed and can be verified during container validation.

These changes ensure proper version tracking, build platform consistency, and simplified verification of the Ninja build system installation.
