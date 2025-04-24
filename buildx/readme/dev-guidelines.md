######################################################################
# THIS FILE CAN BE DELETED
# All relevant content consolidated in /workspaces/jetc/README.md and .github/copilot-instructions.md
# You do NOT need this file anymore.
######################################################################

# JETC Development Guidelines

> **This file expands on the "Development Guidelines" section of the main README.**

---

## Coding Standards

- Follow [copilot-instructions.md](../../.github/copilot-instructions.md)
- Place commit tracking info at the **bottom** of each file
- Use minimal diffs for all code changes

## Modularization

- Each build step is a separate script in `buildx/scripts/`
- Keep functions focused and files small

## Commit Tracking

- Use the same UUID for all files in a logical commit
- See [copilot-instructions.md](../../.github/copilot-instructions.md) for format

## Contributing

- Fork the repo and submit pull requests
- Ensure all scripts run without errors before submitting

---

## More

- [Features & FAQ](features.md)
- [Troubleshooting](troubleshooting.md)

<!--
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── readme/                <- Current directory
# │       └── dev-guidelines.md  <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Marked for deletion - content moved to main README.md and coding standards.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-230000-DOCCONSOL
-->
