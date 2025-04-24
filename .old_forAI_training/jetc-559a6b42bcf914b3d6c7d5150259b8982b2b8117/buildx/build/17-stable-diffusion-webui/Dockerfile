# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

#---
# name: stable-diffusion-webui
# group: diffusion
# depends: [pytorch, torchvision, cuda, cudnn, tensorrt, onnxruntime, opencv, cmake, python, rust]
# requires: '>=35.2.1'
# test: test.sh
# docs: docs.md
#---
# Use ARG for dynamic base image injection, with a default value
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
FROM --platform=linux/arm64 ${BASE_IMAGE}

# Determine appropriate branch/tag based on L4T version and install extensions
RUN set -ex \
    # Get L4T version and set appropriate branch/tag \
    && L4T_VERSION=$(cat /etc/nv_tegra_release | grep -o 'R[0-9]\+.[0-9]\+.[0-9]\+' | sed 's/R//') \
    && L4T_MAJOR=$(echo $L4T_VERSION | cut -d. -f1) \
    && if [ "$L4T_MAJOR" -lt 36 ]; then \
         echo "Using v1.6.0 for L4T < 36 (Python 3.8 compatibility)" \
         && export STABLE_DIFFUSION_WEBUI_REF="refs/tags/v1.6.0" \
         && export STABLE_DIFFUSION_WEBUI_SHA="v1.6.0"; \
       else \
         echo "Using master branch for L4T >= 36" \
         && export STABLE_DIFFUSION_WEBUI_REF="refs/heads/master" \
         && export STABLE_DIFFUSION_WEBUI_SHA="master"; \
       fi \
    \
    # Add GitHub cache-busting trick \
    && curl -s -o /tmp/stable_diffusion_webui_version.json \
       "https://api.github.com/repos/AUTOMATIC1111/stable-diffusion-webui/git/${STABLE_DIFFUSION_WEBUI_REF}" \
    \
    # Set root directory \
    && export AUTOMATIC1111_ROOT_DIR="/opt/stable-diffusion-webui" \
    \
    # Clone repo and checkout appropriate version \
    && git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui $AUTOMATIC1111_ROOT_DIR \
    && git -C $AUTOMATIC1111_ROOT_DIR checkout ${STABLE_DIFFUSION_WEBUI_SHA} \
    \
    # Fix: Install required dependencies \
    && PYTHONPATH="$AUTOMATIC1111_ROOT_DIR" pip3 install --no-cache-dir httpx==0.24.1 insightface GitPython \
    \
    # Prepare extension directory \
    && mkdir -p "$AUTOMATIC1111_ROOT_DIR/extensions" \
    \
    # INSTALL EXTENSIONS SCRIPT INCORPORATED DIRECTLY \
    && ROOT="$AUTOMATIC1111_ROOT_DIR" \
    && PYTHONPATH="$ROOT" \
    && extensions_dir="$ROOT/extensions" \
    && builtin_extensions=("extra-options-section" "hypertile" "prompt-bracket-checker" "canvas-zoom-and-pan" "mobile" "LDSR" "Lora" "SwinIR" "ScuNET") \
    && green="\033[1;32m" \
    && red="\033[1;31m" \
    && yellow="\033[1;33m" \
    && suffix="\033[0m" \
    \
    # Define log function \
    && log() { \
         local color="$1"; \
         local message="$2"; \
         case "$color" in \
           "green") echo -e "${green}${message}${suffix}" ;; \
           "red") echo -e "${red}${message}${suffix}" ;; \
           "yellow") echo -e "${yellow}${message}${suffix}" ;; \
           *) echo "$message" ;; \
         esac; \
       } \
    \
    # Define install function \
    && install() { \
         local repository_url="$1"; \
         local repository_name=$(echo "$repository_url" | rev | cut -d'/' -f1 | rev); \
         local repository_path="$extensions_dir/$repository_name"; \
         local repository_install_script_path="$repository_path/install.py"; \
         local repository_requirements_file="$repository_path/requirements.txt"; \
         if [ -f "$repository_requirements_file" ]; then \
           sed 's|^torch.*|torch|g' -i "$repository_requirements_file"; \
           sed 's|^torchvision.*|torchvision|g' -i "$repository_requirements_file"; \
           sed 's|^onnx.*|onnx|g' -i "$repository_requirements_file"; \
           sed 's|^onnxruntime.*|onnxruntime|g' -i "$repository_requirements_file"; \
           sed 's|^numpy.*|numpy|g' -i "$repository_requirements_file"; \
           sed 's|^opencv-python.*|opencv-python|g' -i "$repository_requirements_file"; \
         fi; \
         if [ -f "$repository_install_script_path" ]; then \
           PYTHONPATH=${ROOT} python3 "$repository_install_script_path"; \
           log green "[INSTALL] ✅ Install Script of $repository_name is completed!"; \
         else \
           log red "[INSTALL] Install Script install.py not found for $repository_name in $repository_path..."; \
         fi; \
       } \
    \
    # Define clone function \
    && clone() { \
         local repository_url="$1"; \
         local repository_name=$(echo "$repository_url" | rev | cut -d'/' -f1 | rev); \
         local repository_path="$extensions_dir/$repository_name"; \
         log green "[GIT] Cloning $repository_name to $repository_path..."; \
         git clone --jobs 0 "$repository_url" "$repository_path"; \
       } \
    \
    # Define remove function \
    && remove() { \
         local repository_name="$1"; \
         local repository_path="$extensions_dir/$repository_name"; \
         if [ -d "$repository_path" ]; then \
           rm -rf "$repository_path"; \
           log yellow "[REMOVED] ✅ Removed previous version of $repository_name..."; \
         fi; \
       } \
    \
    # Install extensions \
    && extension_urls=( \
         "https://github.com/dusty-nv/stable-diffusion-webui-tensorrt" \
         "https://github.com/Mikubill/sd-webui-controlnet" \
         "https://github.com/zanllp/sd-webui-infinite-image-browsing" \
         "https://github.com/ahgsql/StyleSelectorXL" \
         "https://github.com/thomasasfk/sd-webui-aspect-ratio-helper" \
         "https://github.com/BlafKing/sd-civitai-browser-plus" \
       ) \
    \
    # Install each extension \
    && for repository_url in "${extension_urls[@]}"; do \
         repository_name=$(echo "$repository_url" | rev | cut -d'/' -f1 | rev); \
         remove "$repository_name"; \
         clone "$repository_url"; \
         install "$repository_url"; \
       done \
    \
    # Verify extension installation \
    && ls -la $extensions_dir \
    && for ext in tensorrt controlnet infinite-image-browsing StyleSelectorXL aspect-ratio-helper civitai-browser-plus; do \
         [ -d "$extensions_dir/*$ext*" ] || echo "Warning: Extension $ext may not be properly installed"; \
       done \
    \
    # Prepare environment \
    && PYTHONPATH="$AUTOMATIC1111_ROOT_DIR" python3 -c 'from modules import launch_utils; launch_utils.args.skip_python_version_check=True; launch_utils.prepare_environment()' \
    \
    # Fix OpenCV issue \
    && /tmp/opencv/install.sh || true \
    \
    # Apply Python type annotation fixes \
    && sed 's|dict\[str, OptionInfo\]|dict|g' -i $AUTOMATIC1111_ROOT_DIR/modules/options.py \
    && sed 's|dict\[.*\]|dict|g' -i $AUTOMATIC1111_ROOT_DIR/modules/processing.py \
    && sed 's|list\[.*\]|list|g' -i $AUTOMATIC1111_ROOT_DIR/modules/processing.py \
    && sed 's|dict\[.*\]|dict|g' -i $AUTOMATIC1111_ROOT_DIR/modules/script_callbacks.py \
    && sed 's|list\[.*\]|list|g' -i $AUTOMATIC1111_ROOT_DIR/modules/script_callbacks.py \
    \
    # Add verification checks \
    && echo "check_dir $AUTOMATIC1111_ROOT_DIR 'Stable Diffusion WebUI'" >> /opt/list_app_checks.sh \
    && echo "check_dir $extensions_dir 'WebUI Extensions'" >> /opt/list_app_checks.sh \
    \
    # Ensure permissions are correct \
    && find $AUTOMATIC1111_ROOT_DIR -type d -exec chmod 755 {} \; \
    && find $AUTOMATIC1111_ROOT_DIR -type f -name "*.py" -exec chmod 644 {} \; \
    \
    # Thorough cleanup \
    && rm -rf /root/.cache/pip \
    && find "$AUTOMATIC1111_ROOT_DIR" -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true \
    && rm -f /tmp/stable_diffusion_webui_version.json

# Create directory for models and set up volumes
RUN mkdir -p /data/models/stable-diffusion
VOLUME ["/data/models/stable-diffusion", "/data/images/stable-diffusion"]

# Launch command with optimized settings for Jetson
CMD ["/bin/bash", "-c", "cd /opt/stable-diffusion-webui && echo 'Notice: No models found. Please download models using the WebUI interface.' && python3 launch.py --data=/data/models/stable-diffusion --enable-insecure-extension-access --xformers --listen --port=7860 --medvram --opt-sdp-attention --no-half-vae"]