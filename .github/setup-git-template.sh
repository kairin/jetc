#!/bin/bash

# COMMIT-TRACKING: UUID-20240729-004815-A3B1
# Description: Update author
# Author: Mr K
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── .github/                   <- GitHub directory
# │   └── setup-git-template.sh  <- THIS FILE
# └── ...                        <- Other project files

# Ask user for template structure preference
echo "Do you want to use:"
echo "1) Standard structure (.github and .vscode folders) - RECOMMENDED"
echo "2) Simplified structure (all in one folder)"
read -p "Enter choice (1 or 2): " structure_choice

case $structure_choice in
  1)
    # Create standard Git template directories
    echo "Creating standard template structure..."
    mkdir -p ~/.git-template/.github
    mkdir -p ~/.git-template/.vscode
    mkdir -p ~/.git-template/.vscode/snippets
    
    # Copy Copilot instructions to the template
    cp "$(pwd)/.github/copilot-instructions.md" ~/.git-template/.github/
    
    # Copy VSCode tracking system files
    cp "$(pwd)/.vscode/setup_tracking.js" ~/.git-template/.vscode/
    cp "$(pwd)/.vscode/init_copilot.js" ~/.git-template/.vscode/
    cp "$(pwd)/.vscode/README.md" ~/.git-template/.vscode/
    cp "$(pwd)/.vscode/extensions.json" ~/.git-template/.vscode/
    cp "$(pwd)/.vscode/snippets/global.code-snippets" ~/.git-template/.vscode/snippets/
    
    # Create VS Code settings file
    cat > ~/.git-template/.vscode/settings.json << EOF
{
    "editor.snippetSuggestions": "top",
    "github.copilot.enable": {
        "*": true,
        "plaintext": false,
        "markdown": true,
        "scminput": false
    },
    "better-comments.tags": [
        {
            "tag": "COMMIT-TRACKING:",
            "color": "#FF9800",
            "strikethrough": false,
            "underline": false,
            "backgroundColor": "transparent",
            "bold": true,
            "italic": false
        }
    ],
    "github.copilot.advanced": {
        "instructionLocation": "\${workspaceFolder}/.github/copilot-instructions.md"
    }
}
EOF
    ;;
    
  2)
    # Create simplified Git template directory
    echo "Creating simplified template structure..."
    mkdir -p ~/.git-template/copilot
    
    # Copy Copilot instructions to the template
    cp "$(pwd)/.github/copilot-instructions.md" ~/.git-template/copilot/
    
    # Create VS Code settings file pointing to the custom location
    cat > ~/.git-template/copilot/settings.json << EOF
{
  "github.copilot.advanced": {
    "instructionLocation": "\${workspaceFolder}/copilot/copilot-instructions.md"
  }
}
EOF
    
    # Create a setup script that will run after git init
    cat > ~/.git-template/hooks/post-init.sample << EOF
#!/bin/sh
# This hook script is executed after git init
# To enable: rename to post-init (no extension) and make executable

# Create copilot directory if it doesn't exist
mkdir -p \$(git rev-parse --show-toplevel)/copilot

# Copy files from the template
cp -r \$(git rev-parse --show-toplevel)/.git/copilot/* \$(git rev-parse --show-toplevel)/copilot/

# Create .vscode directory for settings
mkdir -p \$(git rev-parse --show-toplevel)/.vscode

# Create settings.json that points to the copilot directory
cat > \$(git rev-parse --show-toplevel)/.vscode/settings.json << EOFINNER
{
  "github.copilot.advanced": {
    "instructionLocation": "\\\${workspaceFolder}/copilot/copilot-instructions.md"
  }
}
EOFINNER

echo "Copilot instructions set up in ./copilot/"
EOF
    
    # Make the hook executable
    chmod +x ~/.git-template/hooks/post-init.sample
    echo "NOTE: For simplified structure, after 'git init' you must:"
    echo "1. Rename .git/hooks/post-init.sample to post-init"
    echo "2. Run: bash .git/hooks/post-init"
    ;;
    
  *)
    echo "Invalid choice. Using standard structure."
    mkdir -p ~/.git-template/.github
    mkdir -p ~/.git-template/.vscode
    mkdir -p ~/.git-template/.vscode/snippets
    cp "$(pwd)/.github/copilot-instructions.md" ~/.git-template/.github/
    cp "$(pwd)/.vscode/setup_tracking.js" ~/.git-template/.vscode/
    cp "$(pwd)/.vscode/init_copilot.js" ~/.git-template/.vscode/
    cp "$(pwd)/.vscode/README.md" ~/.git-template/.vscode/
    cp "$(pwd)/.vscode/extensions.json" ~/.git-template/.vscode/
    cp "$(pwd)/.vscode/snippets/global.code-snippets" ~/.git-template/.vscode/snippets/
    cat > ~/.git-template/.vscode/settings.json << EOF
{
    "editor.snippetSuggestions": "top",
    "github.copilot.enable": {
        "*": true,
        "plaintext": false,
        "markdown": true,
        "scminput": false
    },
    "better-comments.tags": [
        {
            "tag": "COMMIT-TRACKING:",
            "color": "#FF9800",
            "strikethrough": false,
            "underline": false,
            "backgroundColor": "transparent",
            "bold": true,
            "italic": false
        }
    ],
    "github.copilot.advanced": {
        "instructionLocation": "\${workspaceFolder}/.github/copilot-instructions.md"
    }
}
EOF
    ;;
esac

# Configure Git to use the template
git config --global init.templateDir ~/.git-template

echo "Git template setup complete! All new repositories will include:"
echo "- Copilot instructions (.github/copilot-instructions.md)"
echo "- VSCode tracking setup (.vscode/*)"
echo "- VSCode settings configured for Copilot instructions"
echo ""
echo "To test: mkdir test-repo && cd test-repo && git init"
