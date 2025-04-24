######################################################################
# THIS FILE CAN BE DELETED
# All relevant content consolidated in /workspaces/jetc/README.md
# You do NOT need this file anymore.
######################################################################

# JETC Troubleshooting

> **This file expands on the "Troubleshooting" section of the main README.**

---

## Common Issues

### Build Fails for a Stage

- Check logs in `buildx/logs/`
- Fix Dockerfile or dependencies, then re-run `./build.sh`
- You can skip failed stages and continue with successful ones

### Out of Disk or Memory

- Clean up Docker images:  
  `docker system prune -a`
- Increase swap space if needed

### Container Won't Start

- Check if the image exists locally:  
  `docker images`
- Try pulling the image:  
  `docker pull <image>`

### .env Not Updated

- Ensure scripts have write permission to `buildx/.env`
- Re-run the build script

---

## More

- [Development guidelines](dev-guidelines.md)
- [Verification system](verification.md)

<!--
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── readme/                <- Current directory
# │       └── troubleshooting.md <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Marked for deletion - content moved to main README.md
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-230000-DOCCONSOL
-->
