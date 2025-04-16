#---
# name: stable-diffusion-webui
# group: diffusion
# depends: [pytorch, torchvision, transformers, xformers, pycuda, opencv, onnxruntime]
# requires: '>=34.1.0'
# docs: docs.md
# notes: disabled on JetPack 4
#---
ARG BASE_IMAGE=kairin/001:16-stable-diffusion
FROM ${BASE_IMAGE}

ARG STABLE_DIFFUSION_WEBUI_REF="refs/heads/master" 
ARG STABLE_DIFFUSION_WEBUI_SHA="master"
ARG AUTOMATIC1111_ROOT_DIR="/opt/stable-diffusion-webui"

ADD https://api.github.com/repos/AUTOMATIC1111/stable-diffusion-webui/git/${STABLE_DIFFUSION_WEBUI_REF} /tmp/stable_diffusion_webui_version.json

COPY install_extensions.sh /tmp/

RUN set -ex \
    && git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui /opt/stable-diffusion-webui \
    && git -C /opt/stable-diffusion-webui checkout ${STABLE_DIFFUSION_WEBUI_SHA} \
    \
    # Fix: ControlNet init warning: Unable to install insightface automatically. Please try run `pip install insightface` manually. \
    # Fix: https://github.com/AUTOMATIC1111/stable-diffusion-webui/issues/13236 \
    && PYTHONPATH="$AUTOMATIC1111_ROOT_DIR" pip3 install httpx==0.24.1 insightface GitPython \
    && PYTHONPATH="$AUTOMATIC1111_ROOT_DIR" /tmp/install_extensions.sh \
        https://github.com/dusty-nv/stable-diffusion-webui-tensorrt \
        https://github.com/Mikubill/sd-webui-controlnet \
        https://github.com/zanllp/sd-webui-infinite-image-browsing \
        https://github.com/ahgsql/StyleSelectorXL \
        https://github.com/thomasasfk/sd-webui-aspect-ratio-helper \
        https://github.com/BlafKing/sd-civitai-browser-plus \
    && PYTHONPATH="$AUTOMATIC1111_ROOT_DIR" python3 -c 'from modules import launch_utils; launch_utils.args.skip_python_version_check=True; launch_utils.prepare_environment()' \
    # partially initialized module 'cv2' has no attribute 'gapi_wip_gst_GStreamerPipeline' \
    && /tmp/opencv/install.sh \
    # TypeError: 'type' object is not subscriptable \
    && sed 's|dict\[str, OptionInfo\]|dict|g' -i $AUTOMATIC1111_ROOT_DIR/modules/options.py \
    && sed 's|dict\[.*\]|dict|g' -i $AUTOMATIC1111_ROOT_DIR/modules/processing.py \
    && sed 's|list\[.*\]|list|g' -i $AUTOMATIC1111_ROOT_DIR/modules/processing.py \
    && sed 's|dict\[.*\]|dict|g' -i $AUTOMATIC1111_ROOT_DIR/modules/script_callbacks.py \
    && sed 's|list\[.*\]|list|g' -i $AUTOMATIC1111_ROOT_DIR/modules/script_callbacks.py \
    \
    # test that it loads \
    && cd /opt/stable-diffusion-webui \
    && PYTHONPATH="$AUTOMATIC1111_ROOT_DIR" python3 launch.py --help \
    && PYTHONPATH="$AUTOMATIC1111_ROOT_DIR" pip3 show insightface \
    && PYTHONPATH="$AUTOMATIC1111_ROOT_DIR" python3 -c 'import insightface; print(insightface.__version__);' \
    \
    # Cleanup \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# set the cache dir for models
ENV DIFFUSERS_CACHE=/data/models/diffusers \
    PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128

# Add memory optimization for Jetson devices
RUN echo "export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128" >> /etc/profile.d/sd-webui.sh && \
    chmod +x /etc/profile.d/sd-webui.sh

# Create models directory structure
RUN mkdir -p /data/models/stable-diffusion

# Add verification checks for SD WebUI packages
RUN echo "# Check for SD WebUI components" >> /tmp/sdwui_checks.sh \
    && echo "check_dir /opt/stable-diffusion-webui 'Stable Diffusion WebUI'" >> /tmp/sdwui_checks.sh \
    && echo "check_python_pkg insightface" >> /tmp/sdwui_checks.sh \
    && echo "check_dir /opt/stable-diffusion-webui/extensions 'WebUI Extensions'" >> /tmp/sdwui_checks.sh \
    && cat /tmp/sdwui_checks.sh >> /opt/list_app_checks.sh

# Define explicit volumes for persistent data
VOLUME ["/data/models", "/opt/stable-diffusion-webui/outputs"]

# Models need to be downloaded after container startup
# Either through the WebUI interface or using tools like huggingface-cli

# Start-up command with memory optimizations and VAE precision fix
CMD ["/bin/bash", "-c", "cd /opt/stable-diffusion-webui && echo 'Notice: No models found. Please download models using the WebUI interface.' && python3 launch.py --data=/data/models/stable-diffusion --enable-insecure-extension-access --xformers --listen --port=7860 --medvram --opt-sdp-attention --no-half-vae"]