<!--
# COMMIT-TRACKING: UUID-20240729-004815-A3B1
# Description: Clarify UUID reuse policy in instructions
# Author: Mr K
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- THIS FILE
# └── ...                        <- Other project files
-->
# JETC: Jetson Containers for Targeted Use Cases

This repository provides ready-to-use Docker containers for NVIDIA Jetson devices, making it easy to run advanced AI applications like Stable Diffusion on your Jetson hardware.

![Jetson Containers](https://img.shields.io/badge/NVIDIA-Jetson-76B900?style=for-the-badge&logo=nvidia&logoColor=white)

## **What Can You Do With This Repo?**

With JETC, you can:

- **Run Stable Diffusion** and other AI image generation models on your Jetson
- **Use web interfaces** like Stable Diffusion WebUI and ComfyUI for creating AI art
- **Build optimized containers** with all dependencies pre-configured
- **Save hours of setup time** by avoiding manual installation of complex AI frameworks

## **Quick Start Guide**

If you're new to this project, here's how to get started:

1. **Clone the repo**
   ```bash
   git clone https://github.com/kairin/jetc.git
   cd jetc/buildx
   ```

2. **Set up your Docker username**
   ```bash
   echo "DOCKER_USERNAME=your-dockerhub-username" > .env
   ```

3. **Run the build script**
   ```bash
   ./build.sh
   ```

4. **Choose an option when prompted**
   When asked "Do you want to build with cache? (y/n):", type `n` for a clean build or `y` to use cached layers (faster but may use outdated components).

5. **Wait for the build to complete**
   This process will take 1-3 hours depending on your Jetson model.

## **What to Expect During the Build Process**

As a beginner, here's what you'll see during the build:

- The script will build multiple containers in sequence (01-build-essential, 02-bazel, etc.)
- You'll see progress messages for each component showing success or failure
- **Some components might fail** - this is normal and the script will continue with the next one
- At the end, you'll have a collection of usable containers even if some steps failed

![Build Process Example](https://raw.githubusercontent.com/kairin/jetc/main/docs/images/build_process_example.png)

## **After the Build: Using Your AI Applications**

When the build completes successfully, you can:

1. **Run Stable Diffusion WebUI**
   ```bash
   # Replace with your actual tag from the build
   # Format: your-dockerhub-username/001:latest-YYYYMMDD-HHMMSS-1
   docker run -it --rm -p 7860:7860 your-dockerhub-username/001:latest-20250418-123456-1 bash
   cd /opt/stable-diffusion-webui
   python launch.py --listen --port 7860
   ```
   Then open `http://your-jetson-ip:7860` in your browser

2. **Use ComfyUI**
   ```bash
   docker run -it --rm -p 8188:8188 your-dockerhub-username/001:latest-20250418-123456-1 bash
   cd /opt/ComfyUI
   python main.py --listen 0.0.0.0 --port 8188
   ```
   Then open `http://your-jetson-ip:8188` in your browser

## **Repository Structure**

### **Root Structure**

```
.
├── README.md                        # This file - repository documentation
├── buildx/                          # Main directory containing build system
    ├── build/                       # Folder containing build directories for each component
    ├── build.sh                     # Main build script for orchestrating all builds
    ├── scripts/                     # Directory containing modular script components
    │   ├── docker_utils.sh          # Docker utility functions
    │   ├── setup_env.sh             # Environment setup functions
    │   ├── setup_buildx.sh          # Docker buildx setup functions
    │   ├── post_build_menu.sh       # Post-build menu options
    │   ├── generate_app_checks.sh   # Helper script for generating application verification
    │   └── list_installed_apps.sh   # Script for listing installed applications within a container
    ├── jetcrun.sh                   # Utility script for running Jetson containers
    └── logs/                        # Directory containing build logs
```

### **Modular Script Structure**

The build system has been modularized for better maintainability:

1. **`buildx/build.sh`** - Main orchestration script that:
   - Sources all required modular scripts
   - Determines build order and dependencies
   - Manages the overall build process
   - Handles errors and final tagging

2. **`buildx/scripts/docker_utils.sh`** - Contains Docker utility functions:
   - `verify_image_exists()` - Check if a Docker image exists locally
   - `verify_container_apps()` - Run verification inside a container
   - `list_installed_apps()` - List installed applications in a container
   - `build_folder_image()` - Build, push and pull a Docker image

3. **`buildx/scripts/setup_env.sh`** - Handles environment setup:
   - `load_env_variables()` - Load environment variables from .env file
   - `setup_build_environment()` - Initialize build environment variables
   - `get_user_preferences()` - Get user input for build preferences

4. **`buildx/scripts/setup_buildx.sh`** - Sets up Docker buildx:
   - `setup_buildx_builder()` - Create or use Docker buildx builder

5. **`buildx/scripts/post_build_menu.sh`** - Post-build options:
   - `show_post_build_menu()` - Interactive menu for post-build operations

6. **`buildx/scripts/list_installed_apps.sh`** - Container verification:
   - Functions for checking installed applications in containers

7. **`buildx/scripts/generate_app_checks.sh`** - Generates verification code:
   - Creates checks based on Dockerfiles for application verification

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

### **Special Notes for CUDA and Other Complex Components**

For complex components with multiple sub-components (like CUDA):

1. Create a main `Dockerfile` in the component directory (e.g., `01-cuda/Dockerfile`)
2. This main Dockerfile should install core functionality and set up the environment
3. Sub-components can be built separately in later steps (e.g., through separate build entries)

## **How the Modular Build System Works**

The modularized build system in this repository uses Docker's `buildx` to manage multi-platform builds targeting ARM64 (aarch64) devices. The main build process follows these steps:

1. **Initialization and Environment Setup**:
   - The main `build.sh` script sources modular components from `scripts/`
   - `setup_env.sh` loads environment variables and initializes tracking
   - `setup_buildx.sh` sets up the Docker buildx builder

2. **User Input**:
   - The script prompts the user to decide whether to build with or without cache

3. **Build Process**:
   - Processes **numbered directories** in ascending order (01-build-essential, 02-bazel, etc.)
   - Each step uses utility functions from `docker_utils.sh`
   - Continues the build process even if individual components fail

4. **Verification and Tagging**:
   - Creates a timestamped `latest` tag for the final built image
   - Verifies all images are accessible locally

5. **Post-Build Options**:
   - Uses `post_build_menu.sh` to provide interactive options
   - Options include interactive shell, verification, and app listing

## **Recent Improvements**

Recent updates to the build system include:

1.  **Modular Script Structure**:
    *   The build script has been split into modular components for better maintainability
    *   Each script handles a specific aspect of the build process
    *   Scripts can be updated independently without affecting the entire system

2.  **Enhanced Error Handling**:
    *   The build process continues even when individual components fail
    *   Failures are clearly reported, allowing the script to attempt building subsequent components

3.  **Native Docker Buildx Output**:
    *   The build script runs `docker buildx build` directly, without any interference
    *   This ensures you see the **full, native buildx progress**, colors, and interactive output directly in your terminal

4.  **Better Tag Handling & Verification**:
    *   Improved tracking and verification of image tags throughout the build process

5.  **Standardized Headers**:
    *   All scripts include a consistent header for tracking changes (UUID, description, author, location)

**Why these changes were made:**
*   To provide a more maintainable and modular codebase
*   To make it easier to understand and modify specific parts of the build process
*   To provide the most intuitive build experience by showing the **native `docker buildx` output**

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

This repository is based on the excellent work provided by [dusty-nv/jetson-containers](https://github.com/dusty-nv/jetson-containers). The decision not to fork the original repository is not due to a lack of interest in contributing, but because this project serves a different target audience with distinct requirements and goals.

## **How to Use**

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/kairin/jetc.git
   cd jetc/buildx
   ```

2. **Set Up Environment Variables**:
   - Create a `.env` file and set the `DOCKER_USERNAME` variable:
     ```bash
     echo "DOCKER_USERNAME=your-dockerhub-username" > .env
     ```

3. **Run the Build Script**:
   - To build all components:
     ```bash
     ./build.sh
     ```
   - You will see the native `docker buildx` output directly in your terminal.
   - The script will continue building components even if some fail.

4. **View Build Output / Optional Logging**:
    *   The primary build output is shown directly in the console.
    *   If you need a log file, run the script like this:
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

## **License**

This repository is released under the MIT License. See the LICENSE file for details.

## **Build Process Details**

The current build process structure has been reorganized to enhance stability and dependency management:

### **Updated Build Directory Structure**
