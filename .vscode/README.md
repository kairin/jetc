# COMMIT-TRACKING: UUID-20240729-004815-A3B1
# Description: Add header, update author, clarify UUID reuse in usage
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

