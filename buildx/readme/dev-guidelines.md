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
# ├── buildx/                    <- Build system and scripts
# │   └── readme/                <- THIS FILE and related docs
# └── ...                        <- Other project files
#
# Description: Development guidelines for Jetson Container project.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20240805-210000-DEVGUIDE
-->
