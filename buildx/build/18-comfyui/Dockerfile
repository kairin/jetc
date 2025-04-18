# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

#---
# name: comfyui
# group: diffusion
# depends: [pytorch, torchvision, torchaudio, opencv, bitsandbytes, transformers, xformers, torchao, diffusers, huggingface_hub]
# requires: '>=35.0.0'
# docs: docs.md
#---
ARG BASE_IMAGE=kairin/001:17-stable-diffusion-webui
FROM ${BASE_IMAGE}

# Set environment variables for better reproducibility
ENV COMFYUI_ROOT=/opt/ComfyUI
ENV PORT=8188

# Copy local files early for better layer caching
COPY workflow ${COMFYUI_ROOT}/workflow
COPY extra ${COMFYUI_ROOT}/extra

# Consolidate all operations into a single RUN command to reduce layers
RUN set -ex \
    # Clean up existing directory to prevent conflicts
    && rm -rf ${COMFYUI_ROOT} \
    && mkdir -p ${COMFYUI_ROOT} \
    && cd /opt \
    \
    # Clone main repository and install requirements
    && git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git ${COMFYUI_ROOT} \
    && cd ${COMFYUI_ROOT} \
    && pip3 install -r requirements.txt \
    \
    # Create and change to custom_nodes directory
    && mkdir -p ${COMFYUI_ROOT}/custom_nodes \
    && cd ${COMFYUI_ROOT}/custom_nodes \
    \
    # Clone extension repositories
    && git clone --depth=1 --recursive https://github.com/ltdrdata/ComfyUI-Manager.git \
    && git clone --depth=1 --recursive https://github.com/discus0434/comfyui-flux-accelerator.git \
    && git clone --depth=1 --recursive https://github.com/pydn/ComfyUI-to-Python-Extension.git \
    && git clone --depth=1 --recursive https://github.com/johnnynunez/ComfyUI-Crystools.git \
    \
    # Install extension requirements
    && pip3 install --no-cache-dir \
        -r ${COMFYUI_ROOT}/custom_nodes/ComfyUI-Manager/requirements.txt \
        -r ${COMFYUI_ROOT}/custom_nodes/comfyui-flux-accelerator/requirements.txt \
        -r ${COMFYUI_ROOT}/custom_nodes/ComfyUI-to-Python-Extension/requirements.txt \
    \
    # Run flux-accelerator setup if available
    && cd ${COMFYUI_ROOT}/custom_nodes/comfyui-flux-accelerator/scripts \
    && if [ -f download_taef1.sh ]; then \
        chmod +x download_taef1.sh && bash download_taef1.sh; \
    else \
        echo "download_taef1.sh not found"; \
    fi \
    \
    # Install additional dependencies
    && pip3 install --no-cache-dir \
        deepdiff \
        onnxruntime-gpu \
        triton \
        lm_eval \
        vhacdx \
        manifold \
        openexr \
        diffusers \
        flash-attn \
        sageattention \
        torchao \
    \
    # Run initialization script
    && cd ${COMFYUI_ROOT} \
    && sh ${COMFYUI_ROOT}/extra/init.sh \
    \
    # Add verification checks
    && echo "check_dir ${COMFYUI_ROOT} 'ComfyUI'" >> /opt/list_app_checks.sh \
    && echo "check_dir ${COMFYUI_ROOT}/custom_nodes 'ComfyUI Custom Nodes'" >> /opt/list_app_checks.sh \
    \
    # Cleanup
    && find ${COMFYUI_ROOT} -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true \
    && rm -rf /root/.cache/pip

# Set working directory
WORKDIR ${COMFYUI_ROOT}

# Expose port for web interface
EXPOSE 8188

# Start ComfyUI server
CMD ["python3", "main.py", "--listen", "0.0.0.0", "--port", "${PORT:-8188}"]