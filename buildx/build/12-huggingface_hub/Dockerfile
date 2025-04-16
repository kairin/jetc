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

# add downloader tool
COPY huggingface-downloader /usr/local/bin/
COPY huggingface-downloader.py /usr/local/bin/_huggingface-downloader.py

# Make sure directory exists for HF cache
RUN mkdir -p /data/models/huggingface

# install huggingface_hub package (with CLI), GitHub CLI, and Git LFS
RUN set -ex \
    # Fix: ModuleNotFoundError: No module named 'dataclasses' (on JetPack 4) \
    && pip3 install \
        huggingface_hub[cli]==${HUGGINGFACE_HUB_VERSION} \
        dataclasses \
    \
    # make sure it loads \
    && huggingface-cli --help \
    && huggingface-downloader --help \
    && pip3 show huggingface_hub \
    && python3 -c 'import huggingface_hub; print(huggingface_hub.__version__)' \
    \
    # Add verification check \
    && echo "check_python_pkg huggingface_hub" >> /opt/list_app_checks.sh \
    && echo "check_cmd huggingface-cli 'huggingface-cli --help'" >> /opt/list_app_checks.sh \
    && echo "check_cmd huggingface-downloader 'huggingface-downloader --help'" >> /opt/list_app_checks.sh \
    \
    # Install GitHub CLI and Git LFS \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        time \
        curl \
        gnupg \
        git-lfs \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && git lfs install \
    \
    # Add verification check for GitHub CLI and Git LFS \
    && echo "check_cmd gh 'gh --version'" >> /opt/list_app_checks.sh \
    && echo "check_cmd git-lfs 'git lfs --version'" >> /opt/list_app_checks.sh \
    \
    # Cleanup \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /root/.cache/pip