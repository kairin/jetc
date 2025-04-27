# COMMIT-TRACKING: UUID-20240729-004815-A3B1
# Description: Add guidance about file-specific descriptions in headers
# Author: Mr K
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── .vscode/                   <- VSCode settings directory
# │   └── README.md              <- THIS FILE
# └── ...                        <- Other project files

# VSCode Copilot Configuration

This project uses custom VSCode settings to help maintain consistent code styles and headers.

## Features

1. **Header Templates**: Type `header` in any file to get the standard COMMIT-TRACKING header template
2. **Syntax Highlighting**: COMMIT-TRACKING tags are highlighted for visibility
3. **Snippets**: Common project patterns are available as snippets

## Usage

- In any new file, type `header` and press Tab to insert the tracking header
- The UUID timestamp is auto-populated based on current date/time
- Complete the XXXX portion and description manually
- Update the file location diagram to match the current file
- **Important**: If modifying a file that *already has* a `COMMIT-TRACKING` header, **reuse** the existing UUID instead of generating a new one for that commit.
- **Important**: Even when reusing the same UUID across multiple files, the Description line should be unique to each file and accurately describe what changes were made to that specific file.

## Installation and Setup

1. Make sure all files are in the `.vscode` directory:
   - `snippets/global.code-snippets` - Header template snippets
   - `settings.json` - VSCode configuration
   - `init_copilot.js` - UUID generation script
   - `README.md` - This documentation file

2. Run the setup script (requires Node.js):
   ```
   node .vscode/setup_tracking.js
   ```

3. Restart VSCode to apply all settings

## Manual Instructions

If the automatic setup doesn't work, manually add this header to all files:

## Header Best Practices

1. **UUID Consistency**: Use the same UUID across all files in a single commit/change set.
2. **Description Uniqueness**: Each file should have a unique description that explains what specifically changed in that file.
3. **Description Format**: Begin with a verb (Add, Update, Fix, Refactor, etc.) followed by concise details of the change.

## Examples of Good File-Specific Descriptions:

- "Add Docker utility functions for image verification" 
- "Create environment setup functions for variables"
- "Fix syntax error in build_folder_image function"
- "Refactor build script to use modular components"

## Examples of Bad (Too Generic) Descriptions:

- "Update file" (too vague)
- "Fix issues" (doesn't specify what issues)
- "Make changes" (doesn't describe the actual changes)
- "Clarify instructions" (should specify which instructions were clarified)

