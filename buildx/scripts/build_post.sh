#!/bin/bash
if [[ -n "$TIMESTAMPED_LATEST_TAG" ]] && [[ "$BUILD_FAILED" -eq 0 ]]; then
    show_post_build_menu "$TIMESTAMPED_LATEST_TAG"
else
    echo "No final image tag recorded or build failed, skipping further operations."
fi
