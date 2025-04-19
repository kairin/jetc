# COMMIT-TRACKING: UUID-20240730-220000-PLATALL
# Description: Consolidate commit-tracking headers and enforce --platform=linux/arm64 in FROM.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 01-00-build-essential/ <- Current directory
# │   │       └── Dockerfile       <- THIS FILE
# └── ...                        <- Other project files
# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

#---
# name: build-essential
# group: build
# notes: installs compilers, build tools & configures the default locale
#---
# Use ARG for dynamic base image injection, with a default value
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
FROM --platform=linux/arm64 ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive \
    LANGUAGE=en_US:en \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8
    #TERM=dumb

RUN touch /opt/list_app_checks.sh

RUN set -ex \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        locales \
        locales-all \
        tzdata \
        build-essential \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        lsb-release \
        pkg-config \
        gnupg \
        git \
        git-lfs \
        gdb \
        wget \
        wget2 \
        curl \
        nano \
        zip \
        unzip \
        time \
        sshpass \
        ssh-client \
        xfe \
        aptitude \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && gcc --version \
    && g++ --version

# Embed vercmp script
RUN echo '#!/usr/bin/env bash' > /tmp/vercmp && \
    echo '#' >> /tmp/vercmp && \
    echo '# Backportable version comparison: https://stackoverflow.com/a/4025065' >> /tmp/vercmp && \
    echo '#' >> /tmp/vercmp && \
    echo 'function vercmp() {' >> /tmp/vercmp && \
    echo '    if [[ $1 == $2 ]]' >> /tmp/vercmp && \
    echo '    then' >> /tmp/vercmp && \
    echo '        echo "0"' >> /tmp/vercmp && \
    echo '        return' >> /tmp/vercmp && \
    echo '    fi' >> /tmp/vercmp && \
    echo '    local IFS=.' >> /tmp/vercmp && \
    echo '    local i ver1=($1) ver2=($2)' >> /tmp/vercmp && \
    echo '    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))' >> /tmp/vercmp && \
    echo '    do' >> /tmp/vercmp && \
    echo '        ver1[i]=0' >> /tmp/vercmp && \
    echo '    done' >> /tmp/vercmp && \
    echo '    for ((i=0; i<${#ver1[@]}; i++))' >> /tmp/vercmp && \
    echo '    do' >> /tmp/vercmp && \
    echo '        if ((10#${ver1[i]:=0} > 10#${ver2[i]:=0}))' >> /tmp/vercmp && \
    echo '        then' >> /tmp/vercmp && \
    echo '            echo "1"' >> /tmp/vercmp && \
    echo '            return' >> /tmp/vercmp && \
    echo '        fi' >> /tmp/vercmp && \
    echo '        if ((10#${ver1[i]} < 10#${ver2[i]}))' >> /tmp/vercmp && \
    echo '        then' >> /tmp/vercmp && \
    echo '            echo "-1"' >> /tmp/vercmp && \
    echo '            return' >> /tmp/vercmp && \
    echo '        fi' >> /tmp/vercmp && \
    echo '    done' >> /tmp/vercmp && \
    echo '    return' >> /tmp/vercmp && \
    echo '}' >> /tmp/vercmp && \
    echo '' >> /tmp/vercmp && \
    echo 'vercmp "$@"' >> /tmp/vercmp && \
    chmod +x /tmp/vercmp && \
    mv /tmp/vercmp /usr/local/bin/vercmp

# Embed tarpack script
RUN echo '#!/usr/bin/env bash' > /tmp/tarpack && \
    echo 'set -ex' >> /tmp/tarpack && \
    echo '' >> /tmp/tarpack && \
    echo 'COMMAND=$1' >> /tmp/tarpack && \
    echo 'PACKAGE=$2' >> /tmp/tarpack && \
    echo '' >> /tmp/tarpack && \
    echo ': "${TARPACK_PREFIX:=/usr/local}"' >> /tmp/tarpack && \
    echo ': "${TARPACK_TMPDIR:=/tmp/tarpack}"' >> /tmp/tarpack && \
    echo '' >> /tmp/tarpack && \
    echo ': "${WGET_OPTIONS:=--quiet --show-progress --progress=bar:force:noscroll}"' >> /tmp/tarpack && \
    echo '' >> /tmp/tarpack && \
    echo 'mkdir -p ${TARPACK_TMPDIR}/uploads' >> /tmp/tarpack && \
    echo '' >> /tmp/tarpack && \
    echo 'if [ "${COMMAND}" == "install" ]; then' >> /tmp/tarpack && \
    echo '	cd ${TARPACK_TMPDIR}' >> /tmp/tarpack && \
    echo '	wget ${WGET_OPTIONS} ${TAR_INDEX_URL}/${PACKAGE}.tar.gz' >> /tmp/tarpack && \
    echo '	wget ${WGET_OPTIONS} ${TAR_INDEX_URL}/${PACKAGE}.sha256' >> /tmp/tarpack && \
    echo '	ls -ll ${PACKAGE}.tar.gz' >> /tmp/tarpack && \
    echo '	cat ${PACKAGE}.sha256' >> /tmp/tarpack && \
    echo '	sha256sum --check ${PACKAGE}.sha256' >> /tmp/tarpack && \
    echo '	tar -xzvf ${PACKAGE}.tar.gz -C ${TARPACK_PREFIX}' >> /tmp/tarpack && \
    echo '	rm ${PACKAGE}.tar.gz' >> /tmp/tarpack && \
    echo '	rm ${PACKAGE}.sha256' >> /tmp/tarpack && \
    echo 'elif [ "${COMMAND}" == "upload" ]; then' >> /tmp/tarpack && \
    echo '	upload_tarball="${TARPACK_TMPDIR}/uploads/$PACKAGE.tar.gz"' >> /tmp/tarpack && \
    echo '	upload_sha="${TARPACK_TMPDIR}/uploads/$PACKAGE.sha256"' >> /tmp/tarpack && \
    echo '	src_dir="${3:-.}"' >> /tmp/tarpack && \
    echo '	cd $src_dir || echo "warning: input $src_dir was not a valid directory"' >> /tmp/tarpack && \
    echo '	tar -czvf $upload_tarball .' >> /tmp/tarpack && \
    echo '	cd ${TARPACK_TMPDIR}/uploads' >> /tmp/tarpack && \
    echo '	sha256sum $PACKAGE.tar.gz > $upload_sha' >> /tmp/tarpack && \
    echo '	sshpass -p ${SCP_UPLOAD_PASS} scp -o '\''StrictHostKeyChecking no'\'' $upload_tarball ${SCP_UPLOAD_USER}@${SCP_UPLOAD_URL}/' >> /tmp/tarpack && \
    echo '	sshpass -p ${SCP_UPLOAD_PASS} scp -o '\''StrictHostKeyChecking no'\'' $upload_sha ${SCP_UPLOAD_USER}@${SCP_UPLOAD_URL}/' >> /tmp/tarpack && \
    echo '	#rm $upload_tarball' >> /tmp/tarpack && \
    echo '	#rm $upload_sha' >> /tmp/tarpack && \
    echo 'elif [ "${COMMAND}" == "test" ]; then' >> /tmp/tarpack && \
    echo '	mkdir -p /tmp/tarpack-test/include/tarpack /tmp/tarpack-test/bin && \' >> /tmp/tarpack && \
    echo '	echo "// TEST" > /tmp/tarpack-test/include/tarpack/tarpack.h && \' >> /tmp/tarpack && \
    echo '	echo "echo TARPACK TEST" > /tmp/tarpack-test/bin/tarpack-test.sh && \' >> /tmp/tarpack && \
    echo '	chmod +x /tmp/tarpack-test/bin/tarpack-test.sh && \' >> /tmp/tarpack && \
    echo '	tarpack upload tarpack-test /tmp/tarpack-test/ && \' >> /tmp/tarpack && \
    echo '	tarpack install tarpack-test && \' >> /tmp/tarpack && \
    echo '	ls -ll /usr/local/bin && \' >> /tmp/tarpack && \
    echo '	ls -R /usr/local/include && \' >> /tmp/tarpack && \
    echo '	cat /usr/local/include/tarpack/tarpack.h && \' >> /tmp/tarpack && \
    echo '	tarpack-test.sh' >> /tmp/tarpack && \
    echo 'else' >> /tmp/tarpack && \
    echo '	echo "unexpected command ${COMMAND}"' >> /tmp/tarpack && \
    echo '	exit 1' >> /tmp/tarpack && \
    echo 'fi' >> /tmp/tarpack && \
    chmod +x /tmp/tarpack && \
    mv /tmp/tarpack /usr/local/bin/tarpack

# Add verification checks for build-essential packages
RUN echo "# Check for build tools" >> /tmp/build_checks.sh \
    && echo "check_cmd gcc 'gcc --version'" >> /tmp/build_checks.sh \
    && echo "check_cmd g++ 'g++ --version'" >> /tmp/build_checks.sh \
    && echo "check_cmd make 'make --version'" >> /tmp/build_checks.sh \
    && echo "check_cmd git 'git --version'" >> /tmp/build_checks.sh \
    && cat /tmp/build_checks.sh >> /opt/list_app_checks.sh