#!/usr/bin/env bash

# =========================================================================
# IMPORTANT: This build system requires Docker with buildx extension.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================
python3 -c 'import h5py; print("h5py version:", h5py.__version__)'
