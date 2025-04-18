# COMMIT-TRACKING: UUID-20240729-004815-A3B1
# Description: Update author, align embedded instructions with UUID reuse policy
# Author: Mr K
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── .github/                   <- GitHub directory
# │   └── vs-code-snippets-guide.md  <- THIS FILE
# └── ...                        <- Other project files

# Setting Up VS Code User Snippets for Copilot Instructions

VS Code snippets allow you to quickly insert the Copilot instructions into any new project or file. Here's how to set them up:

## 1. Open VS Code User Snippets

1. Open VS Code
2. Go to `File > Preferences > User Snippets` (or press `Ctrl+Shift+P` and type "snippets")
3. Select "New Global Snippets file..."
4. Name it `copilot-instructions.code-snippets`

## 2. Add the Snippet Definition

Replace the default content with this snippet definition:

```json
{
  "Copilot Instructions Header": {
    "scope": "markdown",
    "prefix": "copilot-header",
    "body": [
      "# COMMIT-TRACKING: UUID-$CURRENT_YEAR$CURRENT_MONTH$CURRENT_DATE-$CURRENT_HOUR$CURRENT_MINUTE$CURRENT_SECOND-${1:XXXX}",
      "# Description: ${2:Brief description of changes}",
      "# Author: ${3:Your name/identifier}",
      "#",
      "# File location diagram:",
      "# ${4:project}/                          <- Main project folder",
      "# ├── README.md                  <- Project documentation",
      "# ├── ${5:directory}/               <- File's directory",
      "# │   └── ${6:filename}             <- THIS FILE",
      "# └── ...                        <- Other project files",
      "",
      "$0"
    ],
    "description": "Insert Copilot instructions file header"
  },
  "Copilot Full Instructions": {
    "scope": "markdown",
    "prefix": "copilot-instructions",
    "body": [
      "# LOCAL INSTRUCTIONS - DO NOT COMMIT TO GIT",
      "",
      "## File Header Format",
      "",
      "All modified files should include this header format:",
      "",
      "```",
      "# COMMIT-TRACKING: UUID-YYYYMMDD-HHMMSS-XXXX",
      "# Description: Brief description of changes",
      "# Author: Your name/identifier",
      "#",
      "# File location diagram:",
      "# ${1:project}/                          <- Main project folder",
      "# ├── README.md                  <- Project documentation",
      "# ├── ${2:directory}/               <- File's directory",
      "# │   └── ${3:filename}             <- THIS FILE",
      "# └── ...                        <- Other project files",
      "```",
      "",
      "## How to Use",
      "",
      "1.  When modifying a file, ensure the `COMMIT-TRACKING` header is present at the top. If adding a header to a new file or a file without one, place it at the very top.",
      "2.  **UUID Management:**",
      "    *   **If the file being modified *already has* a `COMMIT-TRACKING` header:** **Reuse** the existing `UUID-YYYYMMDD-HHMMSS-XXXX` value from that header for your current set of changes. Use this *same reused UUID* across all files modified in the same logical commit/change set.",
      "    *   **If the file does *not* have a header, or you are creating a new file:** **Generate** a *new* UUID for the current commit using the format `UUID-YYYYMMDD-HHMMSS-XXXX` (YYYYMMDD = current date, HHMMSS = current time, XXXX = random identifier like last 4 chars of git commit hash or random hex). Use this *same new UUID* across all files modified or created in this commit.",
      "3.  Update the `Description:` line in the header with a brief summary of the changes made in this commit/change set.",
      "4.  Update the `Author:` line if necessary.",
      "5.  Ensure the `File location diagram:` accurately reflects the file's path within the `${1:project}` project structure.",
      "6.  Use the *same* UUID (whether reused or newly generated) across all files modified in the same logical commit.",
      "",
      "## Example",
      "",
      "For a file located at `${1:project}/buildx/build.sh`:",
      "",
      "```",
      "# COMMIT-TRACKING: UUID-20250418-113042-7E2D",
      "# Description: Fixed Docker buildx script syntax errors and improved build output handling",
      "# Author: GitHub Copilot / User",
      "#",
      "# File location diagram:",
      "# ${1:project}/                          <- Main project folder",
      "# ├── README.md                  <- Project documentation",
      "# ├── buildx/                    <- Current directory",
      "# │   └── build.sh               <- THIS FILE",
      "# └── ...                        <- Other project files",
      "```",
      "",
      "## Commit Messages",
      "",
      "When committing, use the UUID as part of your commit message:",
      "",
      "```",
      "UUID-20250418-113042-7E2D: Fixed Docker buildx script syntax errors",
      "```",
      "",
      "This allows easy cross-referencing between commits and the files that were modified.",
      "",
      "## Additional Guidelines",
      "",
      "1. Keep descriptions concise but informative",
      "2. Make sure the file location diagram is accurate for each file",
      "3. For multi-file commits, use the same UUID across all files",
      "4. The UUID should be determined **once per commit/change set** (either reused from an existing file or newly generated) and applied consistently to all files touched in that set.",
      "5. Add this header to all new files as well as modified files",
      "",
      "$0"
    ],
    "description": "Insert complete Copilot instructions template"
  }
}
```

## 3. Save the Snippets File

Click "Save" (or press `Ctrl+S`) to save the snippets file.

## 4. Using the Snippets

You've created two snippets:

1. `copilot-header`: Quickly inserts just the file header with current date/time
2. `copilot-instructions`: Inserts the complete instructions document

To use them:

1. Create a new file (typically a Markdown file in the `.github` folder)
2. Type `copilot-header` and press `Tab` to insert just the header
   - Or type `copilot-instructions` and press `Tab` for the complete instructions
3. Fill in the placeholder values (use `Tab` to navigate between them)

## 5. Creating a .github/copilot-instructions.md File

For each new project:

1. Create a `.github` directory in your project root
2. Create a file named `copilot-instructions.md` inside it
3. At the start of the file, type `copilot-instructions` and press `Tab`
4. Fill in the project name and other placeholders

## 6. Setting Up VS Code to Use the Instructions

Create a `.vscode/settings.json` file in your project with:

```json
{
  "github.copilot.advanced": {
    "instructionLocation": "${workspaceFolder}/.github/copilot-instructions.md"
  }
}
```

## 7. Create a Script to Automate This Process

You can create a shell script to automatically set up the directories and files:

```bash
#!/bin/bash

# Create necessary directories
mkdir -p .github .vscode

# Create the settings.json file for VS Code
cat > .vscode/settings.json << EOF
{
  "github.copilot.advanced": {
    "instructionLocation": "\${workspaceFolder}/.github/copilot-instructions.md"
  }
}
EOF

# Create an empty copilot-instructions.md file
# (you'll still need to fill it using the snippet)
touch .github/copilot-instructions.md

echo "Project setup complete. Now:"
echo "1. Open .github/copilot-instructions.md in VS Code"
echo "2. Type 'copilot-instructions' and press Tab"
echo "3. Fill in the project-specific placeholders"
```

This approach with VS Code snippets gives you flexibility to use your Copilot instructions in any project, whether it's a new or existing one, without relying on Git templates or cloning from a template repository.
