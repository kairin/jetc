#!/bin/bash
setup_build_environment || exit 1
load_env_variables || exit 1

# Add: Update LOCAL_DOCKER_IMAGES in .env with all local images (repo:tag)
if command -v docker &>/dev/null; then
  LOCAL_DOCKER_IMAGES=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -v '<none>' | sort | uniq | tr '\n' ';' | sed 's/;*$//')
  ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.env"
  if [ -f "$ENV_FILE" ]; then
    if grep -q "^LOCAL_DOCKER_IMAGES=" "$ENV_FILE"; then
      sed -i "s|^LOCAL_DOCKER_IMAGES=.*|LOCAL_DOCKER_IMAGES=$LOCAL_DOCKER_IMAGES|" "$ENV_FILE"
    else
      echo -e "\n# All local Docker images (semicolon-separated, auto-updated)" >> "$ENV_FILE"
      echo "LOCAL_DOCKER_IMAGES=$LOCAL_DOCKER_IMAGES" >> "$ENV_FILE"
    fi
  fi
fi

# Initialize CURRENT_BASE_IMAGE with a valid value
CURRENT_BASE_IMAGE="${SELECTED_BASE_IMAGE}"

# Add a check to verify that CURRENT_BASE_IMAGE is not empty after initialization
if [[ -z "$CURRENT_BASE_IMAGE" ]]; then
  echo "Error: CURRENT_BASE_IMAGE is still empty after initialization. Exiting."
  exit 1
fi
