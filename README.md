# JETC: Jetson Containers for Targeted Use Cases

This repository provides a structured and automated system for building Docker containers tailored for Jetson devices. The project is inspired by and based on the work provided by [dusty-nv/jetson-containers](https://github.com/dusty-nv/jetson-containers).

## Overview

This repository is designed to handle the preparation, patching, and building of Docker containers for various libraries and tools commonly used in AI, machine learning, and edge-computing workflows. The project leverages Docker's `buildx` to ensure compatibility with ARM64 (aarch64) devices, specifically NVIDIA Jetson platforms.

The folder structure and scripts are designed to efficiently build and patch specific components, with flexibility to handle dependencies and downstream workflows.

## Repository Structure

### Root Structure

```
.
├── README.md                        # This file - repository documentation
├── buildx/build/                    # Folder containing build directories for each component
├── build.sh                         # Main build script for orchestrating all builds
│                                    # Other buildx related files/scripts
├── generate_app_checks.sh           # Helper script for generating application verification
├── jetcrun.sh                       # Utility script for running Jetson containers
└── list_installed_apps.sh           # Script for listing installed applications within a container
```

### Build Directory Structure

```
build/
├── 01-build-essential               # Base build for essential tools
├── 02-bazel                         # Bazel build system
├── 03-ninja                         # Ninja build tool
├── 04-python                        # Python setup
├── 05-h5py                          # HDF5 for Python
├── 06-rust                          # Rust programming language
├── 07-protobuf_apt                  # Protobuf using APT
├── 08-protobuf_cpp                  # Protobuf for C++
├── 09-opencv                        # OpenCV for computer vision
├── 10-bitsandbytes                  # Bitsandbytes library
├── 11-diffusers                     # Hugging Face Diffusers
├── 12-huggingface_hub               # Hugging Face Hub
├── 13-transformers                  # Hugging Face Transformers
├── 14-xformers                      # Xformers library
├── 15-flash-attention               # FlashAttention library
├── 16-stable-diffusion              # Stable Diffusion models and backend
├── 17-stable-diffusion-webui        # Stable Diffusion Web UI (AUTOMATIC1111)
└── 18-comfyui                       # ComfyUI workflow-based UI for Stable Diffusion
```

Each directory contains the following:
- A Dockerfile for building the specific component
- A patches/ folder for any patches required during the build process
- Other optional files (README.md, test.py, etc.) for documentation and testing
- jetcrun.sh is basically a script to run `jetson-containers run`

## How the Build System Works

This repository uses the buildx system for Docker to manage multi-platform builds, specifically targeting ARM64 (aarch64) devices. The main build process is orchestrated via `buildx/build.sh`, which performs the following steps:

### Initialization
- Loads environment variables from `.env`
- Detects the platform (ensures aarch64)
- Sets up a buildx builder if not already configured

### User Input
- Prompts the user to decide whether to build with or without cache

### Build Process
- Processes numbered directories in ascending order (e.g., 01-build-essential, 02-bazel)
- Each numbered directory depends on the image built in the previous directory
- Processes non-numbered directories after all numbered builds are completed

### Patch Handling
- Applies patches during builds for components like 15-flash-attention

### Final Tagging
- Creates a timestamped latest tag for the final built image

### Post-Build Actions
- Pulls all built images for validation
- Offers several options for verifying and interacting with the final image

## Build Process in Detail

The `buildx/build.sh` script automates the complete build pipeline for Jetson container images. Here's what happens when you run it:

### 1. Initialization
```bash
$ ./buildx/build.sh
```
- Loads configuration from `.env` file
- Verifies Docker username is configured
- Validates you're running on a Jetson device (ARM64 architecture)
- Sets up Docker buildx for multi-architecture builds
- Asks if you want to build with cache for faster builds

### 2. Building Container Images
The script processes directories in the `build/` folder in this order:

- **Numbered directories first** (01-build-essential, 02-bazel, etc.)
  - Processed sequentially as each image depends on the previous one
  - Example: `your-dockerhub-username/jetc:02-bazel` is built on top of `your-dockerhub-username/jetc:01-build-essential`
- **Non-numbered directories** (if any)
  - Built using the last successful numbered image as base

For each directory, the script:
1. Creates a Docker image tag (e.g., `your-dockerhub-username/jetc:01-build-essential`)
2. Builds the image using Docker buildx
3. Pushes the image to Docker Hub
4. Pulls the image back to verify it's accessible
5. Verifies the image exists locally

### 3. Creating Final Tagged Image
After all images are built successfully:
- Creates a timestamped "latest" tag (e.g., `your-dockerhub-username/jetc:latest-YYYYMMDD-HHMMSS`)
- Pushes and pulls this final tag for verification

### 4. Verification and Options
The script offers several options for the final image:
1. Start an interactive shell
2. Run quick verification (common tools and packages)
3. Run full verification (all system packages)
4. List installed apps in the container
5. Skip (do nothing)

### 5. Final Verification
- Performs a final check that all successfully built images exist locally
- Reports overall success or failure

## Example Build Process Output

```
Determining build order...
Starting build process...
--- Building Numbered Directories ---
Processing numbered directory: build/01-build-essential
Generating fixed tag: your-dockerhub-username/jetc:01-build-essential
Building and pushing image from folder: build/01-build-essential
...
Successfully built, pushed, and pulled numbered image: your-dockerhub-username/jetc:01-build-essential

Processing numbered directory: build/02-bazel
Generating fixed tag: your-dockerhub-username/jetc:02-bazel
Using base image build arg: your-dockerhub-username/jetc:01-build-essential
...
Successfully built, pushed, and pulled numbered image: your-dockerhub-username/jetc:02-bazel

... [continues for all directories] ...

--- Creating Final Timestamped Tag ---
Attempting to tag your-dockerhub-username/jetc:18-comfyui as your-dockerhub-username/jetc:latest-YYYYMMDD-HHMMSS
Successfully created, pushed, and pulled final timestamped tag.

Final Image: your-dockerhub-username/jetc:latest-YYYYMMDD-HHMMSS
What would you like to do with the final image?
1) Start an interactive shell
2) Run quick verification (common tools and packages)
3) Run full verification (all system packages, may be verbose)
4) List installed apps in the container
5) Skip (do nothing)
Enter your choice (1-5):
```
> **Note:** Replace `your-dockerhub-username/jetc` and `YYYYMMDD-HHMMSS` with your actual image naming convention and timestamp format.

## Container Verification System

A key feature of this repository is the comprehensive verification system for built containers. After building, the system provides several options to verify the container's functionality:

### Verification Options

#### Interactive Shell
- Launch a bash shell in the container for manual inspection

#### Quick Verification
- Run a quick check of common tools and packages
- Verifies system tools and ML/AI frameworks

#### Full Verification
- Run a comprehensive check of all installed packages
- Includes system packages, Python packages, and framework details

#### Dedicated App Listing
- Builds and runs a specialized container that lists all installed applications

### The `list_installed_apps.sh` Script

This modular script provides detailed information about installed components:

```bash
./list_installed_apps.sh [mode]
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

The script uses color-coded output to clearly indicate installed (✅) vs. missing (❌) components.

## Generative AI Components

This repository includes components for running popular generative AI tools on Jetson:

### Stable Diffusion
- **16-stable-diffusion**: Core models and backend libraries
- **17-stable-diffusion-webui**: AUTOMATIC1111's WebUI implementation
  - Provides a web interface for image generation
  - Supports various models, sampling methods, and extensions

### ComfyUI
- **18-comfyui**: Node-based UI for Stable Diffusion
  - Visual workflow editor for advanced image generation pipelines
  - Modular design allows for complex customization

## Running AI Web Interfaces

To run the Stable Diffusion WebUI or ComfyUI after building:

1. Start the container with port forwarding:

```bash
# Replace your-dockerhub-username/jetc:latest-timestamp with your actual final image tag
docker run -it --rm --gpus all -p 7860:7860 -p 8188:8188 your-dockerhub-username/jetc:latest-timestamp bash
```
> **Note:** The `--gpus all` flag is required for GPU acceleration with these UIs.

2. For Stable Diffusion WebUI:

```bash
cd /opt/stable-diffusion-webui
# Added --enable-insecure-extension-access if needed, remove if not
python launch.py --listen --port 7860 --enable-insecure-extension-access
```
Access the WebUI at http://<your-jetson-ip>:7860

3. For ComfyUI:

```bash
cd /opt/ComfyUI
python main.py --listen 0.0.0.0 --port 8188
```
Access ComfyUI at http://<your-jetson-ip>:8188

## How to Use

### Clone the Repository

```bash
git clone https://github.com/kairin/jetc.git
cd jetc
```

### Set Up Environment Variables

Create a `.env` file and set the DOCKER_USERNAME variable:

```bash
echo "DOCKER_USERNAME=your-dockerhub-username" > .env
```
> **Important:** Ensure `your-dockerhub-username` is replaced with your actual Docker Hub username.

### Run the Build Script

Navigate to the buildx directory:

```bash
cd buildx
```

To build all components:

```bash
./build.sh
```

### Selective Building (optional)

To build only specific components, you might need to modify the build script or pass environment variables if the script supports it:

```bash
# Example: Build only first two components (syntax depends on build.sh implementation)
BUILD_DIRS="01-build-essential 02-bazel" ./build.sh
```

### Post-Build Options

The script will offer several options after successful build:
1. Start an interactive shell
2. Run quick verification
3. Run full verification
4. Build and run list-apps container
5. Skip (do nothing)

### Using Built Images for Development

The final image can be used as a development environment:

```bash
# Replace your-dockerhub-username/jetc:latest-timestamp with your actual final image tag
docker run -it --rm --gpus all -v $(pwd):/workspace your-dockerhub-username/jetc:latest-timestamp bash
```

## System Requirements

- **Hardware**: NVIDIA Jetson device (Tested primarily on AGX Orin 64GB, but should work on others)
- **Operating System**: Jetson Linux (L4T) compatible with the target JetPack version

## Build Requirements

- Docker engine installed
- Docker buildx plugin installed and configured
- Docker Hub account (for pushing images)
- Sufficient free disk space (Recommend at least 50GB, more for extensive caching)
- Reliable internet connection
- Environment file (`.env` in the project root or buildx directory) with DOCKER_USERNAME defined
- Sufficient RAM and Swap (Especially for ML components, consider configuring 8GB+ swap)

## Troubleshooting

### Common Issues

#### Build failures in ML components (e.g., PyTorch, TensorFlow, xformers)
- Ensure you have sufficient RAM and Swap space configured on your Jetson. Building these can be memory intensive.
- Try building without cache if a cached layer seems corrupted: `./build.sh --no-cache` (or similar flag, check build.sh).

#### "No space left on device" errors
- Clean up unused Docker resources: `docker system prune -af`
- Remove old build caches: `docker builder prune -af`
- Ensure your Jetson's storage isn't full.

#### Web UI accessibility issues (Stable Diffusion, ComfyUI)
- Verify the container was started with the correct port mapping (`-p 7860:7860`, `-p 8188:8188`).
- Ensure you are using the correct IP address of your Jetson device in the browser.
- Check if the services inside the container started correctly using the `--listen` flags.
- Make sure no firewall is blocking the ports on the Jetson or your network.

#### Build script fails with "platform error" or architecture mismatch
- Confirm you are running the build script directly on the target Jetson (aarch64) device.
- Ensure Docker buildx is correctly set up for linux/arm64. Check with `docker buildx ls`.

#### Image verification fails after build (Pulling fails)
- Check your internet connection.
- Verify your Docker Hub credentials and ensure you are logged in (`docker login`).
- Confirm the image was successfully pushed to Docker Hub during the build step. Check the build logs.

#### Build hangs or fails on specific components
- Try building with more swap space.
- Isolate the issue by attempting to build only that specific component's directory (if the script allows). Check the Dockerfile for that component for potential issues.

## Inspiration and Original Work

This repository is based on the excellent work provided by [dusty-nv/jetson-containers](https://github.com/dusty-nv/jetson-containers). The decision not to fork the original repository is not due to a lack of interest in contributing, but because this project serves a different target audience with distinct requirements and goals. While the core concepts and approaches are similar, this repository introduces modifications and extensions tailored to specific workflows and use cases.

## Target Audience

This repository is designed for developers and researchers working on:

- AI and machine learning projects on NVIDIA Jetson platforms
- Generative AI applications on edge devices
- Optimized Docker container builds for ARM64 (aarch64) devices
- Customized workflows requiring patched or pre-built libraries

## Contributing

While this repository is not a direct fork, contributions that align with its specific goals are welcome! If you have suggestions, bug reports, or improvements, feel free to open an issue or submit a pull request.

For contributions to the original foundational repository, please visit [dusty-nv/jetson-containers](https://github.com/dusty-nv/jetson-containers).

## License

This repository is released under the MIT License. See the LICENSE file for details.
