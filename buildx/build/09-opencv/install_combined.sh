#!/usr/bin/env bash

# COMMIT-TRACKING: UUID-20240801-160000-PLATFORM
# Description: Consolidated installation script for OpenCV
# Author: GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Main buildx directory
# │   └── build/                 <- Build directory
# │       └── 09-opencv/         <- Current directory
# │           └── install_combined.sh <- THIS FILE

# =========================================================================
# IMPORTANT: This build system requires Docker with buildx extension.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================
set -e

OPENCV_VERSION=${OPENCV_VERSION:-"4.8.1"}
OPENCV_URL=${OPENCV_URL:-""}
FORCE_BUILD=${FORCE_BUILD:-"off"}

ARCH=$(uname -i)
DISTRO=$(lsb_release -rs)

echo "ARCH:   $ARCH"
echo "DISTRO: $DISTRO"

# Install dependencies
install_dependencies() {
    echo "Installing dependencies for opencv ${OPENCV_VERSION}"
    
    if [[ $DISTRO == "18.04" || $DISTRO == "20.04" ]]; then
        EXTRAS="libavresample-dev libdc1394-22-dev"
    fi

    if [[ $DISTRO == "24.04" ]]; then
        EXTRAS="libtbbmalloc2 libtbb-dev $EXTRAS"
    else
        EXTRAS="libtbb2 libtbb2-dev liblapacke-dev $EXTRAS"
    fi

    apt-get update
    apt-get install -y --no-install-recommends \
            build-essential \
            gfortran \
            cmake \
            git \
            file \
            tar \
            libatlas-base-dev \
            libavcodec-dev \
            libavformat-dev \
            libcanberra-gtk3-module \
            libeigen3-dev \
            libglew-dev \
            libgstreamer-plugins-base1.0-dev \
            libgstreamer-plugins-good1.0-dev \
            libgstreamer1.0-dev \
            libgtk-3-dev \
            libjpeg-dev \
            libjpeg8-dev \
            libjpeg-turbo8-dev \
            liblapack-dev \
            libopenblas-dev \
            libpng-dev \
            libpostproc-dev \
            libswscale-dev \
            libtesseract-dev \
            libtiff-dev \
            libv4l-dev \
            libxine2-dev \
            libxvidcore-dev \
            libx264-dev \
            libgtkglext1 \
            libgtkglext1-dev \
            pkg-config \
            qv4l2 \
            v4l-utils \
            zlib1g-dev \
            $EXTRAS

    # on x86, the python dev packages are already installed in the NGC containers under conda
    # and installing them again from apt messes up their proper detection, so skip doing that
    # these are needed however on other platforms (like aarch64) in order to build opencv-python
    if [ $ARCH != "x86_64" ]; then
        echo "detected $ARCH, installing python3 dev packages..."

        if [[ $DISTRO != "24.04" ]]; then
            DIST_EXTRAS="python3-distutils python3-setuptools"
        fi

        apt-get install -y --no-install-recommends \
            python3-pip \
            python3-dev \
            $DIST_EXTRAS

        python3 -c 'import numpy; print("NumPy version before installation:", numpy.__version__)' 2>/dev/null

        if [ $? != 0 ]; then
            echo "NumPy not found. Installing NumPy 2.0..."
            apt-get update
            python3 -m pip install "numpy>=2.0.0" --break-system-packages
        fi
    fi

    rm -rf /var/lib/apt/lists/*
    apt-get clean
}

# Install from deb packages
install_from_deb() {
    local OPENCV_DEB=${1:-"OpenCV-${OPENCV_VERSION}-aarch64.tar.gz"}
    local OPENCV_URL=${2:-"$OPENCV_URL"}
    
    echo "OPENCV_URL=$OPENCV_URL"
    echo "OPENCV_DEB=$OPENCV_DEB"

    if [[ -z ${OPENCV_URL} || -z ${OPENCV_DEB} ]]; then
        echo "OPENCV_URL and OPENCV_DEB must be set as environment variables or as command-line arguments"
        return 1
    fi
    
    # install numpy if needed
    # Check if NumPy is installed
    python3 -c 'import numpy; print("NumPy version before installation:", numpy.__version__)' 2>/dev/null

    if [ $? != 0 ]; then
        echo "NumPy not found. Installing NumPy 2.0..."
        apt-get update
        python3 -m pip install "numpy>=2.0.0" --break-system-packages
    fi

    # Print the installed version after installation
    python3 -c 'import numpy; print("NumPy version after installation:", numpy.__version__)'

    # remove previous OpenCV installation if it exists
    apt-get purge -y '.*opencv.*' || echo "previous OpenCV installation not found"

    # download and extract the deb packages
    mkdir -p opencv
    cd opencv

    echo "Downloading OpenCV archive from ${OPENCV_URL}..."
    if ! wget --quiet --show-progress --progress=bar:force:noscroll --no-check-certificate "${OPENCV_URL}" -O "${OPENCV_DEB}"; then
        echo "❌ ERROR: Failed to download OpenCV archive from ${OPENCV_URL}"
        return 1
    fi

    echo "✅ Successfully downloaded ${OPENCV_DEB}"
    echo "Extracting ${OPENCV_DEB}..."
    tar -xzvf "${OPENCV_DEB}"

    # install the packages and their dependencies
    dpkg -i --force-depends *.deb
    apt-get update
    apt-get install -y -f --no-install-recommends
    dpkg -i *.deb
    rm -rf /var/lib/apt/lists/*
    apt-get clean

    # remove the original downloads
    cd ../
    rm -rf opencv

    # manage some install paths
    PYTHON3_VERSION=`python3 -c 'import sys; version=sys.version_info[:3]; print("{0}.{1}".format(*version))'`

    if [ $ARCH = "aarch64" ]; then
        local_include_path="/usr/local/include/opencv4"
        local_python_path="/usr/local/lib/python${PYTHON3_VERSION}/dist-packages/cv2"

        if [ -d "$local_include_path" ]; then
            echo "$local_include_path already exists, replacing..."
            rm -rf $local_include_path
        fi

        if [ -d "$local_python_path" ]; then
            echo "$local_python_path already exists, replacing..."
            rm -rf $local_python_path
        fi

        ln -s /usr/include/opencv4 $local_include_path
        ln -s /usr/lib/python${PYTHON3_VERSION}/dist-packages/cv2 $local_python_path

    elif [ $ARCH = "x86_64" ]; then
        opencv_conda_path="/opt/conda/lib/python${PYTHON3_VERSION}/site-packages/cv2"

        if [ -d "$opencv_conda_path" ]; then
            echo "$opencv_conda_path already exists, replacing..."
            rm -rf $opencv_conda_path
            ln -s /usr/lib/python${PYTHON3_VERSION}/site-packages/cv2 $opencv_conda_path
        fi
    fi
    
    return 0
}

# Main installation logic
main() {
    # Install dependencies first
    install_dependencies
    
    if [ "$FORCE_BUILD" == "on" ]; then
        echo "Forcing build of opencv-python ${OPENCV_VERSION}"
        return 1
    fi

    if [ ! -z "$OPENCV_URL" ]; then
        echo "Installing opencv ${OPENCV_VERSION} from deb packages"
        install_from_deb "OpenCV-${OPENCV_VERSION}.tar.gz" "$OPENCV_URL"
    else
        echo "Installing opencv ${OPENCV_VERSION} from pip"
        export OPENCV_DEB="OpenCV-${OPENCV_VERSION}.tar.gz"
        export OPENCV_URL=${TAR_INDEX_URL}/${OPENCV_DEB}
        install_from_deb "$OPENCV_DEB" "$OPENCV_URL" || \
        pip3 install opencv-contrib-python~=${OPENCV_VERSION}
    fi

    python3 -c "import cv2; print('OpenCV version:', str(cv2.__version__)); print(cv2.getBuildInformation())"
    return 0
}

# Run the main function
main
exit $?
