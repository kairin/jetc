# JETC: A Modular Build System for Jetson Containers

[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)

This project provides a lean, modular, and robust build system for creating Docker containers tailored for NVIDIA Jetson platforms, leveraging the power of `docker buildx`.

## Table of Contents

*   [Core Philosophy & Acknowledgment](#core-philosophy--acknowledgment)
*   [Quick Start](#quick-start)
*   [Build System Overview](#build-system-overview)
*   [Running Containers](#running-containers)
*   [Verification](#verification)
*   [Documentation](#documentation)
*   [License](#license)

## Core Philosophy & Acknowledgment

**Philosophy:** JETC prioritizes a **lean, modular, thoughtfully implemented, and thoroughly tested build system**. Our focus is on providing a reliable and maintainable way to construct Jetson containers, rather than duplicating the container contents themselves. We emphasize clear script interfaces, proper environment variable management, and interactive user guidance.

> **IMPORTANT ACKNOWLEDGMENT**: This project heavily utilizes and builds upon the foundational work from **[dusty-nv/jetson-containers](https://github.com/dusty-nv/jetson-containers)**. The container configurations, application setups, Dockerfile contents, and core AI component integrations originate from that repository. We are immensely grateful to **dusty-nv and the jetson-containers contributors** for their significant contributions to the Jetson ecosystem. JETC's primary contribution is the **build system architecture** surrounding these components, utilizing `docker buildx` for multi-stage, potentially multi-platform builds.

## Quick Start

1.  **Clone:**
    ```bash
    git clone https://github.com/your-username/jetc.git # Replace with actual repo URL
    cd jetc
    ```
2.  **Configure:**
    *   Copy or rename `buildx/.env.example` to `buildx/.env`.
    *   Edit `buildx/.env` to set your `DOCKER_USERNAME` and `DOCKER_REPO_PREFIX`. Other variables like `DEFAULT_BASE_IMAGE` can also be customized.
3.  **Build:**
    ```bash
    cd buildx
    ./build.sh
    ```
    *   Follow the interactive prompts (Dialog or text-based) to select build stages, options (cache, push/load), and confirm the base image.
4.  **Run:**
    ```bash
    ./jetcrun.sh
    ```
    *   Select the desired image and runtime options (GPU, X11, Workspace, User) via the interactive menu.

## Build System Overview

The core of JETC resides in the `buildx/` directory:

*   **`build/`**: Contains subdirectories, each representing a modular build stage (e.g., `01-python`, `02-pytorch`). Each stage typically has a `Dockerfile` and optional `.buildargs`. The numerical prefix helps define a default build order.
*   **`scripts/`**: Houses modular helper scripts for various functions:
    *   `interactive_ui.sh`: Manages user interaction (Dialog/text) for build and run preferences.
    *   `docker_helpers.sh`: Provides functions for building, tagging, pulling, and running containers.
    *   `env_helpers.sh`: Handles loading, getting, and setting variables in the `.env` file.
    *   `build_stages.sh`: Orchestrates the building of selected stages in order.
    *   `verification.sh`: Contains logic for verifying container contents post-build.
    *   `utils.sh`, `logging.sh`, etc.: Provide common utilities.
    *   These scripts are designed for clarity, using specific functions for distinct tasks and managing environment variables carefully.
*   **`build.sh`**: The main build orchestrator. It sources necessary scripts, presents the build configuration UI (via `interactive_ui.sh`), determines the build order, and executes the selected stages using `build_stages.sh`.
*   **`jetcrun.sh`**: A utility to easily run the built containers. It presents an interactive menu (via `interactive_ui.sh`) to select an image (from those listed in `.env`) and configure common runtime options like GPU access, X11 forwarding, workspace mounting, and user selection.
*   **`.env`**: Stores user-specific configuration like Docker username, repository prefix, default base image, and the list of available built images for `jetcrun.sh`.

This structure promotes modularity, allowing stages to be added, removed, or modified independently. The build process chains stages together, using the output image of one stage as the base for the next.

## Running Containers

Use the `jetcrun.sh` script for an interactive way to launch your built containers:

```bash
cd buildx
./jetcrun.sh
```

The script will:
1.  Read the `AVAILABLE_IMAGES` list from `.env`.
2.  Present a menu to choose an image or enter a custom one.
3.  Offer toggles for common runtime options (GPU, X11, Workspace Mount, Run as Root).
4.  Construct and execute the `docker run` command based on your selections.

Default run options can be configured in `.env`.

## Verification

After a successful build, the `build.sh` script offers post-build actions, including verification:

*   **Quick Verification:** Checks for the presence and basic functionality of common tools and libraries expected in the final image.
*   **Full Verification:** Performs a more comprehensive check (details TBD).
*   **List Apps:** Attempts to list installed packages.

These checks are implemented in `scripts/verification.sh` and called via `scripts/interactive_ui.sh`.

## Documentation

For more detailed information, please refer to the following (Note: These files may be under development):

*   `docs/BUILD_OPTIONS.md`: Detailed explanation of build flags and options.
*   `docs/BUILD_STAGES.md`: List and description of available build stages in `buildx/build/`.
*   `docs/TROUBLESHOOTING.md`: Common issues and solutions.
*   `docs/CONTRIBUTING.md`: Guidelines for contributing to the build system.
*   `.github/copilot-instructions.md`: Coding standards and commit requirements.

## License

[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)

The modifications and build system architecture introduced by the JETC project are released under the **Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0) License**. This license is chosen to ensure the work remains open source, prevents commercial use, and requires derivatives to be shared under the same terms.

Please note that the underlying container contents, Dockerfiles, and application setups sourced from `dusty-nv/jetson-containers` retain their original licenses. Consult the `dusty-nv/jetson-containers` repository for details on the licenses applicable to those components.

<!--
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- THIS FILE
# ├── .github/                   <- GitHub integration and standards
# ├── buildx/                    <- Core build system
# │   ├── build/                 <- Modular build stages
# │   ├── scripts/               <- Helper scripts
# │   ├── build.sh               <- Main build script
# │   ├── jetcrun.sh             <- Container run utility
# │   └── .env                   <- User configuration
# └── ...                        <- Other project files
#
# Description: Main README for the JETC project, focusing on the modular build system. Updated license to CC BY-NC-SA 4.0.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20240806-111500-README
-->
