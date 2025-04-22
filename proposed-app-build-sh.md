# Proposed Interface for build.sh (Jetson Containers)

> **This document reflects the modular build steps as described in the README ("Modular Build Steps (Reflected in build.sh and scripts/)") and the actual build.sh workflow.**

---

## Modular Build Steps (as in README and build.sh)

1. **Environment Setup and .env Loading**  
   - Script: `buildx/scripts/build_env_setup.sh`  
   - Initializes build variables and loads `.env` for defaults and image tracking.

2. **Builder Setup**  
   - Script: `buildx/scripts/build_builder.sh`  
   - Ensures the buildx builder is ready for multi-arch builds.

3. **User Preferences Dialog**  
   - Script: `buildx/scripts/build_prefs.sh`  
   - Interactive dialog (or text prompts) for Docker info, build options, base image, and confirmation.

4. **Build Order Determination**  
   - Script: `buildx/scripts/build_order.sh`  
   - Determines which build stages/folders to process based on user selection.

5. **Building Stages**  
   - Script: `buildx/scripts/build_stages.sh`  
   - Builds selected numbered and other directories in order, updating `.env` with successful tags.

6. **Tagging and Pushing the Final Image**  
   - Script: `buildx/scripts/build_tagging.sh`  
   - Tags the last successful image with a timestamp and pushes it if required.

7. **Post-Build Options**  
   - Script: `buildx/scripts/build_post.sh`  
   - Presents menu to run, verify, or skip actions on the final image.

8. **Final Verification and .env Update**  
   - Script: `buildx/scripts/build_verify.sh`  
   - Verifies all built images exist locally and updates `.env` with the latest successful tag.

---

## Interactive Dialog Workflow (Step 3: build_prefs.sh)

### Step 1: Build Stage Selection  
- User selects which build stages to include (from available folders).

### Step 2: Build Options  
- User configures cache, squash, local build, and builder options.

### Step 3: Base Image Selection  
- User chooses to use default, pull default, or specify a custom base image.

### Step 4: Confirmation  
- User reviews all settings before starting the build.

---

## Automated Build Process (Steps 4–8)

- Sequentially builds selected stages, passing the correct base image to each.
- Tracks successful builds and tags in `.env`.
- Updates `.env` with available images and the latest successful tag.
- Provides detailed logging and error summaries.
- Offers post-build options and final verification.

---

**Note:**  
This document is kept in sync with the modular build steps and script structure described in the README and implemented in `build.sh`.

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
