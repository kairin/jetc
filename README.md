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

> **IMPORTANT ACKNOWLEDGMENT**: This project is based on the work from [dusty-nv/jetson-containers](https://github.com/dusty-nv/jetson-containers). The primary contribution here is an implementation focused on utilizing [Docker](https://www.docker.com/)'s [docker buildx build](https://docs.docker.com/build/builders/#difference-between-docker-build-and-docker-buildx-build) functionality for streamlined container building on Jetson devices.
>
> All credit for the original container implementations goes to the [dusty-nv and his team](https://github.com/dusty-nv/jetson-containers/graphs/contributors).

This repository provides ready-to-use Docker containers for NVIDIA Jetson devices, making it easy to run advanced AI applications like Stable Diffusion on your Jetson hardware.

![Screenshot from 2025-04-20 14-54-05](https://github.com/user-attachments/assets/bf61e6ab-12f0-45f3-860f-e65ec646871a)


![Jetson Containers](https://img.shields.io/badge/NVIDIA-Jetson-76B900?style=for-the-badge&logo=nvidia&logoColor=white)

---

## **What Can You Do With This Repo?**

With JETC, you can:

- **Run Stable Diffusion** and other AI image generation models on your Jetson
- **Use web interfaces** like Stable Diffusion WebUI and ComfyUI for creating AI art
- **Build optimized containers** with all dependencies pre-configured
- **Save hours of setup time** by avoiding manual installation of complex AI frameworks
- **Interactively build and run containers** using user-friendly scripts
- **Track and verify built images** with robust .env management and verification tools
- **Easily select and launch containers** with runtime options and persistent defaults
- **Access detailed logs and troubleshooting guides** for every build step

Planned [interface for build.sh](https://github.com/kairin/jetc/blob/main/proposed-app-build-sh.md), [interface for jetcrun.sh](https://github.com/kairin/jetc/blob/main/proposed-app-jetcrun-sh.md)

---

## **Quick Start Guide**

If you're new to this project, here's how to get started:

1. **Clone the repo**
   ```bash
   git clone https://github.com/kairin/jetc.git
   cd jetc/buildx
   ```

2. **Run the pre-run check script** (optional but recommended)
   ```bash
   ./scripts/pre-run.sh
   ```
   This script checks for prerequisites like Docker, buildx, and the `dialog` package (used for interactive menus). It *does not* create an `.env` file anymore.

3. **(Optional) Create `.env` for Defaults**
   You can optionally create a `buildx/.env` file to provide default values for Docker details and runtime options. The scripts will always prompt you to confirm or edit these. The `.env` file is also used to store information about successfully built images.
   ```bash
   # Example buildx/.env content:
   # DOCKER_REGISTRY=myregistry.example.com # Optional, leave empty for Docker Hub
   DOCKER_USERNAME=your-dockerhub-username
   DOCKER_REPO_PREFIX=001
   DEFAULT_BASE_IMAGE=nvcr.io/nvidia/l4t-pytorch:r35.4.1-pth2.1-py3 # Example, updated by build.sh
   
   # --- Automatically managed by scripts ---
   # List of successfully built images (semicolon-separated)
   AVAILABLE_IMAGES=your-user/001:01-stage:tag;your-user/001:latest-timestamp-tag
   # Last used settings by jetcrun.sh
   DEFAULT_IMAGE_NAME=your-user/001:latest-timestamp-tag
   DEFAULT_ENABLE_X11=on
   DEFAULT_ENABLE_GPU=on
   DEFAULT_MOUNT_WORKSPACE=on
   DEFAULT_USER_ROOT=on
   ```

4. **Run the build script**
   ```bash
   ./build.sh
   ```
   - This script builds the container stages sequentially.
   - **New:** Upon successful build of each stage (and the final timestamped image), the script automatically adds the image tag to the `AVAILABLE_IMAGES` list in your `buildx/.env` file.
   - It also updates `DEFAULT_BASE_IMAGE` in `.env` with the tag of the latest successfully built image.

5. **Follow the Interactive Setup**:
   *   **Step 0: Docker Information**: You'll be prompted (using a dialog menu if `dialog` is installed, otherwise text prompts) to confirm or enter your Docker Registry (optional), Username (required), and Repository Prefix (required). Defaults from `.env` will be shown if available.
   *   **Step 1: Build Options**: Select options like using cache, squashing layers, building locally only (`--load` vs `--push`), and using the optimized builder.
   *   **Step 2: Base Image**: Choose the base image for the *first* build stage (use default, pull default, or specify a custom one).
   *   **Step 3: Confirmation**: Review all settings and confirm to start the build.

6. **Wait for the build to complete**
   This process will build the container stages sequentially. It may take 1-3 hours.

7. **Post-Build Options**: If the build completes successfully, you'll get another menu asking if you want to run the final image, verify it, or skip.

8. **Run a Container**:
   ```bash
   ./jetcrun.sh
   ```
   - **New:** This script now reads the `AVAILABLE_IMAGES` list from `buildx/.env`.
   - It presents an interactive menu (dialog or text) allowing you to select from previously built images or enter a custom image name.
   - Your selections for image name and runtime options (X11, GPU, etc.) are saved back to `.env` as defaults for the next run.

## **What to Expect During the Build Process**

As a beginner, here's what you'll see during the build:

- The script will build multiple containers in sequence (01-build-essential, 02-bazel, etc.)
- You'll see progress messages for each component showing success or failure
- **Some components might fail** - this is normal and the script will continue with the next one
- At the end, you'll have a collection of usable containers even if some steps failed

![Build Process Example](https://raw.githubusercontent.com/kairin/jetc/main/docs/images/build_process_example.png)

## **After the Build: Using Your AI Applications**

When the build completes successfully, you can run your containers easily:

1. **Use the `jetcrun.sh` script (Recommended)**:
   ```bash
   ./jetcrun.sh
   ```
   - Select the desired image from the menu (which includes images automatically added during the build).
   - Choose runtime options (X11, GPU, Workspace Mount, Root User).
   - The script handles constructing the `docker run` or `jetson-containers run` command.

2. **Manual `docker run` (Example)**:
   If you prefer manual control, you can still use `docker run`. Find the exact tag in your `buildx/.env` file under `AVAILABLE_IMAGES` or `DEFAULT_IMAGE_NAME`.
   ```bash
   # Example for Stable Diffusion WebUI
   # Get the tag from .env (e.g., kairin/jetc:latest-YYYYMMDD-HHMMSS-1)
   IMAGE_TAG="kairin/jetc:latest-..." 
   docker run -it --rm --gpus all -p 7860:7860 -v /media/kkk:/workspace "$IMAGE_TAG" bash
   # Inside container:
   # cd /opt/stable-diffusion-webui
   # python launch.py --listen --port 7860
   ```

## **Repository Structure**

### **Root Structure**

```
jetc/
├── README.md
├── proposed-app-build-sh.md
├── proposed-app-jetcrun-sh.md
├── .env
├── .gitattributes
├── .gitignore
├── .github/
│   ├── copilot-instructions.md
│   ├── git-template-setup.md
│   ├── install-hooks.sh
│   ├── pre-commit-hook.sh
│   ├── prepare-commit-msg-hook.sh
│   ├── setup-git-template.sh
│   └── vs-code-snippets-guide.md
├── buildx/
│   ├── build/
│   ├── build.sh
│   ├── jetcrun.sh
│   ├── scripts/
│   │   ├── build_ui.sh
│   │   ├── commit_tracking.sh
│   │   ├── copilot-must-follow.md
│   │   ├── docker_helpers.sh
│   │   ├── logging.sh
│   │   ├── utils.sh
│   │   └── verification.sh
│   └── logs/
```

### **Modular Script Structure**

The build system has been modularized for better maintainability:

1. **`buildx/build.sh`** - Main orchestration script that:
   - Sources all required modular scripts
   - Determines build order and dependencies
   - Manages the overall build process
   - Handles errors and final tagging

2. **`buildx/scripts/docker_helpers.sh`** - Contains Docker utility functions:
   - `verify_image_exists()` - Check if a Docker image exists locally
   - `verify_container_apps()` - Run verification inside a container
   - `list_installed_apps()` - List installed applications in a container
   - `build_folder_image()` - Build, push and pull a Docker image

3. **`buildx/scripts/build_ui.sh`** - Handles environment setup and interactive UI:
   - `load_env_variables()` - Load environment variables from .env file
   - `setup_build_environment()` - Initialize build environment variables
   - `get_user_preferences()` - Get user input for build preferences

4. **`buildx/scripts/utils.sh`** - General utility functions:
   - Dialog checking, datetime retrieval, etc.

5. **`buildx/scripts/verification.sh`** - Container verification:
   - Functions for checking installed applications in containers

6. **`buildx/scripts/commit_tracking.sh`** - Commit tracking helpers

7. **`buildx/scripts/logging.sh`** - Logging helpers

---

### **`build/` Directory Structure**

The build system follows a specific directory structure:

```
buildx/build/
├── 01-build-essential/  # First build - essential build tools
├── 01-cuda/             # CUDA components
│   ├── Dockerfile       # Main CUDA Dockerfile (entry point)
│   ├── cuda/            # Core CUDA installation
│   ├── cudnn/           # NVIDIA cuDNN
│   ├── cuda-python/     # CUDA Python bindings
│   ├── cupy/            # CuPy library
│   └── pycuda/          # PyCUDA library
├── 02-bazel/           # Bazel build system
├── 03-ninja            # Ninja build tool
├── 04-python           # Python setup
└── ...                 # Other components
```

### **Build Process Details**

The modularized build script (`build.sh`) processes directories in numerical order:

1. Numbered directories (`01-*`, `02-*`, etc.) are built sequentially
2. Each numbered directory must contain a `Dockerfile` at its root
3. For directories with sub-components (like `01-cuda`), a main `Dockerfile` is required for the build script to work correctly

---

### **Special Notes for CUDA and Other Complex Components**

For complex components with multiple sub-components (like CUDA):

1. Create a main `Dockerfile` in the component directory (e.g., `01-cuda/Dockerfile`)
2. This main Dockerfile should install core functionality and set up the environment
3. Sub-components can be built separately in later steps (e.g., through separate build entries)

---

## **How the Modular Build System Works**

The modularized build system in this repository uses Docker's `buildx` to manage multi-platform builds targeting ARM64 (aarch64) devices. The main build process follows these steps:

1. **Initialization and Environment Setup**:
   - The main `build.sh` script sources modular components from `scripts/`.
   - `setup_env.sh` initializes build variables (timestamp, platform, etc.) and optionally loads defaults from `buildx/.env` (Registry, Username, Prefix, Default Base Image).
   - `setup_buildx.sh` ensures the `jetson-builder` buildx instance is ready.

2. **Interactive User Configuration**:
   - `setup_env.sh` (via `get_user_preferences`) prompts the user through a series of steps (using `dialog` or text prompts):
     - **Confirm/Enter Docker Details**: Registry, Username (required), Prefix (required).
     - **Select Build Options**: Cache, Squash, Local Build (`--load` vs `--push`), Use Builder.
     - **Choose Initial Base Image**: Use default, pull default, or specify custom.
     - **Final Confirmation**: Review settings before starting.
   - All confirmed settings are exported as environment variables.

3. **Build Process**:
   - `build.sh` determines the build order (numbered directories first, then others).
   - It iterates through the build directories (`build/01-*`, `build/02-*`, etc.).
   - For each stage, it calls `build_folder_image` (`docker_utils.sh`), passing the tag of the *previous successful stage* as the `BASE_IMAGE` build argument.
   - `build_folder_image` constructs the appropriate `docker buildx build` command based on user preferences (cache, squash, push/load) and executes it.
   - It verifies the image exists locally after each successful build (either via `docker pull` if pushed, or directly if loaded).
   - **New:** If a build stage is successful, `build.sh` calls `update_available_images_in_env` to add the new tag to the `AVAILABLE_IMAGES` list in `buildx/.env`.
   - The script continues to the next stage even if one fails, marking the overall build as failed.

4. **Verification and Tagging**:
   - After attempting all stages, if the build was successful so far, it verifies all intermediate images are available locally.
   - It creates a final timestamped tag (e.g., `your-registry/your-user/your-prefix:latest-YYYYMMDD-HHMMSS-1`) based on the last successfully built image.
   - This final tag is pushed to the registry, pulled back, and verified locally.
   - **New:** The final timestamped tag is also added to `AVAILABLE_IMAGES` in `.env`.
   - **New:** The `DEFAULT_BASE_IMAGE` in `.env` is updated to this final successful tag.

5. **Post-Build Options**:
   - If the final tag was created successfully, `post_build_menu.sh` presents an interactive menu (dialog or text).
   - Options include starting a shell in the final container, running verification scripts (`quick` or `full`), listing installed apps, or skipping.

6. **Final Checks & Exit**:
   - The script performs a final check to ensure all images recorded as successfully built/tagged are present locally.
   - Exits with status 0 for success or 1 for any failure during the process.

## **Recent Improvements**

Recent updates to the build system include:

1.  **Interactive Setup**:
    *   The script now always prompts the user to confirm or enter essential Docker information (Registry, Username, Prefix) and build options at the start.
    *   Uses the `dialog` utility for a graphical menu experience if available, falling back to text prompts otherwise.
2.  **Optional `.env` File**:
    *   The `buildx/.env` file is now optional and only used to provide *default* values for the initial interactive prompts. The script no longer fails if it's missing.
3.  **Modular Script Structure**:
    *   The build logic is split into well-defined scripts in `buildx/scripts/` for better maintainability.
4.  **Automatic Image Tracking**:
    *   `build.sh` now automatically records successfully built image tags in the `AVAILABLE_IMAGES` variable within `buildx/.env`.
5.  **Enhanced Run Script**:
    *   `jetcrun.sh` reads the `AVAILABLE_IMAGES` from `.env` to provide a convenient selection menu for running containers.
    *   Runtime options chosen in `jetcrun.sh` are saved back to `.env` as defaults.

## **Container Verification System**

A key feature of this repository is the comprehensive verification system for built containers. After building, you can verify what's installed:

### **Verification Options**

1. **Interactive Shell**: 
   - Launch a bash shell in the container for manual inspection

2. **Quick Verification**:
   - Run a quick check of common tools and packages
   - Verifies system tools and ML/AI frameworks

3. **Full Verification**:
   - Run a comprehensive check of all installed packages
   - Includes system packages, Python packages, and framework details

4. **Dedicated App Listing**:
   - List all installed applications in the container

### **The `list_installed_apps.sh` Script**

This modular script provides detailed information about installed components:

```bash
./scripts/list_installed_apps.sh [mode]
```

Available modes:
- `all`: Run all verification checks (default)
- `quick`: Basic system and ML framework checks
- `tools`: Check only system tools
- `ml`: Check only ML/AI frameworks
- `libs`: Check only Python libraries
- `cuda`: Check CUDA/GPU information
- `python`: List Python packages
- `system`: List system packages

## **Generative AI Components**

This repository includes components for running popular generative AI tools on Jetson:

### **Stable Diffusion**

- **16-stable-diffusion**: Core models and backend libraries
- **17-stable-diffusion-webui**: AUTOMATIC1111's WebUI implementation
  - Provides a web interface for image generation
  - Supports various models, sampling methods, and extensions

### **ComfyUI**

- **18-comfyui**: Node-based UI for Stable Diffusion
  - Visual workflow editor for advanced image generation pipelines
  - Modular design allows for complex customization

## **Running AI Web Interfaces**

To run the Stable Diffusion WebUI or ComfyUI after building:

1. **Start the container with port forwarding**:
   ```bash
   docker run -it --rm -p 7860:7860 -p 8188:8188 your-dockerhub-username/001:latest-timestamp bash
   ```

2. **For Stable Diffusion WebUI**:
   ```bash
   cd /opt/stable-diffusion-webui
   python launch.py --listen --port 7860
   ```
   Access the WebUI at `http://your-jetson-ip:7860`

3. **For ComfyUI**:
   ```bash
   cd /opt/ComfyUI
   python main.py --listen 0.0.0.0 --port 8188
   ```
   Access ComfyUI at `http://your-jetson-ip:8188`

## **Inspiration and Original Work**

This repository is fundamentally based on the excellent work provided by [dusty-nv/jetson-containers](https://github.com/dusty-nv/jetson-containers). The containers, configurations, and AI implementations originate from that project. **This project should be considered a specialized fork** that focuses specifically on streamlining the build process using Docker's buildx functionality.

The decision not to fork the original repository is not due to a lack of interest in contributing, but because this project serves a different target audience with distinct requirements and goals, particularly around the build process implementation.

For the most comprehensive and up-to-date Jetson container implementations, please refer to the original [dusty-nv/jetson-containers](https://github.com/dusty-nv/jetson-containers) repository and the work of its [contributors](https://github.com/dusty-nv/jetson-containers/graphs/contributors).

## **How to Use**

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/kairin/jetc.git
   cd jetc/buildx
   ```

2. **(Optional) Create `.env` for Defaults**:
   - You can create `buildx/.env` to pre-fill prompts:
     ```bash
     # Example buildx/.env
     # DOCKER_USERNAME=your-user
     # DOCKER_REPO_PREFIX=001
     ```

3. **Run the Build Script**:
   ```bash
   ./build.sh
   ```
   - Follow the interactive prompts to configure Docker details, build options, and the base image.
   - Confirm the settings to start the build. You will see native `docker buildx` output.

4. **View Build Output / Optional Logging**:
    *   Build progress is shown directly in the console.
    *   To save a log file:
        ```bash
        ./build.sh | tee build_$(date +"%Y%m%d-%H%M%S").log
        ```

## **Removing Old Files**

If you have an older version of the repository with the `_old_forAI_training` directory, you can safely remove it as all components have been migrated to the `buildx/build` structure:

```bash
rm -rf _old_forAI_training
```

The current repository structure is cleaner and more organized, with all build components residing in the `buildx/build` directory.

## **System Requirements**

- NVIDIA Jetson device (tested on Jetson AGX Orin 64GB)
- JetPack/L4T compatible with CUDA 11.4+
- Sufficient storage space (16GB+ recommended)
- Internet connection for pulling base images

## **Troubleshooting**

### **Handling Failed Builds**

When you see messages like "Build, push or pull failed for build/10-bitsandbytes" and exit code 1, here's what you can do:

1. **Examine the specific component logs**:
   ```bash
   # View logs for a specific failed component
   cat logs/10-bitsandbytes_*.log | grep -i error
   ```

2. **Fix issues and rebuild selective components**:
   - You don't need to rebuild everything from scratch
   - Use the last successful component as a base image and continue:
   ```bash
   # Example: If builds 01-09 succeeded but 10 failed
   cd buildx
   # Edit the Dockerfile in the failing component to fix issues
   nano build/10-bitsandbytes/Dockerfile
   # Run the build for just this component
   docker buildx build --platform linux/arm64 -t your-dockerhub-username/001:10-bitsandbytes --build-arg BASE_IMAGE=your-dockerhub-username/001:09-opencv --push build/10-bitsandbytes
   ```

3. **Common issues and solutions**:
   - For memory errors: Increase swap space on your Jetson
     ```bash
     # Check available memory and swap
     free -h
     # Create or increase swap file if needed
     sudo fallocate -l 8G /swapfile
     sudo chmod 600 /swapfile
     sudo mkswap /swapfile
     sudo swapon /swapfile
     # Add to fstab to make permanent
     echo '/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab
     ```
   - For disk space issues: Clean up Docker images
     ```bash
     # Check space usage
     docker system df
     # Clean up unused images
     docker system prune -a
     ```

4. **Continue with successful builds**:
   - You can still use the successfully built images for development
   - For example, if you need OpenCV but not bitsandbytes, you can use:
   ```bash
   docker run -it --rm your-dockerhub-username/001:09-opencv bash
   ```

5. **Build dependency issues**:
   - If component X depends on failed component Y, try modifying X's Dockerfile
   - Add the necessary packages directly in component X instead of relying on Y

## **Development Guidelines**

When contributing to this project, please follow our [Copilot coding standards](.github/copilot-instructions.md) which include:

- File header format with commit tracking (footer only, never at the top)
- Code organization principles
- Minimal diff guidelines

**All coding standards, minimal diff rules, and commit tracking/footer requirements are defined in [`./.github/copilot-instructions.md`](./.github/copilot-instructions.md).  
This file is the canonical source for all contributors and automation.  
See also [./.github/INSTRUCTIONS.md](./.github/INSTRUCTIONS.md) for summary and enforcement rules.**

These standards ensure consistent documentation and tracking across the codebase.

## **License**

This repository is released under the MIT License. See the LICENSE file for details.

## **Build Process Details**

The current build process structure has been reorganized to enhance stability and dependency management:

### **Updated Build Directory Structure**
