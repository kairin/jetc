#---
# name: rust
# group: build
# depends: [build-essential, python]
#---
ARG BASE_IMAGE=kairin/001:05-h5py
FROM ${BASE_IMAGE}

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN rustc --version && \
    pip3 install setuptools-rust
