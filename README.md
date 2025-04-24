<!--
# COMMIT-TRACKING: UUID-20250422-083100-RDME
# Description: Updated README to reflect .env usage for AVAILABLE_IMAGES.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- THIS FILE
# ├── buildx/                    <- Build system and scripts
# │   ├── build/                 <- Build stages and Dockerfiles
# │   ├── build.sh               <- Main build orchestrator
# │   ├── jetcrun.sh             <- Container run utility
# │   └── scripts/               <- Modular build scripts
# ├── .github/                   <- Copilot and git integration
# │   └── copilot-instructions.md<- Coding standards and commit tracking
# └── ...                        <- Other project files
-->
# JETC: Jetson Containers for Targeted Use Cases

> **Based on [dusty-nv/jetson-containers](https://github.com/dusty-nv/jetson-containers).**  
> This repo focuses on modular, interactive, and robust Docker buildx-based container building for NVIDIA Jetson devices.

---

## Quick Start

1. **Clone and enter the repo**
   ```bash
   git clone https://github.com/kairin/jetc.git
   cd jetc/buildx
   ```

2. **(Optional) Run pre-run check**
   ```bash
   ./scripts/pre-run.sh
   ```

3. **(Optional) Create `.env` for defaults**
   ```bash
   cp .env.example .env
   # Edit as needed
   ```

4. **Run the build script**
   ```bash
   ./build.sh
   ```

5. **Run a container**
   ```bash
   ./jetcrun.sh
   ```

---

## Modular Build Steps

The build process is modular and interactive:

| Step | Script | Description |
|------|--------|-------------|
| 1 | `build_env_setup.sh` | Setup environment variables and load `.env` |
| 2 | `build_builder.sh` | Ensure buildx builder is ready |
| 3 | `build_prefs.sh` | Interactive user preferences dialog |
| 4 | `build_order.sh` | Determine build order and selected folders |
| 5 | `build_stages.sh` | Build selected numbered and other directories |
| 6 | `build_tagging.sh` | Tag and push the final image |
| 7 | `build_post.sh` | Post-build menu/options |
| 8 | `build_verify.sh` | Final verification and update `.env` |

See [proposed-app-build-sh.md](buildx/readme/proposed-app-build-sh.md) for full details.

---

## Features

- Interactive build and run scripts with persistent `.env` config
- Modular, maintainable build steps
- Automatic image tracking and verification
- Easy container selection and runtime options
- [More details...](buildx/readme/features.md)

---

## Repository Structure

See [structure.md](buildx/readme/structure.md) for a full breakdown.

---

## Usage Examples

- [Build process walkthrough](buildx/readme/proposed-app-build-sh.md)
- [Running containers with jetcrun.sh](buildx/readme/proposed-app-jetcrun-sh.md)

---

## Troubleshooting

### .env Variable Errors

- If you see errors like `No such file or directory` with an image name, check your `.env` file for invalid lines.
- Only lines of the form `VAR=value` are allowed. Do not add arbitrary text or commands.
- Never source or execute the value of a variable from `.env`.

### Docker buildx Builder

- The build system requires a working Docker buildx builder named `jetson-builder`.
- If you see errors about buildx or builder not found, run:
  ```bash
  docker buildx create --name jetson-builder --driver docker-container --use
  docker buildx start jetson-builder
  ```
- The build script will attempt to create and start the builder automatically if needed.

### Dialog Form Issues

If the build process stops after the Docker information dialog or does not proceed:

- Ensure you enter a **non-empty Docker Username** and **Repository Prefix**. These are required.
- If you leave these fields blank, the script will prompt you to correct them.
- If you see repeated prompts or the script exits, check your terminal for error messages.
- If the `.env` file is missing or incomplete, the script will prompt for all required values.

### Required .env Variables

The `buildx/.env` file stores configuration. Key variables include:

*   `DOCKER_REGISTRY`: (Optional) Your Docker registry URL (default: Docker Hub).
*   `DOCKER_USERNAME`: Your Docker username (required).
*   `DOCKER_REPO_PREFIX`: Prefix for your image repository (required, e.g., `jetc`).
*   `DEFAULT_BASE_IMAGE`: Base image used if not specified otherwise (updated on selection).
*   `AVAILABLE_IMAGES`: Semicolon-separated list of built/known images (managed by scripts).
*   `DEFAULT_IMAGE_NAME`: Last image used by `jetcrun.sh`.
*   `DEFAULT_ENABLE_X11`, `DEFAULT_ENABLE_GPU`, `DEFAULT_MOUNT_WORKSPACE`, `DEFAULT_USER_ROOT`: Default runtime options for `jetcrun.sh`.

All scripts (build, run, tagging, verification) read and update `.env` for configuration and image state. Do not edit `.env` while a build or run is in progress.

### Additional Troubleshooting Tips

*   **.env File:** Ensure the `.env` file exists in the `buildx/` directory and contains valid `DOCKER_USERNAME` and `DOCKER_REPO_PREFIX`. The script will prompt if missing, but defaults might not be ideal.
*   **Buildx Builder:** The scripts attempt to create and use a `jetson-builder` buildx instance. If you encounter errors like `ERROR: docker-container driver requires remote context or docker server running with experimental mode`, ensure Docker Desktop or your Docker daemon is running correctly and buildx is set up. You might need to manually run `docker buildx create --name jetson-builder --use` or troubleshoot your Docker installation.
*   **Dialog Errors:** If `dialog` isn't installed, the scripts should fall back to basic text prompts. If dialog installation fails or prompts don't appear, check permissions and package manager status.
*   **Debug Output:** For more detailed output during builds or runs, set the `JETC_DEBUG` environment variable:
    ```bash
    export JETC_DEBUG=true
    ./buildx/build.sh
    # or
    JETC_DEBUG=1 ./buildx/jetcrun.sh
    ```
*   **Pull Errors:** If pulling base images fails, check your network connection, registry URL (if not Docker Hub), and authentication (`docker login`).

---

## More Information

- [Features & FAQ](buildx/readme/features.md)
- [Troubleshooting](buildx/readme/troubleshooting.md)
- [Development guidelines](buildx/readme/dev-guidelines.md)
- [Container verification system](buildx/readme/verification.md)
- [Generative AI components](buildx/readme/ai-components.md)

---

## License

This project is licensed under the Creative Commons Attribution-NonCommercial 4.0 International License (CC BY-NC 4.0). This means that you are free to use, share, and adapt the project for non-commercial purposes. Commercial use and monetization are explicitly prohibited. See the LICENSE file for full details.

<!--
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- THIS FILE
# ├── buildx/                    <- Build system and scripts
# │   ├── build/                 <- Build stages and Dockerfiles
# │   ├── build.sh               <- Main build orchestrator
# │   ├── jetcrun.sh             <- Container run utility
# │   └── scripts/               <- Modular build scripts
# │   └── readme/                <- Extended documentation
# ├── .github/                   <- Copilot and git integration
# │   └── copilot-instructions.md<- Coding standards and commit tracking
# └── ...                        <- Other project files
#
# Description: Main README. Removed LOCAL_DOCKER_IMAGES from .env description. Added JETC_DEBUG note.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-140000-RMVLOCALIMG
-->
