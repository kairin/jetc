# JETC Repository Structure

This document outlines the current folder structure and important files in the JETC repository.

## Folder Structure

```
jetc/
├── README.md
├── buildx/
│   ├── README.md
│   ├── build/
│   │   ├── 01-build-essential
│   │   ├── 02-bazel
│   │   ├── 03-ninja
│   │   ├── 04-python
│   │   ├── 05-h5py
│   │   ├── 06-rust
│   │   ├── 07-protobuf_apt
│   │   ├── 08-protobuf_cpp
│   │   ├── 09-opencv
│   │   ├── 10-bitsandbytes
│   │   ├── 11-diffusers
│   │   ├── 12-huggingface_hub
│   │   ├── 13-transformers
│   │   ├── 14-xformers
│   │   ├── 15-flash-attention
│   │   ├── 16-stable-diffusion
│   │   ├── 17-stable-diffusion-webui
│   │   └── 18-comfyui
│   ├── build.sh
│   ├── jetcrun.sh
│   └── scripts/
│       ├── add_buildx_note.sh
│       ├── auto_flatten_images.sh
│       ├── build_utils.sh
│       ├── check_dockerstatus.sh
│       ├── config.sh
│       ├── debug_buildx.sh
│       ├── fix_image_builder.sh
│       ├── generate_app_checks.sh
│       ├── image_builder.sh
│       ├── image_utils.sh
│       ├── list_installed_apps.sh
│       ├── ui_utils.sh
│       ├── utils.sh
│       ├── verification.sh
│       └── verify_utils.sh
```

## Key Files and Their Locations

### Main Build Files
- `/jetc/buildx/build.sh` - Main build script to set up Docker buildx environment
- `/jetc/buildx/jetcrun.sh` - Script for running applications with the JETC environment

### Utility Scripts
Scripts should be called from their respective locations in the `/jetc/buildx/scripts/` directory:

- `debug_buildx.sh` - Debugging utility for Docker buildx issues
- `image_builder.sh` - Helper for building Docker images
- `check_dockerstatus.sh` - Verifies Docker login status
- `build_utils.sh` - Common utilities used during builds
- `config.sh` - Configuration settings for the build system
- `utils.sh` - General utility functions

### Build Definitions
The numbered directories in `/jetc/buildx/build/` contain build definitions for various tools and libraries, arranged in dependency order from 01 to 18.

## Usage Notes
1. Always run scripts from their original locations
2. Build scripts expect to be run from the `/jetc/buildx/` directory
3. The main entry point for builds is `/jetc/buildx/build.sh`
```

## Recent Changes
- Moved scripts from root into the buildx directory structure
- Consolidated build files under the buildx directory
- Added the debug_buildx.sh script to help troubleshoot buildx issues
