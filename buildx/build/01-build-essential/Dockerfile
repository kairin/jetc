#---
# name: build-essential
# group: build
# notes: installs compilers, build tools & configures the default locale
#---
ARG BASE_IMAGE=kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu
FROM ${BASE_IMAGE}

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

COPY tarpack vercmp /usr/local/bin/

# Add verification checks for build-essential packages
RUN echo "# Check for build tools" >> /tmp/build_checks.sh \
    && echo "check_cmd gcc 'gcc --version'" >> /tmp/build_checks.sh \
    && echo "check_cmd g++ 'g++ --version'" >> /tmp/build_checks.sh \
    && echo "check_cmd make 'make --version'" >> /tmp/build_checks.sh \
    && echo "check_cmd git 'git --version'" >> /tmp/build_checks.sh \
    && cat /tmp/build_checks.sh >> /opt/list_app_checks.sh