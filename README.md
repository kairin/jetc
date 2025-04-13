# JETC

### **README.md**

# JETC: Jetson Containers for Targeted Use Cases

This repository provides a structured and automated system for building Docker containers tailored for Jetson devices. The project is inspired by and based on the work provided by [dusty-nv/jetson-containers](https://github.com/dusty-nv/jetson-containers).

## **Overview**

This repository is designed to handle the preparation, patching, and building of Docker containers for various libraries and tools commonly used in AI, machine learning, and edge-computing workflows. The project leverages Docker's `buildx` to ensure compatibility with ARM64 (aarch64) devices, specifically NVIDIA Jetson platforms.

The folder structure and scripts are designed to efficiently build and patch specific components, with flexibility to handle dependencies and downstream workflows.

## **Repository Structure**

### **Root Structure**


```
# Updated README.md for JETC Project

I recommend enhancing your README.md with details about the new components and verification capabilities. Here's a comprehensive update:

```markdown
# JETC: Jetson Containers for Targeted Use Cases

This repository provides a structured and automated system for building Docker containers tailored for Jetson devices. The project is inspired by and based on the work provided by [dusty-nv/jetson-containers](https://github.com/dusty-nv/jetson-containers).

## **Overview**

This repository is designed to handle the preparation, patching, and building of Docker containers for various libraries and tools commonly used in AI, machine learning, and edge-computing workflows. The project leverages Docker's `buildx` to ensure compatibility with ARM64 (aarch64) devices, specifically NVIDIA Jetson platforms.

The folder structure and scripts are designed to efficiently build and patch specific components, with flexibility to handle dependencies and downstream workflows.

## **Repository Structure**

### **Root Structure**

```
.
├─1
├── README.md                        # This file - repository documentation
├─2
├── buildx/build/                    # Folder containing build directories for each component
├─3                    
├── buildx/build.sh                  # Main build script for orchestrating all builds
├── generate_app_checks.sh           # Helper script for generating application verification
├── jetcrun.sh                       # Utility script for running Jetson containers
└── list_installed_apps.sh           # Script for listing installed applications within a container
```
---

### **`build/` Directory**

The `build` directory is where individual components and their build processes are defined. Each subdirectory corresponds to a specific component or library, and is responsible for building and patching as needed.

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
- A `Dockerfile` for building the specific component.
- A `patches/` folder for any patches required during the build process.
- Other optional files (`README.md`, `test.py`, etc.) for documentation and testing.

---

## **How the Build System Works**

This repository uses the `buildx` system for Docker to manage multi-platform builds, specifically targeting ARM64 (aarch64) devices. The main build process is orchestrated via `build.sh`, which performs the following steps:

1. **Initialization**:
   - Loads environment variables from `.env`.
   - Detects the platform (ensures aarch64).
   - Sets up a `buildx` builder if not already configured.

2. **User Input**:
   - Prompts the user to decide whether to build with or without cache.

3. **Build Process**:
   - Processes **numbered directories** in ascending order (e.g., `01-build-essential`, `02-bazel`).
     - Each numbered directory depends on the image built in the previous directory.
   - Processes **non-numbered directories** after all numbered builds are completed.

4. **Patch Handling**:
   - Applies patches during builds for components like `15-flash-attention`.

5. **Final Tagging**:
   - Creates a timestamped `latest` tag for the final built image.

6. **Post-Build Actions**:
   - Pulls all built images for validation.
   - Offers several options for verifying and interacting with the final image.

---

## **Container Verification System**

A key feature of this repository is the comprehensive verification system for built containers. After building, the system provides several options to verify the container's functionality:

### **Verification Options**

1. **Interactive Shell**: 
   - Launch a bash shell in the container for manual inspection.

2. **Quick Verification**:
   - Run a quick check of common tools and packages.
   - Verifies system tools and ML/AI frameworks.

3. **Full Verification**:
   - Run a comprehensive check of all installed packages.
   - Includes system packages, Python packages, and framework details.

4. **Dedicated App Listing**:
   - Builds and runs a specialized container that lists all installed applications.

### **The `list_installed_apps.sh` Script**

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

---

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

---

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

---

## **Inspiration and Original Work**

This repository is based on the excellent work provided by [dusty-nv/jetson-containers](https://github.com/dusty-nv/jetson-containers). The decision not to fork the original repository is not due to a lack of interest in contributing, but because this project serves a different target audience with distinct requirements and goals. While the core concepts and approaches are similar, this repository introduces modifications and extensions tailored to specific workflows and use cases.

---

## **Target Audience**

This repository is designed for developers and researchers working on:
- AI and machine learning projects on NVIDIA Jetson platforms.
- Generative AI applications on edge devices.
- Optimized Docker container builds for ARM64 (aarch64) devices.
- Customized workflows requiring patched or pre-built libraries.

---

## **How to Use**

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/kairin/jetc.git
   cd jetc
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

4. **Selective Building** (optional):
   - To build only specific components, edit the build script or use:
     ```bash
     BUILD_DIRS="01-build-essential 02-bazel" ./build.sh
     ```

5. **Post-Build Options**:
   - The script will offer several options after successful build:
     - Start an interactive shell
     - Run quick verification
     - Run full verification
     - Build and run list-apps container
     - Skip (do nothing)

6. **Using Built Images for Development**:
   - The final image can be used as a development environment:
     ```bash
     docker run -it --rm -v $(pwd):/workspace your-dockerhub-username/001:latest-timestamp bash
     ```

---

## **System Requirements**

- NVIDIA Jetson device: I am particularly targeting the AGX ORIN with 64GB of shared memory.


## Additional Improvements

```markdown
### **Build Requirements**

- Docker with buildx plugin installed
- Docker Hub account (for pushing images)
- At least 50GB free disk space
- Reliable internet connection
- Environment file (.env) with DOCKER_USERNAME defined
```
---

## **Troubleshooting**

### **Common Issues**

1. **Build failures in ML components**:
   - Ensure you have sufficient swap space (8GB+)
   - Try building with cache: `use_cache=y`

2. **"No space left on device" errors**:
   - Clear Docker cache: `docker system prune -af`
   - Increase available storage

3. **Web UI accessibility issues**:
   - Verify port forwarding is correct
   - Ensure you're using `--listen` flags when starting services

### **Common Build Issues**

- **Build script fails with "platform error"**: 
  Ensure you're running on an ARM64 architecture device (Jetson)
  
- **Image verification fails after build**:
  Check your internet connection and Docker Hub permissions
  
- **Build hangs or fails on specific components**:
  Try building with more swap space or specify individual directories to build

---

## **Contributing**

While this repository is not a fork, contributions are welcome! If you have suggestions, bug reports, or improvements, feel free to open an issue or submit a pull request.

For contributions to the original repository, please visit [dusty-nv/jetson-containers](https://github.com/dusty-nv/jetson-containers).

---

## **License**

This repository is released under the MIT License. See the LICENSE file for details.

```
This update:

1. Adds the new components (16-18) to the build directory listing
2. Creates a new "Container Verification System" section explaining our verification tools
3. Adds a "Generative AI Components" section highlighting SD and ComfyUI
4. Includes instructions for running the web interfaces
5. Expands the "How to Use" section with selective building options
6. Adds "System Requirements" and "Troubleshooting" sections
7. Updates the "Target Audience" to include generative AI applications
```
