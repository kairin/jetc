#!/bin/bash

# COMMIT-TRACKING: UUID-20240729-004815-A3B1
# Description: Add script to install Git hooks
# Author: Mr K
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── .github/                   <- GitHub directory
# │   └── install-hooks.sh       <- THIS FILE
# └── ...                        <- Other project files

echo "Installing Git hooks for COMMIT-TRACKING system..."

# Create hooks directory if it doesn't exist
mkdir -p .git/hooks

# Copy pre-commit hook
cp .github/pre-commit-hook.sh .git/hooks/pre-commit

# Make the hook executable
chmod +x .git/hooks/pre-commit

echo "✅ Pre-commit hook installed!"
echo "The hook will now validate your commit headers automatically."
