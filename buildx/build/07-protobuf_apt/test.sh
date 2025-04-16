#!/usr/bin/env bash

# =========================================================================
# IMPORTANT: This build system requires Docker with buildx extension.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

echo "getting protobuf API implementation..."
echo "PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION = $PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION"
echo ""

echo "getting protobuf Python package info..."
pip3 show protobuf
echo ""

echo "getting protobuf compiler version..."
protoc --version
echo ""
