######################################################################
# THIS FILE CAN BE DELETED
# All relevant content consolidated in /workspaces/jetc/README.md
# You do NOT need this file anymore.
######################################################################

# JETC Features & FAQ

> **This file expands on the "Features" section of the main README.**

---

## Key Features

- Interactive build and run scripts with persistent `.env` config
- Modular, maintainable build steps
- Automatic image tracking and verification
- Easy container selection and runtime options
- Robust logging and error summaries
- Support for custom and default base images
- Compatibility with NVIDIA Jetson hardware and [jetson-containers](https://github.com/dusty-nv/jetson-containers)

---

## Frequently Asked Questions

**Q: Do I need to edit `.env` manually?**  
A: No. The scripts will prompt you for all required info and update `.env` automatically.

**Q: Can I select which build stages to run?**  
A: Yes. The build script presents a checklist of available stages.

**Q: How are images tracked?**  
A: All successfully built images are added to `AVAILABLE_IMAGES` in `.env`. All local images are also tracked in `LOCAL_DOCKER_IMAGES`.

**Q: Can I use my own base image?**  
A: Yes. You can specify a custom image during the build dialog.

**Q: What if a build step fails?**  
A: The build continues with the next stage. See logs for details.

**Q: How do I run a container after building?**  
A: Use `./jetcrun.sh` for an interactive menu of available images and runtime options.

---

## More

- [Troubleshooting](troubleshooting.md)
- [Development guidelines](dev-guidelines.md)
- [Verification system](verification.md)
- [AI components](ai-components.md)

<!--
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── readme/                <- Current directory
# │       └── features.md        <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Marked for deletion - content moved to main README.md
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-230000-DOCCONSOL
-->
