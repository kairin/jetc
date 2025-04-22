# JETC Repository Structure

> **This file expands on the "Repository Structure" section of the main README.**

---

## Root Structure

```
jetc/
├── README.md
├── buildx/
│   ├── build/
│   ├── build.sh
│   ├── jetcrun.sh
│   ├── scripts/
│   └── readme/
│       ├── features.md
│       ├── structure.md
│       ├── troubleshooting.md
│       ├── dev-guidelines.md
│       ├── verification.md
│       ├── ai-components.md
│       ├── proposed-app-build-sh.md
│       └── proposed-app-jetcrun-sh.md
├── .github/
└── ...
```

---

## Modular Script Structure

| Script | Description |
|--------|-------------|
| build_env_setup.sh | Setup environment variables and load `.env` |
| build_builder.sh | Ensure buildx builder is ready |
| build_prefs.sh | Interactive user preferences dialog |
| build_order.sh | Determine build order and selected folders |
| build_stages.sh | Build selected numbered and other directories |
| build_tagging.sh | Tag and push the final image |
| build_post.sh | Post-build menu/options |
| build_verify.sh | Final verification and update `.env` |
| build_ui.sh | UI functions for interactive build process |
| docker_helpers.sh | Docker build, tag, push, pull, and verification helpers |
| utils.sh | General utility functions |
| logging.sh | Logging functions |
| verification.sh | Container verification functions |
| commit_tracking.sh | Commit tracking UUID and footer helpers |

---

## See Also

- [proposed-app-build-sh.md](proposed-app-build-sh.md)
- [proposed-app-jetcrun-sh.md](proposed-app-jetcrun-sh.md)
- [features.md](features.md)
- [troubleshooting.md](troubleshooting.md)
- [dev-guidelines.md](dev-guidelines.md)
- [verification.md](verification.md)
- [ai-components.md](ai-components.md)

<!--
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Build system and scripts
# │   └── readme/                <- THIS FILE and related docs
# └── ...                        <- Other project files
#
# Description: Expanded repository structure and modular script roles for Jetson Container project.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20240805-210000-STRUCT
-->
