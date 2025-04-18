# COMMIT-TRACKING: UUID-20240729-004815-A3B1
# Description: Update author
# Author: Mr K
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── .github/                   <- GitHub directory
# │   └── git-template-setup.md  <- THIS FILE
# └── ...                        <- Other project files

# Setting Up Git Templates for Copilot Instructions

Git templates allow you to automatically include files and directories in every new Git repository you create. Here's how to set up a Git template that includes your Copilot instructions.

## 1. Create the Git Template Directory

First, create a directory to store your Git template:

```bash
# Create the Git template directory structure
mkdir -p ~/.git-template/.github
```

## 2. Copy Your Copilot Instructions

Copy your existing Copilot instructions file to the template:

```bash
# Copy your Copilot instructions to the template directory
cp /path/to/your/jetc/.github/copilot-instructions.md ~/.git-template/.github/
```

## 3. Configure Git to Use Your Template

Tell Git to use your template directory for all new repositories:

```bash
# Set the global Git template directory
git config --global init.templateDir ~/.git-template
```

## 4. Test Your Template

To test that your setup is working:

```bash
# Create a test directory
mkdir test-git-template
cd test-git-template

# Initialize a new Git repository
git init

# Check if the Copilot instructions file exists
ls -la .github/
```

You should see your `copilot-instructions.md` file in the `.github` directory of the new repository.

## 5. Additional Configuration

To ensure VS Code's Copilot recognizes your instructions in new projects, create a settings file in your template:

```bash
# Create VS Code settings directory in the template
mkdir -p ~/.git-template/.vscode

# Create a settings.json file that points to the instructions
cat > ~/.git-template/.vscode/settings.json << EOF
{
  "github.copilot.advanced": {
    "instructionLocation": "\${workspaceFolder}/.github/copilot-instructions.md"
  }
}
EOF
```

## 6. Automation Script

If you want to automate this entire process, you can use the following script:

```bash
#!/bin/bash

# Create Git template directories
mkdir -p ~/.git-template/.github
mkdir -p ~/.git-template/.vscode

# Copy Copilot instructions to the template
cp "$(pwd)/.github/copilot-instructions.md" ~/.git-template/.github/

# Create VS Code settings file
cat > ~/.git-template/.vscode/settings.json << EOF
{
  "github.copilot.advanced": {
    "instructionLocation": "\${workspaceFolder}/.github/copilot-instructions.md"
  }
}
EOF

# Configure Git to use the template
git config --global init.templateDir ~/.git-template

echo "Git template setup complete! All new repositories will include your Copilot instructions."
```

Save this script to a file (e.g., `setup-git-template.sh`), make it executable (`chmod +x setup-git-template.sh`), and run it from your repository root.

## Notes

- The template is only applied when creating a new repository with `git init`
- Existing repositories won't be affected
- If you update your Copilot instructions, you'll need to update the template
- This works for both local repositories and those created from GitHub clones (if you run `git init` again)
