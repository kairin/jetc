#---
# name: huggingface_hub
# group: llm
# depends: [python]
# test: test.py
# notes: provides `huggingface-cli` and `huggingface-downloader` tools
#---
ARG BASE_IMAGE=kairin/001:11-diffusers
FROM ${BASE_IMAGE}

# Set default version if not provided
ARG HUGGINGFACE_HUB_VERSION=0.17.3

# set the model cache dir
ENV TRANSFORMERS_CACHE=/data/models/huggingface \
    HUGGINGFACE_HUB_CACHE=/data/models/huggingface \
    HF_HOME=/data/models/huggingface

# Consolidating all operations into a single RUN command to minimize layers
RUN set -ex \
    # First create directories 
    && mkdir -p /data/models/huggingface \
    \
    # Install apt packages in a single operation 
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        time \
        curl \
        gnupg \
        git-lfs \
    \
    # Setup GitHub CLI 
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && git lfs install \
    \
    # Install Python packages with no-cache to reduce layer size
    && pip3 install --no-cache-dir \
        huggingface_hub[cli]==${HUGGINGFACE_HUB_VERSION} \
        dataclasses \
    \
    # Add verification checks
    && echo "check_python_pkg huggingface_hub" >> /opt/list_app_checks.sh \
    && echo "check_cmd huggingface-cli 'huggingface-cli --help'" >> /opt/list_app_checks.sh \
    && echo "check_cmd huggingface-downloader 'huggingface-downloader --help'" >> /opt/list_app_checks.sh \
    && echo "check_cmd gh 'gh --version'" >> /opt/list_app_checks.sh \
    && echo "check_cmd git-lfs 'git lfs --version'" >> /opt/list_app_checks.sh \
    \
    # Verify installations
    && huggingface-cli --help \
    && pip3 show huggingface_hub \
    && python3 -c 'import huggingface_hub; print(huggingface_hub.__version__)' \
    \
    # Thorough cleanup to reduce image size
    && apt-get clean \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /root/.cache/pip \
    && rm -rf /tmp/*

# These COPY instructions need to remain separate since they reference local files
COPY huggingface-downloader /usr/local/bin/
COPY huggingface-downloader.py /usr/local/bin/_huggingface-downloader.py

# Final verification of the downloader tool
RUN huggingface-downloader --help