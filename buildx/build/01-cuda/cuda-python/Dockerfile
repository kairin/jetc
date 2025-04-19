#---
# name: cuda-python (unified)
# group: cuda
# config: config.py
# requires: '>=34.1.0'
# depends: [cuda, numpy] # Handled by config.py
# test: (embedded in Dockerfile)
#---
# Hardcoded base image from the previous stage
FROM kairin/001:cuda

ARG CUDA_PYTHON_VERSION
ARG INSTALL_MODE="install" # Mode can be 'install' or 'build'

# Install dependencies needed for building or running tests
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    python3-pip \
    python3-setuptools \
    wheel \
    && rm -rf /var/lib/apt/lists/*

# --- Installation/Build Logic ---
RUN set -ex && \
    \
    # Mode: install (try pre-built wheel first)
    if [ "${INSTALL_MODE}" = "install" ]; then \
        echo "Attempting to install pre-built cuda-python ${CUDA_PYTHON_VERSION}..." && \
        pip3 install --no-cache-dir cuda-python==${CUDA_PYTHON_VERSION} || \
        pip3 install --no-cache-dir cuda_core cuda_bindings==${CUDA_PYTHON_VERSION} || \
        (echo "Pre-built wheel not found or failed to install for ${CUDA_PYTHON_VERSION}. Build required." && exit 1); \
    fi; \
    \
    # Mode: build (or if install failed and INSTALL_MODE was install)
    if [ "${INSTALL_MODE}" = "build" ] || { [ "${INSTALL_MODE}" = "install" ] && [ $? -ne 0 ]; }; then \
        echo "Building cuda-python ${CUDA_PYTHON_VERSION} from source..." && \
        SRC=/opt/cuda-python && \
        WHL=/opt/wheels && \
        mkdir -p $WHL && \
        export MAX_JOBS=$(nproc) && \
        \
        git clone --branch v$CUDA_PYTHON_VERSION --depth=1 https://github.com/NVIDIA/cuda-python $SRC && \
        \
        # Check version for build structure (requires vercmp or equivalent logic)
        # Simple string comparison might work for basic cases, otherwise install 'dpkg-dev' for vercmp
        # Assuming simple comparison for now:
        if [[ "${CUDA_PYTHON_VERSION}" > "12.5" ]]; then \
            echo "Using multi-wheel build structure (>=12.6)..." && \
            cd $SRC/cuda_core && \
            pip3 wheel . --no-deps --wheel-dir $WHL --verbose && \
            cd $SRC/cuda_bindings && \
            pip3 wheel . --no-deps --wheel-dir $WHL --verbose; \
        else \
            echo "Using single-wheel build structure (<12.6)..." && \
            cd $SRC && \
            sed 's|^numpy.=.*|numpy|g' -i requirements.txt && \
            sed 's|^numba.=.*|numba|g' -i requirements.txt && \
            pip3 install --no-cache-dir -r requirements.txt && \
            python3 setup.py bdist_wheel --verbose --dist-dir $WHL; \
        fi && \
        \
        cd / && rm -rf $SRC && \
        pip3 install --no-cache-dir $WHL/cuda*.whl && \
        # Optional: Upload wheel if TWINE vars are set
        ( twine upload --verbose $WHL/cuda*.whl || echo "failed to upload wheel to ${TWINE_REPOSITORY_URL}" ) && \
        rm -rf $WHL; \
    fi

# --- Test Execution ---
COPY cuda-python/utils.py cuda-python/test_driver.py cuda-python/test_runtime.py /tmp/cuda-python/
RUN echo "Running cuda-python tests..." && \
    python3 /tmp/cuda-python/test_runtime.py && \
    python3 /tmp/cuda-python/test_driver.py && \
    # Verify installation
    python3 -c 'import cuda; print(f"Successfully imported cuda-python version: {cuda.__version__}")' && \
    (pip3 show cuda_core cuda_bindings || pip3 show cuda-python) && \
    rm -rf /tmp/cuda-python

WORKDIR /
