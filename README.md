<!--
# COMMIT-TRACKING: UUID-20250422-083100-RDME
# Description: Updated README to reflect .env usage for AVAILABLE_IMAGES.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- THIS FILE
# ├── buildx/                    <- Build system and scripts
# │   ├── build/                 <- Build stages and Dockerfiles
# │   ├── build.sh               <- Main build orchestrator
# │   ├── jetcrun.sh             <- Container run utility
# │   └── scripts/               <- Modular build scripts
# ├── .github/                   <- Copilot and git integration
# │   └── copilot-instructions.md<- Coding standards and commit tracking
# └── ...                        <- Other project files
-->
# JETC: Jetson Containers for Targeted Use Cases

> **Based on [dusty-nv/jetson-containers](https://github.com/dusty-nv/jetson-containers).**  
> This repo focuses on modular, interactive, and robust Docker buildx-based container building for NVIDIA Jetson devices.

---

## Quick Start

1. **Clone and enter the repo**
   ```bash
   git clone https://github.com/kairin/jetc.git
   cd jetc/buildx
   ```

2. **(Optional) Run pre-run check**
   ```bash
   ./scripts/pre-run.sh
   ```

3. **(Optional) Create `.env` for defaults**
   ```bash
   cp .env.example .env
   # Edit as needed
   ```

4. **Run the build script**
   ```bash
   ./build.sh
   ```

5. **Run a container**
   ```bash
   ./jetcrun.sh
   ```

---

## Modular Build Steps

The build process is modular and interactive:

| Step | Script | Description |
|------|--------|-------------|
| 1 | `build_env_setup.sh` | Setup environment variables and load `.env` |
| 2 | `build_builder.sh` | Ensure buildx builder is ready |
| 3 | `build_prefs.sh` | Interactive user preferences dialog |
| 4 | `build_order.sh` | Determine build order and selected folders |
| 5 | `build_stages.sh` | Build selected numbered and other directories |
| 6 | `build_tagging.sh` | Tag and push the final image |
| 7 | `build_post.sh` | Post-build menu/options |
| 8 | `build_verify.sh` | Final verification and update `.env` |

See [proposed-app-build-sh.md](buildx/readme/proposed-app-build-sh.md) for full details.

---

## Features

- Interactive build and run scripts with persistent `.env` config
- Modular, maintainable build steps
- Automatic image tracking and verification
- Easy container selection and runtime options
- [More details...](buildx/readme/features.md)

---

## Repository Structure

See [structure.md](buildx/readme/structure.md) for a full breakdown.

---

## Usage Examples

- [Build process walkthrough](buildx/readme/proposed-app-build-sh.md)
- [Running containers with jetcrun.sh](buildx/readme/proposed-app-jetcrun-sh.md)

---

## Troubleshooting

### .env Variable Errors

- If you see errors like `No such file or directory` with an image name, check your `.env` file for invalid lines.
- Only lines of the form `VAR=value` are allowed. Do not add arbitrary text or commands.
- Never source or execute the value of a variable from `.env`.

### Docker buildx Builder

- The build system requires a working Docker buildx builder named `jetson-builder`.
- If you see errors about buildx or builder not found, run:
  ```bash
  docker buildx create --name jetson-builder --driver docker-container --use
  docker buildx start jetson-builder
  ```
- The build script will attempt to create and start the builder automatically if needed.

---

## More Information

- [Features & FAQ](buildx/readme/features.md)
- [Troubleshooting](buildx/readme/troubleshooting.md)
- [Development guidelines](buildx/readme/dev-guidelines.md)
- [Container verification system](buildx/readme/verification.md)
- [Generative AI components](buildx/readme/ai-components.md)

---

## License

This project is licensed under the Creative Commons Attribution-NonCommercial 4.0 International License (CC BY-NC 4.0). This means that you are free to use, share, and adapt the project for non-commercial purposes. Commercial use and monetization are explicitly prohibited. See the LICENSE file for full details.

<!--
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- THIS FILE
# ├── buildx/                    <- Build system and scripts
# │   ├── build/                 <- Build stages and Dockerfiles
# │   ├── build.sh               <- Main build orchestrator
# │   ├── jetcrun.sh             <- Container run utility
# │   └── scripts/               <- Modular build scripts
# │   └── readme/                <- Extended documentation
# ├── .github/                   <- Copilot and git integration
# │   └── copilot-instructions.md<- Coding standards and commit tracking
# └── ...                        <- Other project files
#
# Description: Short main README for Jetson Container project, with links to modular docs.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20240805-210000-RDMESHORT
-->
