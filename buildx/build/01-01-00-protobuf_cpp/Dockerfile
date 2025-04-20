# COMMIT-TRACKING: UUID-20240802-101500-FIX-PROTOBUF-CPP-BUILD
# Description: Use install.sh to build protobuf with C++ implementation instead of pip install. Remove redundant TARGETPLATFORM and pip install step.
# Author: GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 01-01-00-protobuf_cpp/ <- Current directory (renamed from 08-protobuf_cpp)
# │   │       ├── Dockerfile       <- THIS FILE
# │   │       ├── install.sh       <- Installation script
# │   │       └── config.py        <- Configuration script
# └── ...                        <- Other project files
# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

#---
# name: protobuf:cpp
# group: build
# config: config.py
# depends: [build-essential, cmake] # Dependencies handled by install.sh now
# test: embedded
#---
# Use ARG for dynamic base image injection, with a default value
ARG TARGETPLATFORM=linux/arm64 # Keep ARG for potential external use, but remove from FROM
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
FROM ${BASE_IMAGE} # Removed --platform=$TARGETPLATFORM

ARG PROTOBUF_VERSION

# Copy and run the installation script
COPY install.sh /tmp/install.sh
RUN chmod +x /tmp/install.sh && \
    /tmp/install.sh && \
    rm /tmp/install.sh

# Add verification checks
RUN echo "check_cmd protoc --version" >> /opt/list_app_checks.sh && \
    echo "check_python_package protobuf" >> /opt/list_app_checks.sh

# Embed test.sh script
RUN cat <<EOF > /tmp/test_protobuf.sh && chmod +x /tmp/test_protobuf.sh
#!/usr/bin/env bash

echo "getting protobuf API implementation..."
echo "PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION = \$PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION"
echo ""

echo "getting protobuf Python package info..."
pip3 show protobuf
echo ""

echo "getting protobuf compiler version..."
protoc --version
echo ""

echo "listing protobuf libraries..."
ls /usr/local/lib/libproto* || echo "No protobuf libraries found in /usr/local/lib/"
echo ""
EOF
RUN /tmp/test_protobuf.sh && rm /tmp/test_protobuf.sh

# Embed test.py script
RUN cat <<EOF > /tmp/test_protobuf.py
#!/usr/bin/env python3
print('testing protobuf (cpp)...')

import google.protobuf
print('protobuf version: ' + str(google.protobuf.__version__))

# verify implementation is cpp
from google.protobuf.internal import api_implementation

protobuf_implementation = str(api_implementation.Type())

print(f'protobuf default API implementation: {str(api_implementation._implementation_type)}') # Changed _default_implementation_type to _implementation_type
print(f'protobuf active API implementation:  {protobuf_implementation}')

if protobuf_implementation != "cpp":
    raise ValueError(f'expected protobuf to have cpp implementation, but instead it has {protobuf_implementation} implementation')
    
print('protobuf (cpp) OK\n')
EOF
RUN python3 /tmp/test_protobuf.py && rm /tmp/test_protobuf.py
