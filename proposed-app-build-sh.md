######################################################################
# THIS FILE CAN BE DELETED
# All relevant content consolidated in /workspaces/jetc/README.md
# You do NOT need this file anymore.
######################################################################

# Proposed Interface for build.sh (Jetson Containers)

> **This document reflects the modular build steps as described in the README ("Modular Build Steps (Reflected in build.sh and scripts/)") and the actual build.sh workflow.**

---

## Modular Build Steps (as in README and `build.sh`)

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

<!--
# File location diagram:
# jetc/                          <- Main project folder
# ├── proposed-app-build-sh.md   <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Marked for deletion - content moved to main README.md
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-230000-DOCCONSOL
-->
