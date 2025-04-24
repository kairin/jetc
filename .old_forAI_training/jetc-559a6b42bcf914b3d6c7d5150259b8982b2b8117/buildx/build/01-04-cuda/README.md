<!--
# COMMIT-TRACKING: UUID-20240730-100000-B4D1
# Description: Consolidate all CUDA subcomponent documentation into a single README.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 01-cuda/             <- CUDA directory
# │   │       └── README.md        <- THIS FILE
# └── ...                        <- Other project files
-->

# CUDA Related Dockerfile Optimizations

This README documents the changes made to the Dockerfiles within the `01-cuda` directory and its subdirectories (`001-cuda`, `002-cuda-python`, `003-cudnn`, `004-cupy`, `005-pycuda`).

## Changes Applied Across Dockerfiles

1.  **Updated Commit Tracking:** The `COMMIT-TRACKING` header UUID and description were updated in all relevant Dockerfiles and configuration files (`config.py`, `test.py`).
2.  **Platform Enforcement:** Added `ARG TARGETPLATFORM=linux/arm64` and modified the `FROM` instruction to `FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}` in all Dockerfiles to explicitly set the build platform.
3.  **Consolidation:** Several components (like `cuda`, `cuda-python`, `cupy`) were consolidated into unified Dockerfiles with `INSTALL_MODE` arguments to handle different installation/build scenarios (package install, source build, pre-built wheel install). Tests were embedded directly within the Dockerfiles where applicable.

These changes ensure consistency in commit tracking, enforce the target platform during the build process, and streamline the build logic for CUDA-related components.
