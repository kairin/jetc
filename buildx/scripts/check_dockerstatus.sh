#!/bin/bash

# =========================================================================
# IMPORTANT: This build system requires Docker with buildx extension.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================

# Check Docker status
if systemctl is-active --quiet docker; then
    echo "✅ Docker is running"
else
    echo "❌ Docker is not running"
fi

# Check sudo privileges
if sudo -n true 2>/dev/null; then
    echo "✅ You have sudo privileges"
else
    echo "❌ You don't have sudo privileges or need to enter password"
fi