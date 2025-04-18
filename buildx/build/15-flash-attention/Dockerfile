# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

#---
# name: flash-attention
# group: llm
# depends: [pytorch]
# requires: '>=35'
# test: test.py
#---
ARG BASE_IMAGE=kairin/001:14-xformers
FROM ${BASE_IMAGE}

# Build Arguments
ARG MAX_JOBS=6
ENV FLASH_ATTN_CUDA_ARCHS=87

# Single consolidated RUN command for speed and efficiency
RUN set -ex \
    # Install dependencies \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        python3-pip python3-setuptools git cmake build-essential \
    && pip3 install --no-cache-dir --upgrade pip setuptools wheel \
    \
    # Clone specific version \
    && rm -rf /opt/flash-attention \
    && git clone --depth=1 --branch=v2.7.4.post2 https://github.com/Dao-AILab/flash-attention /opt/flash-attention \
    && cd /opt/flash-attention \
    \
    # Apply patch directly instead of using a patch file \
    && sed -i 's|def get_platform():|def get_arch():\n    """\n    Returns the system aarch for the current system.\n    """\n    if sys.platform.startswith("linux"):\n        if platform.machine() == "x86_64":\n            return "x86_64"\n        if platform.machine() == "arm64" or platform.machine() == "aarch64":\n            return "aarch64"\n    elif sys.platform == "darwin":\n        mac_version = ".".join(platform.mac_ver()[0].split(".")[:2])\n        return f"macosx_{mac_version}_x86_64"\n    elif sys.platform == "win32":\n        return "win_amd64"\n    else:\n        raise ValueError("Unsupported platform: {}".format(sys.platform))\n\ndef get_system() -> str:\n    """\n    Returns the system name as used in wheel filenames.\n    """\n    if platform.system() == "Windows":\n        return "win"\n    elif platform.system() == "Darwin":\n        mac_version = ".".join(platform.mac_ver()[0].split(".")[:1])\n        return f"macos_{mac_version}"\n    elif platform.system() == "Linux":\n        return "linux"\n    else:\n        raise ValueError("Unsupported system: {}".format(platform.system()))\n\ndef get_platform() -> str:|' setup.py \
    && sed -i 's|    Returns the platform name as used in wheel filenames.|    Returns the platform name as used in wheel filenames.\n    """\n    return f"{get_system()}_{get_arch()}"|' setup.py \
    && sed -i 's|    if "80" in cuda_archs():.*|    cc_flag.append("-gencode")\n    cc_flag.append("arch=compute_87,code=sm_87")|' setup.py \
    \
    # Build with optimized parallelism \
    && mkdir -p /opt/wheels \
    && export CMAKE_BUILD_PARALLEL_LEVEL=${MAX_JOBS} \
    && python3 setup.py --verbose bdist_wheel --dist-dir /opt/wheels \
    && pip3 install /opt/wheels/flash_attn*.whl \
    \
    # Verify installation \
    && python3 -c "import flash_attn; print(f'Flash-Attention {flash_attn.__version__} installed successfully')" \
    && echo "check_python_pkg flash_attn" >> /opt/list_app_checks.sh \
    \
    # Cleanup \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /root/.cache/pip \
    && rm -rf /opt/flash-attention/build