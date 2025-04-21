# Proposed Interface for jetcrun.sh (Jetson Containers)

This document illustrates a proposed user interface and workflow for the `jetcrun.sh` script, which is used to launch Jetson containers with various runtime options.

---

## Start Page

![image](https://github.com/user-attachments/assets/9c1da346-16f1-4cdf-8c27-40b72a0b703a)

The script starts with a clear introduction, guiding the user through the process of selecting and running a container image.

---

## Image Selection Dialog

![image](https://github.com/user-attachments/assets/d82e58e4-5de3-4f93-a2bf-e57020d9e4ed)

The user is presented with a menu of available images (populated from `.env` and previous builds). They can select an image or enter a custom image name.

---

## Runtime Options Dialog

![image](https://github.com/user-attachments/assets/841fdabf-c0d1-495b-b460-552fbfe91df9)

A checklist allows the user to enable or disable runtime options such as:
- X11 forwarding (for GUI applications)
- GPU access (for CUDA-enabled workloads)
- Mounting the workspace directory
- Running as root user

---

## Launching the Container

After confirming their selections, the script constructs the appropriate `docker run` or `jetson-containers run` command, ensuring all options are correctly applied and avoiding duplicate mounts or conflicting settings.

The script also checks if the selected image exists locally, attempts to pull it if not, and provides clear feedback on the process.

---

## Integration with jetson-containers

The script leverages [jetson-containers](https://github.com/dusty-nv/jetson-containers/blob/master/docs/run.md) to ensure proper NVIDIA GPU support and runtime configuration.

---

## Summary

This proposed interface aims to make running Jetson containers as simple and robust as possible, even for users unfamiliar with Docker command-line options.

---

<!--
# File location diagram:
# jetc/                          <- Main project folder
# ├── proposed-app-jetcrun-sh.md <- THIS FILE
# ├── buildx/                    <- Build system and scripts
# └── ...                        <- Other project files
#
# Description: Proposed interactive UI and workflow for jetcrun.sh script, including image selection, runtime options, and integration with jetson-containers.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250422-064000-PRPJ
-->
