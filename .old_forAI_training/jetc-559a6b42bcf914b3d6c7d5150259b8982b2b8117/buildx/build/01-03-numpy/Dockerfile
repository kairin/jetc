# COMMIT-TRACKING: UUID-20240730-180000-LNT1
# Description: Consolidate config.py logic into Dockerfile
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 01-01-numpy/         <- Current directory
# │   │       └── Dockerfile       <- THIS FILE
# └── ...                        <- Other project files
#---
# name: numpy
# group: core
# depends: [build-essential, python]
# # test: test.py # Removed as test is now embedded
#---
# Use ARG for dynamic base image injection, with a default value
ARG TARGETPLATFORM=linux/arm64
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}

# https://github.com/numpy/numpy/issues/18131#issuecomment-755438271
ENV OPENBLAS_CORETYPE=ARMV8

# ARG to determine CUDA version at build time
# Set at build time with --build-arg CUDA_VERSION=x.y
# Default values are set for numpy 2.x (CUDA > 12.6)
ARG CUDA_VERSION="12.7"
ARG NUMPY_PACKAGE="numpy"
ARG NUMPY_VERSION_MAJOR=2

# Logic that would have been in config.py
# If building with CUDA <= 12.6, builder should pass:
# --build-arg CUDA_VERSION=12.6 --build-arg NUMPY_PACKAGE="numpy<2" --build-arg NUMPY_VERSION_MAJOR=1
ENV NUMPY_PACKAGE="$NUMPY_PACKAGE" \
    NUMPY_VERSION_MAJOR="$NUMPY_VERSION_MAJOR"

# Install numpy and check/reinstall numba if necessary
RUN set -ex && \
    pip3 install --no-cache-dir --force-reinstall ${NUMPY_PACKAGE} && \
    echo "Installed numpy version:" && \
    pip3 show numpy && python3 -c 'import numpy; print(numpy.__version__)' && \
    # Check if numba is installed and if it imports correctly after numpy update
    (pip3 show numba > /dev/null 2>&1 && \
     ! python3 -c 'import numba' > /dev/null 2>&1 && \
     echo "Numba import failed after numpy update, reinstalling numba..." && \
     pip3 install --no-cache-dir --force-reinstall numba) || \
    echo "Numba not found or imports correctly, skipping reinstall."

# Embed and run test.py logic
RUN echo '#!/usr/bin/env python3' > /tmp/test_numpy.py && \
    echo "print('testing numpy...')" >> /tmp/test_numpy.py && \
    echo "import numpy as np" >> /tmp/test_numpy.py && \
    echo "print('numpy version: ' + str(np.__version__))" >> /tmp/test_numpy.py && \
    echo "print(np.show_config())" >> /tmp/test_numpy.py && \
    echo "print('numpy OK\\n')" >> /tmp/test_numpy.py && \
    echo "Running embedded numpy test script..." && \
    python3 /tmp/test_numpy.py && \
    rm /tmp/test_numpy.py

# Add verification checks for numpy
RUN echo "# Check for Numpy" >> /tmp/numpy_checks.sh \
    && echo "check_python_package numpy 'Numpy numerical computing library'" >> /tmp/numpy_checks.sh \
    && cat /tmp/numpy_checks.sh >> /opt/list_app_checks.sh
