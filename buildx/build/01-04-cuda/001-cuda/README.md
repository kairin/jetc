# CUDA Unified Build Stage (`001-cuda`)

This directory contains a unified `Dockerfile` for building CUDA-related images based on the `INSTALL_MODE` build argument.

## Modes

*   **`package`**: Installs the CUDA toolkit from NVIDIA's `.deb` packages.
*   **`samples`**: Clones and builds the NVIDIA CUDA Samples. Requires a base image with CUDA toolkit already installed (e.g., depends on `package` mode).
*   **`builtin`**: Assumes CUDA is pre-installed in the base image (e.g., L4T base images) and primarily sets environment variables.
*   **`pip`**: Sets up environment variables for using a pip cache server.

## Configuration

Build arguments are controlled by `config.py` in this directory.

## Build Process Notes

This stage uses a single `Dockerfile` (`buildx/build/01-04-cuda/001-cuda/Dockerfile`) managed by `config.py`.

**Important:** If you encounter build errors related to missing files like `install.sh`, ensure your build command is correctly targeting this directory (`buildx/build/01-04-cuda/001-cuda/`) as the build context and specifying this `Dockerfile`. Older configurations might incorrectly point to the parent directory (`buildx/build/01-04-cuda/`) or expect external scripts that are no longer used in this unified setup.
