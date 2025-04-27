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
echo "Installing pre-commit hook..."
cp .github/pre-commit-hook.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Copy prepare-commit-msg hook
echo "Installing prepare-commit-msg hook..."
cp .github/prepare-commit-msg-hook.sh .git/hooks/prepare-commit-msg
chmod +x .git/hooks/prepare-commit-msg

echo "✅ Pre-commit and prepare-commit-msg hooks installed!"
echo "The hooks will now validate headers, update timestamps, and prepare commit messages."
