# Proposed Interface for jetcrun.sh (Jetson Containers)

> **This document reflects the image selection and runtime options as described in the README ("After the Build: Using Your AI Applications") and the modular build system's `.env` image tracking.**

---

## Start Page

![image](https://github.com/user-attachments/assets/9c1da346-16f1-4cdf-8c27-40b72a0b703a)

The script starts with a clear introduction, guiding the user through the process of selecting and running a container image. This ensures that even new users can confidently launch containers.

---

## Image Selection Dialog (Reflects .env AVAILABLE_IMAGES and LOCAL_DOCKER_IMAGES)

- The script presents a menu of available images, populated from:
  - `AVAILABLE_IMAGES` (built and tracked by build.sh)
  - `LOCAL_DOCKER_IMAGES` (all images found by `docker images`)
  - `DEFAULT_IMAGE_NAME` and `DEFAULT_BASE_IMAGE` (for convenience)
- User can select from the menu or enter a custom image name.
- The selected image is saved back to `.env` for future runs.

---

## Runtime Options Dialog

- User can enable/disable:
  - X11 forwarding
  - GPU access
  - Workspace mount
  - Root user
- Options are saved to `.env` as defaults for next run.

---

## Launching the Container

- The script constructs the appropriate `docker run` or `jetson-containers run` command.
- Checks if the selected image exists locally; attempts to pull if not.
- Provides clear feedback and saves all selections to `.env`.

---

**Note:**  
This workflow matches the modular build and run system described in the README and implemented in `build.sh` and `jetcrun.sh`.

---

## Integration with jetson-containers

The script leverages [jetson-containers](https://github.com/dusty-nv/jetson-containers/blob/master/docs/run.md) to ensure proper NVIDIA GPU support and runtime configuration. This integration guarantees compatibility with Jetson hardware and NVIDIA drivers.

---

## Summary

This proposed interface aims to make running Jetson containers as simple and robust as possible, even for users unfamiliar with Docker command-line options. The interactive menus, persistent defaults, and automatic image tracking ensure a smooth and user-friendly experience.

---

<!--
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Main project README
# ├── proposed-app-build-sh.md   <- Proposed build.sh UI/workflow
# ├── proposed-app-jetcrun-sh.md <- THIS FILE
# ├── .env                       <- Environment/config file
# ├── .gitattributes
# ├── .gitignore
# ├── .github/                   <- Copilot and git integration
# │   ├── copilot-instructions.md
# │   ├── git-template-setup.md
# │   ├── install-hooks.sh
# │   ├── pre-commit-hook.sh
# │   ├── prepare-commit-msg-hook.sh
# │   ├── setup-git-template.sh
# │   └── vs-code-snippets-guide.md
# ├── buildx/                    <- Build system and scripts
# │   ├── build/                 <- Build stages and Dockerfiles
# │   ├── build.sh               <- Main build orchestrator
# │   ├── jetcrun.sh             <- Container run utility
# │   ├── scripts/               <- Modular build scripts
# │   │   ├── build_ui.sh
# │   │   ├── commit_tracking.sh
# │   │   ├── copilot-must-follow.md
# │   │   ├── docker_helpers.sh
# │   │   ├── logging.sh
# │   │   ├── utils.sh
# │   │   └── verification.sh
# │   └── logs/                  <- Build logs
# └── ...                        <- Other project files
#
# Description: Proposed interactive UI and workflow for jetcrun.sh script, including image selection, runtime options, and integration with jetson-containers.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250422-083100-PRPJ
-->
