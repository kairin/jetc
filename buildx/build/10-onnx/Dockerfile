# COMMIT-TRACKING: UUID-20240730-170000-DYN1
# Description: Revert to dynamic BASE_IMAGE ARG.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 10-onnx/             <- Current directory
# │   │       └── Dockerfile       <- THIS FILE
# └── ...                        <- Other project files
#---
# name: onnx
# group: core
# depends: [python, protobuf]
# test: test.py
#---
# Use ARG for dynamic base image injection
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ARG ONNX_VERSION

RUN pip3 install onnx || \
    pip3 install git+https://github.com/onnx/onnx@${ONNX_VERSION} && \
    pip3 show onnx && \
    python3 -c 'import onnx; print(onnx.__version__)'
    
# error introduced by https://github.com/onnx/onnx/pull/5777 results in python protobuf mismatch
# https://github.com/onnx/onnx/blob/6ff456c1179c34827ad910e5601cb1486822d800/CMakeLists.txt#L249
#RUN set -ex \
#    && if [ `lsb_release --codename --short` != 'bionic' ]; then \
#        pip3 install protobuf==4.22.3; \
#    fi \
#    \
#    && pip3 install git+https://github.com/onnx/onnx@${ONNX_VERSION} \
#    && pip3 show onnx \
#    && python3 -c 'import onnx; print(onnx.__version__)'
