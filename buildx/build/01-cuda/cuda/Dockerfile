#---
# name: cuda (unified)
# group: cuda
# notes: Installs CUDA components, samples, or sets up pip cache based on INSTALL_MODE. Build includes tests.
# config: config.py
# depends: [build-essential] (implicitly handled by build system based on config)
# test: (embedded in Dockerfile)
#---
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

# --- Common ARGs ---
ARG DEBIAN_FRONTEND=noninteractive
ARG INSTALL_MODE="package" # Default mode (can be package, builtin, pip, samples)

# --- ARGs for 'package' mode ---
ARG CUDA_URL
ARG CUDA_DEB
ARG CUDA_PACKAGES
ARG CUDA_ARCH_LIST
ARG DISTRO

# --- ARGs for 'samples' mode ---
ARG CUDA_BRANCH
ARG CUDA_SAMPLES_MAKE='cmake'
ARG CUDA_SAMPLES_ROOT='/opt/cuda-samples'

# --- ARGs for 'pip' mode ---
ARG PIP_INDEX_REPO
ARG PIP_UPLOAD_REPO
ARG PIP_UPLOAD_USER
ARG PIP_UPLOAD_PASS
ARG PIP_TRUSTED_HOSTS
ARG TAR_INDEX_URL
ARG SCP_UPLOAD_URL
ARG SCP_UPLOAD_USER
ARG SCP_UPLOAD_PASS

# --- Installation Steps ---

# === Mode: package ===
# Install CUDA Toolkit from .deb and run basic tests
RUN if [ "${INSTALL_MODE}" = "package" ]; then \
        set -ex && \
        echo "INSTALL_MODE=package: Installing CUDA Toolkit..." && \
        \
        # Start install.sh logic
        ARCH=$(uname -m) && \
        ARCH_TYPE=$ARCH && \
        if [[ "$ARCH" == "aarch64" ]] && uname -a | grep -qi tegra; then ARCH_TYPE="tegra-aarch64"; fi && \
        echo "Detected architecture: ${ARCH_TYPE}" && \
        \
        apt-get update && \
        apt-get install -y --no-install-recommends binutils xz-utils wget ca-certificates && \
        \
        echo "Downloading ${CUDA_DEB}" && \
        mkdir -p /tmp/cuda && cd /tmp/cuda && \
        \
        if [[ "$ARCH_TYPE" == "tegra-aarch64" ]]; then \
            wget --quiet --show-progress --progress=bar:force:noscroll \
                https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}/arm64/cuda-${DISTRO}.pin \
                -O /etc/apt/preferences.d/cuda-repository-pin-600; \
        elif [[ "$ARCH_TYPE" == "aarch64" ]]; then \
            wget --quiet --show-progress --progress=bar:force:noscroll \
                https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}/sbsa/cuda-${DISTRO}.pin \
                -O /etc/apt/preferences.d/cuda-repository-pin-600; \
        else \
            # Assuming x86_64 or other non-ARM needing a pin file structure
             wget --quiet --show-progress --progress=bar:force:noscroll \
                https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}/$(uname -m)/cuda-${DISTRO}.pin \
                -O /etc/apt/preferences.d/cuda-repository-pin-600; \
        fi && \
        wget --quiet --show-progress --progress=bar:force:noscroll ${CUDA_URL} && \
        \
        dpkg -i *.deb && \
        cp /var/cuda-*-local/cuda-*-keyring.gpg /usr/share/keyrings/ && \
        \
        if [[ "$ARCH_TYPE" == "tegra-aarch64" ]]; then \
            ar x /var/cuda-tegra-repo-ubuntu*-local/cuda-compat-*.deb && \
            tar xvf data.tar.xz -C / ; \
        fi && \
        \
        apt-get update && \
        apt-get install -y --no-install-recommends ${CUDA_PACKAGES} && \
        \
        dpkg --list | grep cuda && \
        dpkg -P ${CUDA_DEB} && \
        rm -rf /tmp/cuda && \
        # End install.sh logic
        \
        # Start test.sh logic
        echo "=== CUDA version files ===" && \
        cat /usr/local/cuda/version* && \
        echo "" && \
        echo "=== Location of nvcc ===" && \
        which nvcc && \
        echo "" && \
        echo "=== nvcc version ===" && \
        nvcc --version && \
        echo "" && \
        echo "=== Supported GPU architectures by nvcc ===" && \
        nvcc --list-gpu-arch && \
        # End test.sh logic
        \
        # Cleanup
        rm -rf /var/lib/apt/lists/* && apt-get clean; \
    else \
        echo "INSTALL_MODE=${INSTALL_MODE}: Skipping CUDA Toolkit package installation and test."; \
    fi

# === Mode: samples ===
# Clone, build, and test CUDA Samples
RUN if [ "${INSTALL_MODE}" = "samples" ]; then \
        set -ex && \
        echo "INSTALL_MODE=samples: Installing and testing CUDA Samples..." && \
        apt-get update && apt-get install -y --no-install-recommends git make g++ freeglut3-dev libfreeimage-dev && \
        \
        git clone --branch ${CUDA_BRANCH} --depth=1 --recursive \
            https://github.com/NVIDIA/cuda-samples ${CUDA_SAMPLES_ROOT} && \
        \
        # Start install-samples.sh logic
        cd $CUDA_SAMPLES_ROOT && \
        \
        # Define functions inline or just execute logic directly
        if [ "$CUDA_SAMPLES_MAKE" == "make" ]; then \
            cd Samples/1_Utilities/deviceQuery && make && cd ../bandwidthTest && make && \
            cd ../../0_Introduction/matrixMul && make && cd ../vectorAdd && make && \
            cd $CUDA_SAMPLES_ROOT && make -j$(nproc) || echo "failed to make all CUDA samples"; \
        elif [ "$CUDA_SAMPLES_MAKE" == "make_flat" ]; then \
            cd Samples/deviceQuery && make && cd ../bandwidthTest && make && \
            cd ../matrixMul && make && cd ../vectorAdd && make && \
            cd $CUDA_SAMPLES_ROOT && make -j$(nproc) || echo "failed to make all CUDA samples"; \
        else \
            # cmake_all logic
            if [ $(uname -m) == "aarch64" ]; then \
                local patch="Samples/3_CUDA_Features/CMakeLists.txt"; \
                sed -i 's|add_subdirectory(cdp.*|#|g' $patch; \
                echo "Patched $patch"; \
                cat $patch; \
            fi && \
            mkdir build && cd build && cmake .. && make -j$(nproc) || echo "failed to cmake all CUDA samples" && \
            make install -j$(nproc) && \
            local out="$CUDA_SAMPLES_ROOT/bin/$(uname -m)/linux/release"; \
            mkdir -p $out || true; \
            set +x; \
            for i in $(find ./Samples -type d); do \
                local exe="$i/$(basename $i)"; \
                if [ -f "$exe" ]; then \
                    echo "Installing $exe -> $out"; \
                    cp $exe $out; \
                fi; \
            done; \
            set -x; \
            rm -rf $CUDA_SAMPLES_ROOT/build; \
        fi && \
        # End install-samples.sh logic
        \
        # Start test-samples.sh logic
        cd $CUDA_SAMPLES_ROOT/bin/$(uname -m)/linux/release && \
        ./deviceQuery && \
        ./bandwidthTest && \
        ./vectorAdd && \
        ./matrixMul && \
        # End test-samples.sh logic
        \
        # Cleanup
        rm -rf /var/lib/apt/lists/* && apt-get clean; \
    else \
        echo "INSTALL_MODE=${INSTALL_MODE}: Skipping CUDA Samples installation and test."; \
    fi

# === Environment Setup ===

# Common CUDA environment variables (for 'package' and 'builtin' modes)
ENV CUDA_HOME="/usr/local/cuda"
ENV NVCC_PATH="$CUDA_HOME/bin/nvcc"

RUN if [ "${INSTALL_MODE}" = "package" ] || [ "${INSTALL_MODE}" = "builtin" ]; then \
        echo "INSTALL_MODE=${INSTALL_MODE}: Setting CUDA environment variables..."; \
        export NVIDIA_VISIBLE_DEVICES=all; \
        export NVIDIA_DRIVER_CAPABILITIES=all; \
        export CUDAARCHS=${CUDA_ARCH_LIST}; \
        export CUDA_ARCHITECTURES=${CUDA_ARCH_LIST}; \
        # export CUDA_HOME="/usr/local/cuda"; # Already set above
        export CUDNN_LIB_PATH="/usr/lib/aarch64-linux-gnu"; \
        export CUDNN_LIB_INCLUDE_PATH="/usr/include"; \
        export CMAKE_CUDA_COMPILER=${NVCC_PATH}; \
        export CUDA_NVCC_EXECUTABLE=${NVCC_PATH}; \
        export CUDACXX=${NVCC_PATH}; \
        export TORCH_NVCC_FLAGS="-Xfatbin -compress-all"; \
        export CUDA_BIN_PATH="${CUDA_HOME}/bin"; \
        export CUDA_TOOLKIT_ROOT_DIR="${CUDA_HOME}"; \
        export PATH="$CUDA_HOME/bin:${PATH}"; \
        export LD_LIBRARY_PATH="${CUDA_HOME}/compat:${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}"; \
        export DEBIAN_FRONTEND=noninteractive; \
        # Add verification checks only for package/builtin modes
        echo "# Check for CUDA" >> /tmp/cuda_checks.sh; \
        echo "check_cmd nvcc 'NVIDIA CUDA Compiler'" >> /tmp/cuda_checks.sh; \
        echo "check_cmd nvidia-smi 'NVIDIA System Management Interface'" >> /tmp/cuda_checks.sh; \
        echo "check_cmd_output 'nvcc --version' 'Cuda compilation tools'" >> /tmp/cuda_checks.sh; \
        cat /tmp/cuda_checks.sh >> /opt/list_app_checks.sh; \
    else \
        echo "INSTALL_MODE=${INSTALL_MODE}: Skipping CUDA environment variable setup."; \
    fi

# Pip cache environment variables (for 'pip' mode)
RUN if [ "${INSTALL_MODE}" = "pip" ]; then \
        echo "INSTALL_MODE=pip: Setting pip cache environment variables..."; \
        export TAR_INDEX_URL=${TAR_INDEX_URL}; \
        export PIP_INDEX_URL=${PIP_INDEX_REPO}; \
        export PIP_TRUSTED_HOST=${PIP_TRUSTED_HOSTS}; \
        export TWINE_REPOSITORY_URL=${PIP_UPLOAD_REPO}; \
        export TWINE_USERNAME=${PIP_UPLOAD_USER}; \
        export TWINE_PASSWORD=${PIP_UPLOAD_PASS}; \
        export SCP_UPLOAD_URL=${SCP_UPLOAD_URL}; \
        export SCP_UPLOAD_USER=${SCP_UPLOAD_USER}; \
        export SCP_UPLOAD_PASS=${SCP_UPLOAD_PASS}; \
    else \
        echo "INSTALL_MODE=${INSTALL_MODE}: Skipping pip cache environment variable setup."; \
    fi

# Set ENV vars from the RUN commands above so they persist
ENV TAR_INDEX_URL=${TAR_INDEX_URL} \
    PIP_INDEX_URL=${PIP_INDEX_REPO} \
    PIP_TRUSTED_HOST=${PIP_TRUSTED_HOSTS} \
    TWINE_REPOSITORY_URL=${PIP_UPLOAD_REPO} \
    TWINE_USERNAME=${PIP_UPLOAD_USER} \
    TWINE_PASSWORD=${PIP_UPLOAD_PASS} \
    SCP_UPLOAD_URL=${SCP_UPLOAD_URL} \
    SCP_UPLOAD_USER=${SCP_UPLOAD_USER} \
    SCP_UPLOAD_PASS=${SCP_UPLOAD_PASS} \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=all \
    CUDAARCHS=${CUDA_ARCH_LIST} \
    CUDA_ARCHITECTURES=${CUDA_ARCH_LIST} \
    CUDNN_LIB_PATH="/usr/lib/aarch64-linux-gnu" \
    CUDNN_LIB_INCLUDE_PATH="/usr/include" \
    CMAKE_CUDA_COMPILER=${NVCC_PATH} \
    CUDA_NVCC_EXECUTABLE=${NVCC_PATH} \
    CUDACXX=${NVCC_PATH} \
    TORCH_NVCC_FLAGS="-Xfatbin -compress-all" \
    CUDA_BIN_PATH="${CUDA_HOME}/bin" \
    CUDA_TOOLKIT_ROOT_DIR="${CUDA_HOME}" \
    PATH="$CUDA_HOME/bin:${PATH}" \
    LD_LIBRARY_PATH="${CUDA_HOME}/compat:${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}" \
    DEBIAN_FRONTEND=noninteractive

WORKDIR /
