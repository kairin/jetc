# =========================================================================
# IMPORTANT: This build system requires Docker with buildx extension.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

jetson-containers run --gpus all -v /media/kkk:/workspace -it --rm --user root $(autotag kairin/001:latest-20250412-230811-1) /bin/bash