# Docker Image Builder for Jetson Devices

This automated build system creates, pushes, and verifies Docker images specifically optimized for Jetson (ARM64) platforms.

## Prerequisites

- Docker with buildx plugin
- A running Jetson device (aarch64 architecture)
- Internet connectivity
- Docker Hub account or other container registry access
- `.env` file with required configuration

## Configuration

Create a `.env` file with the following variables:

```
DOCKER_USERNAME=yourusername
# Add other configuration variables as needed
```

## Usage

```bash
# Run the build script
./build.sh
```

The script will:
1. Build images in numeric order from the build/ directory
2. Push images to Docker registry
3. Pull images to verify they're accessible
4. Create a final timestamped tag for the last successful build
5. Verify all images are available locally

## Image Layer Management

The script includes automatic flattening of Docker images to prevent the "max depth exceeded" error common with deep image hierarchies.

## Troubleshooting

If you encounter authentication issues:
```bash
docker login
```

For layer depth issues, enable image flattening when prompted.
