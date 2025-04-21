# Proposed Interface for build.sh (Jetson Containers)

This document illustrates a proposed user interface and workflow for the `build.sh` script in the Jetson container build system. The goal is to provide a clear, interactive, and user-friendly experience for building complex multi-stage Docker images on Jetson devices.

---

## Start Page

![Screenshot from 2025-04-20 14-54-05](https://github.com/user-attachments/assets/aa9080d3-a6c9-441b-9a7f-44649ad5d3f8)

The build process begins with a welcoming start page, introducing the user to the Jetson container build system and summarizing the available options.

---

## Interactive Dialog Workflow

### Step 1: Build Stage Selection

![image](https://github.com/user-attachments/assets/af3765f6-3d56-4f9a-9b89-9f4f610377b9)

The user is presented with a checklist of available build stages (numbered directories). They can select which stages to include in the build process, allowing for partial or full builds as needed.

### Step 2: Build Options

![image](https://github.com/user-attachments/assets/9609709d-f49e-45cd-b027-895c1c7c83f4)

A dialog allows the user to configure build options such as:
- Use of build cache (for faster builds)
- Squashing image layers (to reduce final image size)
- Local build only (skip push/pull to registry)
- Use of the optimized Jetson builder

### Step 3: Base Image Selection

![image](https://github.com/user-attachments/assets/44a9b88b-143a-40c4-ae2b-cd7d1a302525)

The user can choose to:
- Use the default base image (from `.env` or previous build)
- Pull the default base image from the registry
- Specify a custom base image (with validation and pull attempt)

### Step 4: Confirmation

A summary dialog displays all selected options and stages, allowing the user to confirm or go back and edit their choices.

---

## Pulling the Base Image

![image](https://github.com/user-attachments/assets/55af5c86-222f-415d-aea8-b090dd4d9833)

If the user chooses to pull a base image (default or custom), the script attempts to pull it and provides feedback on success or failure.

---

## Automated Build Process

Once confirmed, the script orchestrates the build process:
- Sequentially builds selected stages, passing the correct base image to each
- Tracks successful builds and tags
- Updates `.env` with available images and the latest successful tag
- Provides detailed logging and error summaries

---

## Post-Build Options

After the build completes, the user is presented with options to:
- Start a shell in the final image
- Run quick or full verification of installed applications
- List all installed packages
- Skip further actions

---

## Summary

This proposed interface aims to make the Jetson container build process accessible, robust, and transparent, even for users new to Docker or Jetson development.

---

<!--
# File location diagram:
# jetc/                          <- Main project folder
# ├── proposed-app-build-sh.md   <- THIS FILE
# ├── buildx/                    <- Build system and scripts
# └── ...                        <- Other project files
#
# Description: Proposed interactive UI and workflow for build.sh script, including dialogs, options, and user experience.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250422-064000-PRPB
-->
