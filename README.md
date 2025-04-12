# jetc



### **`README.md`**


# JETC: Jetson Containers for Targeted Use Cases

This repository provides a structured and automated system for building Docker containers tailored for Jetson devices. The project is inspired by and based on the work provided by [dusty-nv/jetson-containers](https://github.com/dusty-nv/jetson-containers).



## **Overview**

This repository is designed to handle the preparation, patching, and building of Docker containers for various libraries and tools commonly used in AI, machine learning, and edge-computing workflows. The project leverages Docker's `buildx` to ensure compatibility with ARM64 (aarch64) devices, specifically NVIDIA Jetson platforms.

The folder structure and scripts are designed to efficiently build and patch specific components, with flexibility to handle dependencies and downstream workflows.



## **Repository Structure**

### **Root Structure**


.
├── Dockerfile                       # General Dockerfile for building containers
├── Dockerfile-20250410              # Alternate Dockerfile for specific builds
├── Dockerfile-list-apps             # Dockerfile for listing installed applications
├── README.md                        # This file - repository documentation
├── build/                           # Folder containing build directories for each component
├── build-20250410.sh                # Specific build script for 20250410
├── build-20250412-1118am.sh         # Specific build script for 20250412 (11:18 AM)
├── build-20250412-1127am.sh         # Specific build script for 20250412 (11:27 AM)
├── build-20250412-1150am.sh         # Specific build script for 20250412 (11:50 AM)
├── build-20250412.sh                # General build script for 20250412
├── build.sh                         # Main build script for orchestrating all builds
└── list_installed_apps.sh           # Script for listing installed applications within a container


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
└── 15-flash-attention               # FlashAttention library
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
   - Optionally runs the final image for interactive testing.

---

## **Inspiration and Original Work**

This repository is based on the excellent work provided by [dusty-nv/jetson-containers](https://github.com/dusty-nv/jetson-containers). The decision not to fork the original repository is not due to a lack of interest in contributing, but because this project serves a different target audience with distinct requirements and goals. While the core concepts and approaches are similar, this repository introduces modifications and extensions tailored to specific workflows and use cases.

---

## **Target Audience**

This repository is designed for developers and researchers working on:
- AI and machine learning projects on NVIDIA Jetson platforms.
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

4. **Inspect Built Images**:
   - List all built images:
     ```bash
     docker images
     ```

5. **Run the Final Image**:
   - Optionally, run the final built image:
     ```bash
     docker run -it --rm your-dockerhub-username/001:latest bash
     ```

---

## **Contributing**

While this repository is not a fork, contributions are welcome! If you have suggestions, bug reports, or improvements, feel free to open an issue or submit a pull request.

For contributions to the original repository, please visit [dusty-nv/jetson-containers](https://github.com/dusty-nv/jetson-containers).

---

## **License**

This repository is released under the MIT License. See the [LICENSE](LICENSE) file for details.
```

---

### Key Points in the `README.md`

1. **Acknowledgment of Source**:
   - Clearly states that the repository is based on [dusty-nv/jetson-containers](https://github.com/dusty-nv/jetson-containers).
   - Explains why the repository is not a fork (to serve a different target audience).

2. **Detailed Structure**:
   - Explains the purpose of each major folder and file.
   - Provides a clear overview of the `build/` directory and its subdirectories.

3. **Build Workflow**:
   - Describes how the `buildx` flow works step-by-step.

4. **Target Audience**:
   - Defines the intended users of the repository.

5. **How to Use**:
   - Provides a quick start guide for cloning, setting up, and building the images.

---

Copy this content into your `README.md` file, and it will provide a clear and comprehensive overview of your repository for potential users and contributors. Let me know if you'd like any additional edits!
