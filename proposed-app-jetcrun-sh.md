# Proposed Interface for jetcrun.sh (Jetson Containers)

This document illustrates a proposed user interface and workflow for the `jetcrun.sh` script, which is used to launch Jetson containers with various runtime options.

---

## Start Page

![image](https://github.com/user-attachments/assets/9c1da346-16f1-4cdf-8c27-40b72a0b703a)

The script starts with a clear introduction, guiding the user through the process of selecting and running a container image. This ensures that even new users can confidently launch containers.

---

## Image Selection Dialog

![image](https://github.com/user-attachments/assets/d82e58e4-5de3-4f93-a2bf-e57020d9e4ed)

The user is presented with a menu of available images (populated from `.env` and previous builds). They can select an image or enter a custom image name. This menu makes it easy to reuse previously built images and reduces the risk of typos.

---

## Runtime Options Dialog

![image](https://github.com/user-attachments/assets/841fdabf-c0d1-495b-b460-552fbfe91df9)

A checklist allows the user to enable or disable runtime options such as:
- X11 forwarding (for GUI applications)
- GPU access (for CUDA-enabled workloads)
- Mounting the workspace directory
- Running as root user

These options are essential for customizing the container environment for different use cases.

---

## Launching the Container

After confirming their selections, the script constructs the appropriate `docker run` or `jetson-containers run` command, ensuring all options are correctly applied and avoiding duplicate mounts or conflicting settings.

The script also checks if the selected image exists locally, attempts to pull it if not, and provides clear feedback on the process. This helps prevent runtime errors due to missing images.

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
# COMMIT-TRACKING: UUID-20250422-064000-PRPJ
-->
