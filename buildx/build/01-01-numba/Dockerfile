# COMMIT-TRACKING: UUID-20240730-130000-PEP1
# Description: Add --break-system-packages flag to pip install for numba.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Parent directory
# │   └── build/                 <- Parent directory
# │       └── 01-01-numba/       <- Current directory
# │           └── Dockerfile     <- THIS FILE
# └── ...                        <- Other project files

ARG BASE_IMAGE
FROM ${BASE_IMAGE}

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
# For more complex tests, consider using `COPY test.py /tmp/test_numba.py` instead.
RUN echo '#!/usr/bin/env python3' > /tmp/test_numba.py && \
    echo "print('testing numba...')" >> /tmp/test_numba.py && \
    echo "" >> /tmp/test_numba.py && \
    echo "import math" >> /tmp/test_numba.py && \
    echo "import numba" >> /tmp/test_numba.py && \
    echo "from numba import vectorize, guvectorize, cuda" >> /tmp/test_numba.py && \
    echo "import numpy as np" >> /tmp/test_numba.py && \
    echo "" >> /tmp/test_numba.py && \
    echo "print('numba version: ' + str(numba.__version__))" >> /tmp/test_numba.py && \
    echo "" >> /tmp/test_numba.py && \
    echo "# test scalar vectorization" >> /tmp/test_numba.py && \
    echo "print('testing cuda vectorized ufunc...')" >> /tmp/test_numba.py && \
    echo "" >> /tmp/test_numba.py && \
    echo "@vectorize(['float32(float32, float32, float32)'," >> /tmp/test_numba.py && \
    echo "            'float64(float64, float64, float64)']," >> /tmp/test_numba.py && \
    echo "           target='cuda')" >> /tmp/test_numba.py && \
    echo "def cu_discriminant(a, b, c):" >> /tmp/test_numba.py && \
    echo "    return math.sqrt(b ** 2 - 4 * a * c)" >> /tmp/test_numba.py && \
    echo "" >> /tmp/test_numba.py && \
    echo "N = 10000" >> /tmp/test_numba.py && \
    echo "dtype = np.float32" >> /tmp/test_numba.py && \
    echo "" >> /tmp/test_numba.py && \
    echo "# prepare the input" >> /tmp/test_numba.py && \
    echo "A = np.array(np.random.sample(N), dtype=dtype)" >> /tmp/test_numba.py && \
    echo "B = np.array(np.random.sample(N) + 10, dtype=dtype)" >> /tmp/test_numba.py && \
    echo "C = np.array(np.random.sample(N), dtype=dtype)" >> /tmp/test_numba.py && \
    echo "" >> /tmp/test_numba.py && \
    echo "D = cu_discriminant(A, B, C)" >> /tmp/test_numba.py && \
    echo "" >> /tmp/test_numba.py && \
    echo "print('cuda vectorized ufunc result:')" >> /tmp/test_numba.py && \
    echo "# print(D) # Commented out to avoid excessive output" >> /tmp/test_numba.py && \
    echo "" >> /tmp/test_numba.py && \
    echo "# test array vectorization" >> /tmp/test_numba.py && \
    echo "print('testing cuda guvectorized ufunc...')" >> /tmp/test_numba.py && \
    echo "" >> /tmp/test_numba.py && \
    echo "@guvectorize(['uint8[:], uint8[:], uint8[:]'," >> /tmp/test_numba.py && \
    echo "              'float32[:], float32[:], float32[:]'], " >> /tmp/test_numba.py && \
    echo "              '(n),(n)->(n)'," >> /tmp/test_numba.py && \
    echo "             target='cuda')" >> /tmp/test_numba.py && \
    echo "def cu_add_arrays(x, y, res):" >> /tmp/test_numba.py && \
    echo "    for i in range(x.shape[0]):" >> /tmp/test_numba.py && \
    echo "        res[i] = x[i] + y[i]" >> /tmp/test_numba.py && \
    echo "" >> /tmp/test_numba.py && \
    echo "A = np.full((2,4,3), 1, dtype)" >> /tmp/test_numba.py && \
    echo "B = np.full(A.shape, 2, dtype)" >> /tmp/test_numba.py && \
    echo "C = cu_add_arrays(A, B)" >> /tmp/test_numba.py && \
    echo "" >> /tmp/test_numba.py && \
    echo "print('cuda guvectorized ufunc result:')" >> /tmp/test_numba.py && \
    echo "# print(C) # Commented out to avoid excessive output" >> /tmp/test_numba.py && \
    echo "" >> /tmp/test_numba.py && \
    echo "print('numba OK\\n')" >> /tmp/test_numba.py && \
    echo "Running embedded numba test script..." && \
    python3 /tmp/test_numba.py && \
    rm /tmp/test_numba.py

# Add verification checks for numba and llvm
RUN echo "# Check for Numba dependencies" >> /tmp/numba_checks.sh \
    && echo "check_cmd llvm-config 'LLVM Configuration Tool'" >> /tmp/numba_checks.sh \
    && echo "# Check for Numba" >> /tmp/numba_checks.sh \
    && echo "check_python_package numba 'Numba JIT Compiler'" >> /tmp/numba_checks.sh \
    && cat /tmp/numba_checks.sh >> /opt/list_app_checks.sh
