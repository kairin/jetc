<!--
# COMMIT-TRACKING: UUID-20250424-230000-DOCCONSOL
# Description: Main README. Consolidated documentation from various files. Added structure, features, usage, workflow, troubleshooting.
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
# │   └── readme/                <- Extended documentation
# ├── .github/                   <- Copilot and git integration
# │   └── copilot-instructions.md<- Coding standards and commit tracking
# └── ...                        <- Other project files
-->
# Jetson Container Toolkit (jetc)

A collection of scripts and Dockerfiles designed to simplify building and running customized container images for NVIDIA Jetson devices, focusing on AI/ML development environments.

## Overview

This toolkit provides a modular and interactive approach to building complex Docker images layer by layer. It allows users to select specific components (like PyTorch, TensorFlow, OpenCV, etc.) and build options through a user-friendly interface (using `dialog` or basic text prompts).

## Features

*   **Modular Build System:** Build images incrementally by selecting specific numbered folders in `buildx/build/`. Each folder represents a component or configuration step.
*   **Interactive UI:** Uses `dialog` (if installed) or text prompts to guide users through build options, base image selection, and component choices.
*   **Configuration Management:** Uses a central `.env` file (`buildx/.env`) to store Docker Hub credentials, repository prefix, default base images, and last used settings.
*   **Buildx Integration:** Leverages Docker Buildx for multi-platform builds (though primarily focused on `linux/arm64` for Jetson) and optimized builder instances.
*   **Caching & Squashing:** Options to enable/disable build cache and experimental layer squashing.
*   **Local Builds:** Option to build images locally (`--load`) without pushing to a registry.
*   **Verification:** Includes scripts to verify installed components within the built container (`verification.sh`).
*   **Runtime Utility (`jetcrun.sh`):** An interactive script to easily run containers based on built images, managing common options like GPU access, X11 forwarding, and workspace mounting.
*   **Logging:** Comprehensive logging of the build process, including main output, errors, and a summary markdown file.
*   **Automated Commit Tracking:** Integrates with Git hooks (`prepare-commit-msg`, `pre-commit`) to automatically manage `COMMIT-TRACKING:` footers in modified files.

## Project Structure

```
jetc/
├── .git/                     # Git directory (hooks installed here)
├── .github/                  # GitHub Actions, Issue Templates, Copilot instructions, Git hooks source
│   ├── copilot-instructions.md # Canonical coding standards for Copilot
│   ├── INSTRUCTIONS.md       # Summary of standards and enforcement
│   ├── install-hooks.sh      # Script to install Git hooks locally
│   ├── pre-commit-hook.sh    # Hook source: Updates footers before commit
│   ├── prepare-commit-msg-hook.sh # Hook source: Prepends UUID to commit message
│   └── setup-git-template.sh # Script to setup Git template dir with hooks
├── .gitignore                # Files ignored by Git
├── .gitattributes            # Git attributes (e.g., for git-crypt)
├── LICENSE                   # Project license file
├── README.md                 # This file: Main project documentation
├── buildx/                   # Core build system directory
│   ├── .env                  # **IMPORTANT**: Stores Docker creds, defaults, last used settings
│   ├── build/                # Contains subdirectories for build stages/components
│   │   ├── 01-base/          # Example base setup stage
│   │   └── ...               # Other numbered component folders (e.g., 02-pytorch, 03-opencv)
│   ├── build.sh              # **Main build script** - Run this to build images
│   ├── jetcrun.sh            # **Main run script** - Run this to launch containers
│   ├── logs/                 # Build logs are stored here
│   └── scripts/              # Helper scripts used by build.sh and jetcrun.sh
│       ├── build_stages.sh   # Logic for building selected stages
│       ├── build_tagging.sh  # Logic for tagging images
│       ├── build_ui.sh       # Main UI interaction logic (calls dialog/basic)
│       ├── commit_tracking.sh# Functions for UUID/footer management
│       ├── dialog_ui.sh      # Dialog-based UI functions
│       ├── docker_helpers.sh # Docker command wrappers (build, pull, tag)
│       ├── env_helpers.sh    # .env file reading/writing functions
│       ├── logging.sh        # Build logging functions
│       ├── post_build_menu.sh# Menu shown after successful build
│       ├── utils.sh          # General utility functions (datetime, dialog check)
│       └── verification.sh   # Functions to verify container contents
└── ...                       # Other project files/directories (e.g., specific app code)
```

## Prerequisites

*   Docker & Docker Buildx installed and running.
*   Git installed.
*   (Optional but Recommended) `dialog` package for a better UI (`sudo apt install dialog`).
*   An NVIDIA Jetson device or an environment capable of running/building ARM64 containers.

## Setup

1.  **Clone the Repository:**
    ```bash
    git clone <repository_url> jetc
    cd jetc
    ```
2.  **Install Git Hooks:** (Run once)
    ```bash
    ./.github/install-hooks.sh
    ```
    This copies the necessary hooks (`prepare-commit-msg`, `pre-commit`) to your local `.git/hooks` directory to enable automated commit tracking.
3.  **Configure `.env`:**
    *   Navigate to the `buildx` directory: `cd buildx`
    *   Copy the example if it exists, or create `.env`.
    *   Edit `buildx/.env` and set at least `DOCKER_USERNAME` and `DOCKER_REPO_PREFIX`. The scripts will prompt if these are missing.
    ```bash
    # Example buildx/.env
    DOCKER_REGISTRY= # Optional: leave empty for Docker Hub
    DOCKER_USERNAME=your_dockerhub_username
    DOCKER_REPO_PREFIX=myjetson_images
    # Other defaults will be added/updated by the scripts
    ```

## Usage

### Building Images (`build.sh`)

1.  Navigate to the `buildx` directory: `cd /path/to/jetc/buildx`
2.  Run the build script: `./build.sh`
3.  Follow the interactive prompts:
    *   Confirm/edit Docker registry, username, and prefix.
    *   Select build stages (numbered folders in `buildx/build/`).
    *   Choose build options (cache, squash, local build).
    *   Select the base image for the first stage (use default, pull default, specify custom).
    *   Confirm the build summary.
4.  The script will build the selected stages sequentially, tagging each intermediate image. The final image tag will be based on the last successful stage.
5.  After the build, a post-build menu allows you to run verification checks or start a shell in the final container.

### Running Containers (`jetcrun.sh`)

1.  Navigate to the `buildx` directory: `cd /path/to/jetc/buildx`
2.  Run the container launch script: `./jetcrun.sh`
3.  Follow the interactive prompts:
    *   Select the image to run from a list of previously built/used images or enter a custom tag.
    *   Choose runtime options (X11 forwarding, GPU access, workspace mount, run as root).
    *   Confirm the `docker run` command.
4.  The script launches the container with the selected options.

## Development Workflow

### Adding New Components

1.  Create a new numbered directory in `buildx/build/` (e.g., `buildx/build/05-my-component`). The numbering determines the build order.
2.  Add a `Dockerfile` inside the new directory.
    *   Use `ARG BASE_IMAGE` and `FROM $BASE_IMAGE` to inherit from the previous stage.
    *   Add instructions to install your component.
    *   Include the standard commit tracking footer at the bottom.
3.  (Optional) Add a `.buildargs` file in the component directory if you need to pass specific build arguments during that stage.
4.  Run `./buildx/build.sh` and select your new stage along with any prerequisites.

### Commit Tracking (Automated via Git Hooks)

This project uses an automated commit tracking system integrated with Git hooks to ensure consistency and traceability.

1.  **Runtime UUID Generation:** When you run key scripts like `buildx/build.sh` or `buildx/jetcrun.sh`, they generate a unique UUID based on the current system time (e.g., `UUID-20250424-210000-BLDX`). This UUID is temporarily stored in `.git/LAST_RUNTIME_UUID`.
2.  **Commit Message Preparation (`prepare-commit-msg` hook):** When you run `git commit`, this hook activates:
    *   It checks for the `.git/LAST_RUNTIME_UUID` file.
    *   If a valid runtime UUID is found, it uses that UUID and deletes the temporary file.
    *   If no valid runtime UUID is found (e.g., for commits not related to running `build.sh` or `jetcrun.sh`), it generates a new UUID based on the *commit* time (e.g., `UUID-20250424-220000-COMM`).
    *   It prepends the chosen UUID to your commit message (e.g., `UUID-20250424-220000-COMM: Your commit summary`). You only need to write the summary part.
3.  **File Footer Update (`pre-commit` hook):** Before the commit is finalized, this hook runs:
    *   It reads the UUID from the commit message prepared in the previous step.
    *   It finds all staged files (`.sh`, `.md`, `Dockerfile`, etc.) that should contain a tracking footer.
    *   It updates the `COMMIT-TRACKING:` line in the footer of each staged file with the single UUID from the commit message.
    *   It automatically re-stages these modified files (`git add`).

**Result:** All files modified within a single commit will share the same `COMMIT-TRACKING:` UUID, which is also present in the commit message itself, linking the code changes directly to the commit record. The UUID reflects the runtime if triggered by `build.sh` or `jetcrun.sh`, otherwise it reflects the commit time.

**Setup:** Ensure you have run `./.github/install-hooks.sh` once to copy the hooks into your local `.git/hooks` directory.

### Coding Standards

Refer to `.github/copilot-instructions.md` for detailed coding standards, minimal diff rules, and footer requirements. Key points:
*   Footers go at the **bottom** of the file.
*   Use the automated Git hooks for UUID management.
*   Follow minimal diff rules for changes.

## Troubleshooting

*   **`.env` File:** Ensure `buildx/.env` exists and contains valid `DOCKER_USERNAME` and `DOCKER_REPO_PREFIX`. The scripts will prompt if missing, but defaults might not be ideal. Check permissions if scripts fail to read/write.
*   **Buildx Builder:** The scripts attempt to create and use a `jetson-builder` buildx instance. If you encounter errors like `ERROR: docker-container driver requires remote context or docker server running with experimental mode`, ensure Docker Desktop or your Docker daemon is running correctly and buildx is set up. You might need to manually run `docker buildx create --name jetson-builder --use` or troubleshoot your Docker installation.
*   **Dialog Errors:** If `dialog` isn't installed, the scripts should fall back to basic text prompts. If dialog installation fails or prompts don't appear, check permissions and package manager status (`sudo apt update && sudo apt install dialog`).
*   **Pull Errors (`jetcrun.sh`):** If `jetcrun.sh` fails to find an image locally, it currently attempts a fallback pull by appending `-py3` to the image name (e.g., trying `my/image:tag-py3` if `my/image:tag` isn't found). This is a heuristic and might not match the actual tag in the registry. If the automatic pull fails, verify the correct image tag and pull it manually using `docker pull <correct-image-tag>`.
*   **Pull Errors (Build):** If pulling base images during the build process fails, check your network connection, registry URL (if not Docker Hub), and authentication (`docker login`). Ensure the base image tag specified exists for the `linux/arm64` platform.
*   **Git Hook Errors:** If commits fail with messages related to UUIDs or footers, ensure the hooks were installed correctly (`./.github/install-hooks.sh`) and have execute permissions (`chmod +x .git/hooks/*`). Check the error messages from the hooks for specific issues (e.g., missing `commit_tracking.sh`, invalid UUID format).
*   **Debug Output:** For more detailed script output, set the `JETC_DEBUG` environment variable:
    ```bash
    export JETC_DEBUG=true
    ./buildx/build.sh
    # or
    JETC_DEBUG=1 ./buildx/jetcrun.sh
    ```

## License

See the [LICENSE](LICENSE) file for details.

<!--
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Main README. Consolidated documentation from various files. Added structure, features, usage, workflow, troubleshooting.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-230000-DOCCONSOL
-->
