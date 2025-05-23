# COMMIT-TRACKING: UUID-20240731-111500-HEREDOCFIX
# Description: Fix syntax error in RUN command using heredoc for test script.
# Author: GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Parent directory
# │   └── build/                 <- Parent directory
# │       └── 01-01-numba/       <- Current directory
# │           └── Dockerfile     <- THIS FILE
# └── ...                        <- Other project files

# Use ARG for dynamic base image injection, with a default value
ARG TARGETPLATFORM=linux/arm64
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}

# Install llvm-dev and check version in one layer
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
		  llvm-dev \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && echo "Installed llvm version:" \
    && llvm-config --version
    
# Note: The update-alternatives command below might be needed depending on the base image's LLVM setup.
# It's commented out as per the original file, but keep it in mind if llvmlite build fails.
# https://github.com/numba/llvmlite/issues/621#issuecomment-737100914
#RUN update-alternatives --install /usr/bin/llvm-config llvm-config /usr/bin/llvm-config-9 1
#RUN llvm-config --version

# Install numba and check version in one layer
RUN pip3 install --no-cache-dir --break-system-packages numba && \
    echo "Installed numba version:" && \
    pip3 show numba && python3 -c 'import numba; print(numba.__version__)'

# Embed and run test.py logic
# Note: Embedding the test script avoids needing a separate file and COPY command.
# Build-time test verifies CPU JIT; CUDA functionality relies on base image + runtime.
RUN cat <<EOF > /tmp/test_numba.py
#!/usr/bin/env python3
print('testing numba...')

import math
import numba
from numba import vectorize, guvectorize, cuda
import numpy as np

print('numba version: ' + str(numba.__version__))

# test scalar vectorization
print('testing cpu vectorized ufunc...')

@vectorize(['float32(float32, float32, float32)',
            'float64(float64, float64, float64)'])
def cpu_discriminant(a, b, c):
    return math.sqrt(b ** 2 - 4 * a * c)

N = 10000
dtype = np.float32

# prepare the input
A = np.array(np.random.sample(N), dtype=dtype)
B = np.array(np.random.sample(N) + 10, dtype=dtype)
C = np.array(np.random.sample(N), dtype=dtype)

D = cpu_discriminant(A, B, C)

print('cpu vectorized ufunc result:')
# print(D) # Commented out to avoid excessive output

# test array vectorization
print('testing cpu guvectorized ufunc...')

@guvectorize(['uint8[:], uint8[:], uint8[:]',
              'float32[:], float32[:], float32[:]'], 
              '(n),(n)->(n)')
def cpu_add_arrays(x, y, res):
    for i in range(x.shape[0]):
        res[i] = x[i] + y[i]

A = np.full((2,4,3), 1, dtype)
B = np.full(A.shape, 2, dtype)
C = cpu_add_arrays(A, B)

print('cpu guvectorized ufunc result:')
# print(C) # Commented out to avoid excessive output

print('numba OK\n')
EOF
RUN echo "Running embedded numba test script..." && \
    python3 /tmp/test_numba.py && \
    rm /tmp/test_numba.py

# Add verification checks for numba and llvm
RUN echo "# Check for Numba dependencies" >> /tmp/numba_checks.sh \
    && echo "check_cmd llvm-config 'LLVM Configuration Tool'" >> /tmp/numba_checks.sh \
    && echo "# Check for Numba" >> /tmp/numba_checks.sh \
    && echo "check_python_package numba 'Numba JIT Compiler'" >> /tmp/numba_checks.sh \
    && cat /tmp/numba_checks.sh >> /opt/list_app_checks.sh
