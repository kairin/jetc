<!-- COMMIT-TRACKING: UUID-20240731-153001-protobufapt-readme -->
<!-- Description: Update README to reflect Dockerfile optimizations for protobuf_apt. -->
<!-- Author: GitHub Copilot -->

# Protobuf Apt Dockerfile Optimizations

This README documents the changes made to the Dockerfile in this directory (`07-protobuf_apt`).

## Changes Applied

1.  **Updated Commit Tracking:** The `COMMIT-TRACKING` header UUID and description were updated to reflect the consolidation and optimization changes.
2.  **Platform Enforcement:** Added `ARG TARGETPLATFORM=linux/arm64` and modified the `FROM` instruction to `FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}` to explicitly set the build platform, ensuring arm64 architecture.
3.  **Consolidation:** The test script (`test.sh`) logic was embedded directly into the Dockerfile using a `RUN cat <<EOF ...` block. The original `test.sh` file is no longer needed for the build process. The `# test:` metadata comment in the Dockerfile header was updated to `embedded`.
4.  **Verification Checks:** Added checks for the installed components to `/opt/list_app_checks.sh`:
    *   `check_cmd protoc` verifies the protobuf compiler command is available.
    *   `check_python_package protobuf` verifies the Python protobuf package is installed.
