#!/bin/bash
# Script to consolidate changes and push to repository

# Make sure we're in the right directory
cd "$(dirname "$0")"

# Add all changed files to staging
git add buildx/build.sh
git add buildx/scripts/build_utils.sh
git add buildx/scripts/image_utils.sh
git add buildx/scripts/ui_utils.sh
git add buildx/scripts/verify_utils.sh
git add .gitattributes

# Commit all changes with a descriptive message
git commit -m "Refactor build system with modular utility scripts and add .gitattributes"

# Push changes to remote repository
git push

echo "All changes have been committed and pushed!"
