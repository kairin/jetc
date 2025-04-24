#--------------------------------------------------------------------------
# Stage: 01-01-arrow
# Base:  ${BASE_IMAGE} (Set by build-arg)
# Desc:  Builds Apache Arrow from source.
#--------------------------------------------------------------------------
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

LABEL maintainer="kairin"
LABEL stage="01-01-arrow"

# Build arguments
ARG ARROW_VERSION=17.0.0
ARG BUILD_DIR=/tmp/arrow_build

# Install build dependencies
# Update this list based on actual Arrow requirements for your base image
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    wget \
    # Arrow dependencies (Example - Verify these!)
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    liblz4-dev \
    libsnappy-dev \
    libzstd-dev \
    # Add others as needed (e.g., for parquet, flight, etc.)
    && rm -rf /var/lib/apt/lists/*

# Clone Arrow source
RUN mkdir -p ${BUILD_DIR} && \
    cd ${BUILD_DIR} && \
    git clone --branch apache-arrow-${ARROW_VERSION} --depth 1 https://github.com/apache/arrow.git arrow-src

# Build Arrow
# Combine cmake, make, make install into one RUN layer for better caching
# Ensure backslashes (\) are used correctly for line continuation
RUN cd ${BUILD_DIR}/arrow-src/cpp && \
    mkdir -p build && \
    cd build && \
    cmake \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
      -DCMAKE_BUILD_TYPE=Release \
      -DARROW_BUILD_TESTS=OFF \
      -DARROW_COMPUTE=ON \
      -DARROW_CSV=ON \
      -DARROW_DATASET=ON \
      -DARROW_FILESYSTEM=ON \
      -DARROW_IPC=ON \
      -DARROW_JSON=ON \
      -DARROW_PARQUET=ON \
      # Add optional components as needed
      -DARROW_PYTHON=OFF \ # Assuming Python bindings handled later
      -DARROW_FLIGHT=OFF \
      -DARROW_ORC=OFF \ # Disabled ORC as per original comment
      # --- Moved CMake flags inside cmake command ---
      -DARROW_WITH_BZ2=ON \
      -DARROW_WITH_LZ4=ON \
      -DARROW_WITH_SNAPPY=ON \
      -DARROW_WITH_ZLIB=ON \
      -DARROW_WITH_ZSTD=ON \
      # --- End moved flags ---
      ../ && \
    make -j$(nproc) && \
    make install && \
    # Cleanup build directory
    cd / && rm -rf ${BUILD_DIR}

# Optional: Verify installation (e.g., check for a library file)
RUN ldconfig && \
    ls /usr/local/lib/libarrow.so || (echo "libarrow.so not found!" && exit 1)

# Set environment variables if needed (e.g., for pkg-config)
# ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH

WORKDIR /
