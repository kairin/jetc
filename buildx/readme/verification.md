######################################################################
# THIS FILE CAN BE DELETED
# All relevant content consolidated in /workspaces/jetc/README.md
# You do NOT need this file anymore.
######################################################################

# JETC Container Verification System

> **This file expands on the "Container Verification System" section of the main README.**

---

## Verification Options

- **Interactive Shell**: Launch a shell in the container
- **Quick Verification**: Check common tools and ML/AI frameworks
- **Full Verification**: List all installed packages
- **App Listing**: List all installed applications

## How It Works

- Verification functions are in `buildx/scripts/verification.sh`
- Run via post-build menu or manually

## Usage

```bash
./scripts/verification.sh run_checks quick
./scripts/verification.sh run_checks all
```

Or via `jetcrun.sh` post-run menu.

---

## More

- [Features & FAQ](features.md)
- [Development guidelines](dev-guidelines.md)

<!--
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── readme/                <- Current directory
# │       └── verification.md    <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Marked for deletion - content moved to main README.md
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-230000-DOCCONSOL
-->
