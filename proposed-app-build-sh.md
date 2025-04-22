# Proposed Interface for build.sh (Jetson Containers)

This document illustrates a proposed user interface and workflow for the `build.sh` script in the Jetson container build system. The goal is to provide a clear, interactive, and user-friendly experience for building complex multi-stage Docker images on Jetson devices.

---

## Start Page

![Screenshot from 2025-04-20 14-54-05](https://github.com/user-attachments/assets/aa9080d3-a6c9-441b-9a7f-44649ad5d3f8)

The build process begins with a welcoming start page, introducing the user to the Jetson container build system and summarizing the available options. This page helps orient new users and provides a clear entry point for the build workflow.

---

## Interactive Dialog Workflow

### Step 1: Build Stage Selection

![image](https://github.com/user-attachments/assets/af3765f6-3d56-4f9a-9b89-9f4f610377b9)

The user is presented with a checklist of available build stages (numbered directories). They can select which stages to include in the build process, allowing for partial or full builds as needed. This enables advanced users to skip unnecessary stages or resume from a failed step.

### Step 2: Build Options

![image](https://github.com/user-attachments/assets/9609709d-f49e-45cd-b027-895c1c7c83f4)

A dialog allows the user to configure build options such as:
- Use of build cache (for faster builds)
- Squashing image layers (to reduce final image size)
- Local build only (skip push/pull to registry)
- Use of the optimized Jetson builder

These options provide flexibility for both development and production builds.

### Step 3: Base Image Selection

![image](https://github.com/user-attachments/assets/44a9b88b-143a-40c4-ae2b-cd7d1a302525)

The user can choose to:
- Use the default base image (from `.env` or previous build)
- Pull the default base image from the registry
- Specify a custom base image (with validation and pull attempt)

This ensures that the build always starts from a known, validated base image.

### Step 4: Confirmation

A summary dialog displays all selected options and stages, allowing the user to confirm or go back and edit their choices. This step helps prevent mistakes and ensures the user is aware of the build configuration.

---

## Pulling the Base Image

![image](https://github.com/user-attachments/assets/55af5c86-222f-415d-aea8-b090dd4d9833)

If the user chooses to pull a base image (default or custom), the script attempts to pull it and provides feedback on success or failure. This step ensures that the build will not fail later due to missing images.

---

## Automated Build Process

Once confirmed, the script orchestrates the build process:
- Sequentially builds selected stages, passing the correct base image to each
- Tracks successful builds and tags
- Updates `.env` with available images and the latest successful tag
- Provides detailed logging and error summaries

The build process is robust and continues even if some stages fail, allowing for partial success and easy recovery.

---

## Post-Build Options

After the build completes, the user is presented with options to:
- Start a shell in the final image
- Run quick or full verification of installed applications
- List all installed packages
- Skip further actions

These options make it easy to verify and use the built images immediately.

---

## Summary

This proposed interface aims to make the Jetson container build process accessible, robust, and transparent, even for users new to Docker or Jetson development. The interactive dialogs, clear feedback, and automated tracking of built images ensure a smooth experience from start to finish.

---

<!--
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Main project README
# ├── proposed-app-build-sh.md   <- THIS FILE
# ├── proposed-app-jetcrun-sh.md <- Proposed jetcrun.sh UI/workflow
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
# Description: Proposed interactive UI and workflow for build.sh script, including dialogs, options, and user experience.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250422-083100-PRPB
-->
