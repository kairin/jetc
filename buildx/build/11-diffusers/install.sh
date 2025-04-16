#!/bin/bash
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