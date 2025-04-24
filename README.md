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

## Modular Build Steps (Reflected in `build.sh` and `scripts/`)

The build process is orchestrated by `build.sh` and utilizes modular scripts:

1.  **Initialization & Logging:** (`build.sh`, `scripts/logging.sh`)
    *   Sources helper scripts.
    *   Initializes logging for the build process.

2.  **User Preferences & .env:** (`scripts/build_ui.sh`, `scripts/dialog_ui.sh`, `scripts/env_helpers.sh`)
    *   Presents dialogs or prompts to gather user preferences (Docker info, build options, base image, stages).
    *   Loads initial settings from `.env`.
    *   Exports selected preferences to `/tmp/build_prefs.sh`.
    *   Updates `.env` with Docker info and selected base image.

3.  **Environment & Builder Setup:** (`build.sh`, `scripts/env_helpers.sh`, `scripts/docker_helpers.sh`)
    *   Loads environment variables from `.env`.
    *   Ensures the `buildx` builder (`jetson-builder`) is running.

4.  **Load Preferences:** (`build.sh`)
    *   Sources the preferences exported by the UI step (`/tmp/build_prefs.sh`).

5.  **Determine Build Order:** (`build.sh`)
    *   Calculates the order of build stages based on user selection and folder structure.

6.  **Build Stages:** (`build.sh`, `scripts/build_stages.sh`, `scripts/docker_helpers.sh`, `scripts/env_helpers.sh`)
    *   Iterates through the selected build folders (`buildx/build/*`).
    *   Calls `build_folder_image` for each stage, passing the output of the previous stage as the base image.
    *   Updates `AVAILABLE_IMAGES` in `.env` after each successful stage build.

7.  **Base Image Verification (Optional):** (`build.sh`, `scripts/verification.sh`)
    *   Optionally verifies the contents of the selected base image before starting stage builds.

8.  **Final Tagging & Push:** (`build.sh`, `scripts/build_tagging.sh`, `scripts/docker_helpers.sh`)
    *   Generates a timestamped tag for the last successfully built image.
    *   Tags the image.
    *   Pushes the image if `Build Locally Only` was not selected.

9.  **Post-Build Menu:** (`build.sh`, `scripts/post_build_menu.sh`)
    *   Presents options to interact with the final built image (run shell, verify, etc.).

10. **Final Verification (Optional):** (`build.sh`, `scripts/verification.sh`)
    *   Optionally runs verification checks inside the final built image.

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
*   **Pull Errors (`jetcrun.sh`):** If `jetcrun.sh` fails to find an image locally. If the automatic pull fails, verify the correct image tag and pull it manually using `docker pull <correct-image-tag>`.
*   **Pull Errors (Build):** If pulling base images during the build process fails, check your network connection, registry URL (if not Docker Hub), and authentication (`docker login`).

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
# Description: Main README. Updated build steps description. Removed LOCAL_DOCKER_IMAGES. Added JETC_DEBUG note.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-150000-DOCSTEPS
-->
