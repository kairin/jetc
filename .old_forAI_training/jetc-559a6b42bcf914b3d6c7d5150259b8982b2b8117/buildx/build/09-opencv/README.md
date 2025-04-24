<!-- COMMIT-TRACKING: UUID-20240803-193500-RESTRUCTURE -->
<!-- Description: Update README for builder/runtime Dockerfile split. -->
<!-- Author: GitHub Copilot -->

# OpenCV Dockerfile Structure

This directory contains Dockerfiles for building and installing OpenCV with CUDA support for Jetson platforms.

## File Structure

1.  **`Dockerfile.builder`**:
    *   Builds OpenCV C++ libraries (`.deb` packages) and Python bindings (`opencv-contrib-python` wheel) from source.
    *   Clones OpenCV, opencv_contrib, and opencv-python repositories.
    *   Applies necessary patches (`patches.diff`).
    *   Configures the build using CMake with CUDA enabled.
    *   Compiles the code using `make`.
    *   Packages the C++ libraries into `.deb` files.
    *   Builds the Python wheel using `pip wheel`.
    *   Outputs artifacts (`.whl`, `.deb`) to an `/artifacts` directory in the final stage (`artifacts_stage`).
    *   Optionally uploads artifacts if `TWINE_REPOSITORY_URL` (for wheels) or a suitable mechanism (for debs) is configured.

2.  **`Dockerfile.runtime`**:
    *   Installs OpenCV into a base image.
    *   Installs necessary runtime dependencies.
    *   Installs OpenCV either:
        *   From pre-built `.deb` packages specified by the `OPENCV_URL` build argument.
        *   From the `opencv-contrib-python` wheel via `pip` (assuming the wheel built by `Dockerfile.builder` is available in a configured Python package index).
    *   Includes verification steps to ensure OpenCV is installed correctly and functional (including a basic CUDA check).

3.  **`config.py`**:
    *   Defines package configurations for different OpenCV versions and JetPack releases.
    *   Specifies which Dockerfile (`Dockerfile.builder` or `Dockerfile.runtime`) to use for each package variant.
    *   Sets appropriate build arguments (`OPENCV_VERSION`, `CUDA_ARCH_BIN`, `OPENCV_URL`, etc.).

4.  **`patches.diff`**:
    *   Contains patches applied during the build process in `Dockerfile.builder`.

## Build Process

*   The `opencv:<version>-builder` packages use `Dockerfile.builder` to compile OpenCV and produce artifacts.
*   The `opencv:<version>` (pip) and `opencv:<version>-deb` packages use `Dockerfile.runtime` to install the pre-built library/wheel into a target image.

This separation allows for building OpenCV once and installing it multiple times, or using pre-built versions provided by NVIDIA or other sources.
