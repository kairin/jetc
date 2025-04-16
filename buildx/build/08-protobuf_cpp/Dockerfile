# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

#---
# name: protobuf:cpp
# alias: protobuf
# group: build
# config: config.py
# depends: [build-essential, python]
# test: [test.py, test.sh]
# notes: install protobuf using pip
#---
ARG BASE_IMAGE=kairin/001:07-protobuf_apt
FROM ${BASE_IMAGE}

RUN apt-get update && apt-get install -y --no-install-recommends python3-pip

# Install the latest protobuf using pip
RUN pip install --upgrade protobuf
