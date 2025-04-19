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

# COMMIT-TRACKING: UUID-20240730-170000-DYN1
# Description: Revert to dynamic BASE_IMAGE ARG.
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

# COMMIT-TRACKING: UUID-20240730-180000-LNT1
# Description: Fix taming-transformers path structure issues and add verification testing
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
# Use ARG for dynamic base image injection, with a default value
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
FROM --platform=linux/arm64 ${BASE_IMAGE}

# Install dependencies and set up Stable Diffusion repositories
RUN set -ex \
    # Install Python packages with version pinning \
    && pip3 install --no-cache-dir \
        diffusers==0.24.0 \
        openai-clip \
        kornia==0.7.0 \
        invisible-watermark==0.2.0 \
        einops==0.7.0 \
        pandas==2.1.1 \
        scipy==1.11.3 \
    \
    # Clone taming-transformers directly instead of pip install \
    && rm -rf /opt/taming-transformers \
    && git clone --depth=1 https://github.com/CompVis/taming-transformers /opt/taming-transformers \
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
    # Apply fixes with conditional checks \
    && grep -q "from pytorch_lightning.utilities.distributed" /opt/stable-diffusion/ldm/models/diffusion/ddpm.py && \
       sed -i \
           -e 's|from pytorch_lightning.utilities.distributed|#from pytorch_lightning.utilities.distributed|g' \
           -e 's|@rank_zero_only||g' \
           /opt/stable-diffusion/ldm/models/diffusion/ddpm.py || true \
    && grep -q "from pytorch_lightning.utilities.distributed" /opt/stable-diffusion/optimizedSD/ddpm.py && \
       sed -i \
           -e 's|from pytorch_lightning.utilities.distributed|#from pytorch_lightning.utilities.distributed|g' \
           -e 's|@rank_zero_only||g' \
           /opt/stable-diffusion/optimizedSD/ddpm.py || true \
    \
    # Create directories \
    && mkdir -p /data/models/stable-diffusion \
    && mkdir -p /data/models/diffusers \
    && mkdir -p /data/images/stable-diffusion \
    \
    # Create test script \
    && echo '#!/bin/bash' > /opt/test_sd.sh \
    && echo 'cd /opt/stable-diffusion && python3 -c "import sys; sys.path.append(\"/opt/taming-transformers\"); from ldm.util import instantiate_from_config; print(\"Stable Diffusion imports working\")"' >> /opt/test_sd.sh \
    && echo 'cd /opt/stable-diffusion && python3 -c "import sys; sys.path.append(\"/opt/taming-transformers\"); from taming.modules.vqvae.quantize import VectorQuantizer; print(\"Taming-transformers VectorQuantizer imported successfully\")"' >> /opt/test_sd.sh \
    && chmod +x /opt/test_sd.sh \
    && /opt/test_sd.sh \
    \
    # Add verification checks \
    && echo "# Check for Stable Diffusion packages" >> /tmp/sd_checks.sh \
    && echo "check_python_pkg diffusers" >> /tmp/sd_checks.sh \
    && echo "check_dir /opt/stable-diffusion 'Stable Diffusion'" >> /tmp/sd_checks.sh \
    && echo "check_dir /opt/taming-transformers 'Taming Transformers'" >> /tmp/sd_checks.sh \
    && echo "check_file /opt/test_sd.sh 'Stable Diffusion Test'" >> /tmp/sd_checks.sh \
    && cat /tmp/sd_checks.sh >> /opt/list_app_checks.sh \
    \
    # Cleanup \
    && rm -rf /root/.cache/pip \
    && find /opt/stable-diffusion /opt/taming-transformers -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true \
    && rm -f /tmp/sd_checks.sh

# add modules to PYTHONPATH since they're not installable
ENV PYTHONPATH=${PYTHONPATH}:/opt/stable-diffusion:/opt/taming-transformers \
    DIFFUSERS_CACHE=/data/models/diffusers

# Create wrapper script with usage instructions
RUN echo '#!/bin/bash' > /usr/local/bin/sd-txt2img && \
    echo '# Stable Diffusion txt2img wrapper script' >> /usr/local/bin/sd-txt2img && \
    echo 'MODEL="/data/models/stable-diffusion/sd-v1-4.ckpt"' >> /usr/local/bin/sd-txt2img && \
    echo 'PROMPT="${1:-a photograph of an astronaut riding a horse}"' >> /usr/local/bin/sd-txt2img && \
    echo 'OUTDIR="/data/images/stable-diffusion"' >> /usr/local/bin/sd-txt2img && \
    echo '' >> /usr/local/bin/sd-txt2img && \
    echo 'if [ ! -f "$MODEL" ]; then' >> /usr/local/bin/sd-txt2img && \
    echo '  echo "Downloading stable-diffusion model..."' >> /usr/local/bin/sd-txt2img && \
    echo '  mkdir -p /data/models/stable-diffusion' >> /usr/local/bin/sd-txt2img && \
    echo '  wget https://huggingface.co/CompVis/stable-diffusion-v-1-4-original/resolve/main/sd-v1-4.ckpt -O "$MODEL"' >> /usr/local/bin/sd-txt2img && \
    echo 'fi' >> /usr/local/bin/sd-txt2img && \
    echo '' >> /usr/local/bin/sd-txt2img && \
    echo 'mem_capacity=$(grep MemTotal /proc/meminfo | awk "{print \$2}")' >> /usr/local/bin/sd-txt2img && \
    echo 'if [ $mem_capacity -gt 8388608 ]; then' >> /usr/local/bin/sd-txt2img && \
    echo '  echo "Using standard txt2img (requires >8GB RAM)"' >> /usr/local/bin/sd-txt2img && \
    echo '  cd /opt/stable-diffusion && python3 scripts/txt2img.py --plms \\' >> /usr/local/bin/sd-txt2img && \
    echo '    --n_samples 1 --n_iter 1 --ddim_steps 25 \\' >> /usr/local/bin/sd-txt2img && \
    echo '    --outdir "$OUTDIR" \\' >> /usr/local/bin/sd-txt2img && \
    echo '    --ckpt "$MODEL" \\' >> /usr/local/bin/sd-txt2img && \
    echo '    --prompt "$PROMPT"' >> /usr/local/bin/sd-txt2img && \
    echo 'else' >> /usr/local/bin/sd-txt2img && \
    echo '  echo "Using optimized txt2img for lower memory usage"' >> /usr/local/bin/sd-txt2img && \
    echo '  cd /opt/stable-diffusion && python3 optimizedSD/optimized_txt2img.py \\' >> /usr/local/bin/sd-txt2img && \
    echo '    --sampler plms --seed 42 \\' >> /usr/local/bin/sd-txt2img && \
    echo '    --n_samples 1 --n_iter 1 --ddim_steps 25 \\' >> /usr/local/bin/sd-txt2img && \
    echo '    --outdir "$OUTDIR" \\' >> /usr/local/bin/sd-txt2img && \
    echo '    --ckpt "$MODEL" \\' >> /usr/local/bin/sd-txt2img && \
    echo '    --prompt "$PROMPT"' >> /usr/local/bin/sd-txt2img && \
    echo 'fi' >> /usr/local/bin/sd-txt2img && \
    chmod +x /usr/local/bin/sd-txt2img && \
    echo "echo 'Run sd-txt2img \"your prompt here\" to generate images'" >> /root/.bashrc

# Define volumes for persistent data
VOLUME ["/data/models/diffusers", "/data/images/stable-diffusion", "/data/models/stable-diffusion"]

# Set working directory
WORKDIR /opt/stable-diffusion

# Provide helpful usage information at container start
CMD echo "Stable Diffusion Container" && \
    echo "------------------------" && \
    echo "Usage examples:" && \
    echo "1. Generate an image with default prompt:" && \
    echo "   sd-txt2img" && \
    echo "2. Generate an image with custom prompt:" && \
    echo "   sd-txt2img \"a cat wearing sunglasses on a beach\"" && \
    echo "3. Run custom scripts:" && \
    echo "   cd /opt/stable-diffusion" && \
    echo "   python3 scripts/txt2img.py --help" && \
    echo "" && \
    echo "Images are saved to /data/images/stable-diffusion" && \
    echo "Models are stored in /data/models/stable-diffusion" && \
    echo "" && \
    exec /bin/bash