# COMMIT-TRACKING: UUID-20240730-170000-DYN1
# Description: Revert to dynamic BASE_IMAGE ARG.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 01-01-arrow/         <- Current directory
# │   │       └── Dockerfile       <- THIS FILE
# └── ...                        <- Other project files
#---
# name: arrow
# group: core
# config: config.py
# depends: [cuda, cmake, python]
# # test: test.py # Removed as test is now embedded
# notes: installed under `/usr/local`
#---
# Use ARG for dynamic base image injection, with a default value
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
FROM --platform=linux/arm64 ${BASE_IMAGE}

ARG ARROW_BRANCH

RUN git clone --branch=${ARROW_BRANCH} --depth=1 --recursive https://github.com/apache/arrow /opt/arrow
    
RUN cd /opt/arrow/cpp && \
    mkdir build && \
    cd build && \
    cmake \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
	 -DARROW_CUDA=ON \
	 -DARROW_PYTHON=ON \
	 -DARROW_COMPUTE=ON \
	 -DARROW_CSV=ON \
	 -DARROW_DATASET=ON \
	 -DARROW_FILESYSTEM=ON \
	 -DARROW_HDFS=ON \
	 -DARROW_JSON=ON \
	 -DARROW_PARQUET=ON \
	 -DARROW_ORC=ON \
	 -DARROW_WITH_BZ2=ON \
	 -DARROW_WITH_LZ4=ON \
	 -DARROW_WITH_SNAPPY=ON \
	 -DARROW_WITH_ZLIB=ON \
	 -DARROW_WITH_ZSTD=ON \
	 ../ && \
    make -j$(nproc) && \
    make install
    
#RUN pip3 install -r /opt/arrow/python/requirements-wheel-build.txt

RUN export PYARROW_WITH_CUDA=1 && \
    export PYARROW_WITH_HDFS=1 && \
    export PYARROW_WITH_DATASET=1 && \
    export PYARROW_WITH_PARQUET=1 && \
    export PYARROW_WITH_ORC=1 && \
    export PYARROW_PARALLEL=$(nproc) && \
    #export ARROW_HOME=/usr/local && \
    #export PYARROW_CMAKE_OPTIONS="-DARROW_HOME=/usr/local" && \
    cd /opt/arrow/python && \
    python3 setup.py bdist_wheel && \
    cp dist/*.whl /opt
    
RUN pip3 install /opt/pyarrow*.whl
RUN pip3 show pyarrow && python3 -c 'import pyarrow; print(pyarrow.__version__);'

# Embed and run test.py logic
RUN echo '#!/usr/bin/env python3' > /tmp/test_arrow.py && \
    echo "print('testing PyArrow...')" >> /tmp/test_arrow.py && \
    echo "import pyarrow" >> /tmp/test_arrow.py && \
    echo "" >> /tmp/test_arrow.py && \
    echo "print('PyArrow version: ' + str(pyarrow.__version__))" >> /tmp/test_arrow.py && \
    echo "" >> /tmp/test_arrow.py && \
    echo "pyarrow.show_info()" >> /tmp/test_arrow.py && \
    python3 /tmp/test_arrow.py && \
    rm /tmp/test_arrow.py

# Add verification check for pyarrow
RUN echo "# Check for PyArrow" >> /tmp/arrow_checks.sh \
    && echo "check_python_package pyarrow 'PyArrow'" >> /tmp/arrow_checks.sh \
    && cat /tmp/arrow_checks.sh >> /opt/list_app_checks.sh
