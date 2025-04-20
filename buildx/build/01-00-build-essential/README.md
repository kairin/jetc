## Build Summary

**Build Parameters:**
*   Image Name: 01-00-build-essential
*   Platform: linux/arm64
*   Tag: kairin/001:01-00-build-essential
*   Base Image: kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu

**Build Outcome:**
*   Status: Success
*   Duration: 20.6s

**Description:**
This build stage installs essential tools required for compiling software from source in subsequent stages. Key packages installed include:
*   `build-essential` (gcc, g++, make, etc.)
*   `cmake`
*   `git`
*   `curl`, `wget`
*   `ca-certificates`
*   Python development headers (`python3-dev`)
*   Other common utilities (`locales`, `pkg-config`, etc.)

It also sets up helper scripts (`vercmp`, `tarpack`) and initializes a script (`/opt/list_app_checks.sh`) used for verification checks in later stages. This stage provides the foundational environment for building C++, Python, and other projects within the container build process.
