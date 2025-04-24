#!/bin/bash

# =========================================================================
# IMPORTANT: This build system requires Docker with buildx extension.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================
set -e

if [ "$FORCE_BUILD" == "on" ]; then
    exit 1
fi

# Check if version is provided
if [ -z "$DIFFUSERS_VERSION" ]; then
    echo "DIFFUSERS_VERSION not set, defaulting to latest"
    pip3 install diffusers
else
    echo "Installing diffusers version $DIFFUSERS_VERSION"
    pip3 install "diffusers==$DIFFUSERS_VERSION"
fi