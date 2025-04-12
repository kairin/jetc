#!/usr/bin/env bash
set -e

echo "Listing all installed applications and packages in the container..."

# Determine the package manager and list installed packages
if command -v dpkg > /dev/null; then
    echo "Detected dpkg (Debian/Ubuntu-based system)."
    dpkg --get-selections
elif command -v rpm > /dev/null; then
    echo "Detected rpm (RHEL/CentOS-based system)."
    rpm -qa
elif command -v apk > /dev/null; then
    echo "Detected apk (Alpine-based system)."
    apk info
else
    echo "Unknown package manager. Please add support for your package manager."
    exit 1
fi

echo "Application listing complete."
