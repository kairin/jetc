# COMMIT-TRACKING: UUID-20240730-101500-A1B2
# Description: Install 'openai-clip' instead of 'clip==1.0'.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── build/                     <- Current directory
# │   └── 16-stable-diffusion/   <- Current directory
# │       └── Dockerfile         <- THIS FILE
# └── ...                        <- Other project files

ARG BASE_IMAGE
FROM ${BASE_IMAGE}

# Install dependencies for Stable Diffusion
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3-pip \
        # Add other dependencies as needed
        && \
    # Install Python packages
    # Replace 'clip==1.0' with 'openai-clip'
    pip3 install --no-cache-dir \
        torch torchvision torchaudio \
        diffusers transformers accelerate \
        openai-clip \
        # Add other python packages as needed
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Add application code, models, etc.
# COPY . /app
# WORKDIR /app

# Set entrypoint or command
# CMD ["python3", "app.py"]
