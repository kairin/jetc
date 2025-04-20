<!--
# COMMIT-TRACKING: UUID-20240801-170000-PLATFORM
# Description: Update README to reflect script consolidation and Dockerfile optimizations.
# Author: GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Main buildx directory
# │   └── build/                 <- Build directory
# │       └── 09-opencv/         <- Current directory
# │           └── README.md      <- THIS FILE
-->

# OpenCV Dockerfile Optimizations

This README documents the changes made to the Dockerfiles in this directory.

## Changes Applied

1. **Script Consolidation:** Merged three separate installation scripts into a single unified script.
   - Combined `install.sh`, `install_deps.sh`, and `install_deb.sh` into a single `install_combined.sh`
   - Structured the script with modular functions for better maintainability
   - Reduced file count from 4 to 2 scripts (including build.sh)

2. **Updated Commit Tracking:** The `COMMIT-TRACKING` headers were updated in all files.
   - Main Dockerfile updated to `UUID-20240801-170000-PLATFORM`
   - Build script updated to `UUID-20240801-150000-PLATFORM`
   - New consolidated install script added with `UUID-20240801-160000-PLATFORM`

3. **Platform Enforcement:** 
   - Added `ARG TARGETPLATFORM=linux/arm64` before the FROM instructions
   - Modified the FROM instructions to use `FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}`
   - This ensures consistent builds across different platforms

4. **Build Script Optimization:**
   - Retained git clone optimizations in the build script using `--depth 1` for shallow clones
   - This significantly speeds up the build process while maintaining functionality

5. **Verification Checks:** 
   - Kept the existing checks for the OpenCV installation:
     ```
     echo "check_python_pkg onnxruntime" >> /opt/list_app_checks.sh
     echo "check_python_pkg cv2" >> /opt/list_app_checks.sh
     ```

These changes significantly reduce the complexity of the build system while maintaining all functionality. The consolidation of installation scripts makes the codebase more maintainable and easier to understand, while the platform enforcement ensures consistent builds across different environments.
