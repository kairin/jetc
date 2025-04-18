# COMMIT-TRACKING: UUID-20240730-100000-B4D1
# Description: Embed install/test scripts, add verification checks.
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
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

# https://github.com/numpy/numpy/issues/18131#issuecomment-755438271
ENV OPENBLAS_CORETYPE=ARMV8

# 'numpy<2' (1.26.4) for <= cu126
# 'numpy' (2.2+) for >= cu128
ARG NUMPY_PACKAGE="numpy" \
    NUMPY_VERSION_MAJOR=2

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
