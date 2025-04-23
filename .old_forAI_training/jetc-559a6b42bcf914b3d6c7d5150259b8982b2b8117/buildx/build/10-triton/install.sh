#!/usr/bin/env bash
#triton
set -ex

# Validate environment variables
if [ -z "${TRITON_VERSION}" ]; then
    echo "Error: TRITON_VERSION is not set"
    exit 1
fi

if [ "$FORCE_BUILD" == "on" ]; then
	echo "Forcing build of triton ${TRITON_VERSION} (branch=${TRITON_BRANCH})"
	exit 1
fi

pip3 install triton==${TRITON_VERSION}
