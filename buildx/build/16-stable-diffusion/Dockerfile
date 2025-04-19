# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

#---
# name: stable-diffusion
# group: diffusion
# depends: [pytorch, torchvision, transformers]
# requires: '>=34.1.0'
# test: test.sh
# docs: docs.md
# notes: disabled on JetPack 4
#---

# COMMIT-TRACKING: UUID-20240730-150000-SED1
# Description: Remove ARG BASE_IMAGE; FROM line will be set by build script.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Parent directory
# │   └── build/                 <- Parent directory
# │       └── 16-stable-diffusion/ <- Current directory
# │           └── Dockerfile       <- THIS FILE
# └── ...                        <- Other project files

# The build script will replace the line below with the correct base image
FROM ${BASE_IMAGE}

# Install dependencies and set up Stable Diffusion repositories
RUN set -ex \
    # Install Python packages with version pinning \
    && pip3 install --no-cache-dir \
        diffusers==0.24.0 \
        openai-clip \
        kornia==0.7.0 \
        taming-transformers==0.0.1 \
        invisible-watermark==0.2.0 \
        einops==0.7.0 \
        pandas==2.1.1 \
        scipy==1.11.3 \
    \
    # Get Python dist-packages path \
    && PYTHON_DIST_PACKAGES=$(python3 -c 'import sys; print(f"/usr/local/lib/python{sys.version_info.major}.{sys.version_info.minor}/dist-packages")') \
    && wget https://raw.githubusercontent.com/CompVis/taming-transformers/master/taming/modules/vqvae/quantize.py -O $PYTHON_DIST_PACKAGES/taming/modules/vqvae/quantize.py \
    \
    # Clean before cloning \
    && rm -rf /opt/stable-diffusion /opt/stable-diffusion-optimized \
    \
    # Clone repositories \
    && git clone --depth=1 https://github.com/CompVis/stable-diffusion /opt/stable-diffusion \
    && git clone --depth=1 https://github.com/basujindal/stable-diffusion /opt/stable-diffusion-optimized \
    && cp -r /opt/stable-diffusion-optimized/optimizedSD /opt/stable-diffusion/ \
    && rm -rf /opt/stable-diffusion-optimized \
    \
    # Apply fixes \
    && sed -i \
        -e 's|from pytorch_lightning.utilities.distributed|#from pytorch_lightning.utilities.distributed|g' \
        -e 's|@rank_zero_only||g' \
        /opt/stable-diffusion/ldm/models/diffusion/ddpm.py \
    && sed -i \
        -e 's|from pytorch_lightning.utilities.distributed|#from pytorch_lightning.utilities.distributed|g' \
        -e 's|@rank_zero_only||g' \
        /opt/stable-diffusion/optimizedSD/ddpm.py \
    \
    # Create directories \
    && mkdir -p /data/models/diffusers \
    && mkdir -p /data/images/stable-diffusion \
    \
    # Add verification checks \
    && echo "# Check for Stable Diffusion packages" >> /tmp/sd_checks.sh \
    && echo "check_python_pkg diffusers" >> /tmp/sd_checks.sh \
    && echo "check_dir /opt/stable-diffusion 'Stable Diffusion'" >> /tmp/sd_checks.sh \
    && cat /tmp/sd_checks.sh >> /opt/list_app_checks.sh \
    \
    # Cleanup \
    && rm -rf /root/.cache/pip \
    && find /opt/stable-diffusion -name ".git" -type d -exec rm -rf {} + \
    && rm -f /tmp/sd_checks.sh

# add module to PYTHONPATH since it's not installable
ENV PYTHONPATH=${PYTHONPATH}:/opt/stable-diffusion \
    DIFFUSERS_CACHE=/data/models/diffusers

# Define volumes for persistent data
VOLUME ["/data/models/diffusers", "/data/images/stable-diffusion"]