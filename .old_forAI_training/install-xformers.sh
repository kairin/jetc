#!/usr/bin/env bash

# =========================================================================
# IMPORTANT: This build system requires Docker with buildx extension.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================
set -ex

if [ "$FORCE_BUILD" == "on" ]; then
	echo "Forcing build of xformers ${XFORMERS}"
	exit 1
fi

pip3 install xformers==${XFORMERS_VERSION}
