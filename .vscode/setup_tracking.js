// COMMIT-TRACKING: UUID-20240729-004815-A3B1
// Description: Setup script for initializing the tracking system
// Author: Mr K
//
// File location diagram:
// jetc/                          <- Main project folder
// ├── README.md                  <- Project documentation
// ├── .vscode/                   <- VSCode settings directory
// │   └── setup_tracking.js      <- THIS FILE
// └── ...                        <- Other project files

const fs = require('fs');
const path = require('path');

// Ensure all files are in the right place
function validateSetup() {
    const requiredFiles = [
        '.vscode/snippets/global.code-snippets',
        '.vscode/settings.json',
        '.vscode/README.md',
        '.vscode/init_copilot.js'
    ];
    
    const missingFiles = [];
    
    for (const file of requiredFiles) {
        if (!fs.existsSync(path.join(process.cwd(), file))) {
            missingFiles.push(file);
        }
    }
    
    if (missingFiles.length > 0) {
        console.error('Warning: The following tracking system files are missing:');
        missingFiles.forEach(file => console.error(`- ${file}`));
        return false;
    }
    
    console.log('All tracking system files are present.');
    return true;
}

// Create .gitignore entry to protect local instructions
function updateGitignore() {
    const gitignorePath = path.join(process.cwd(), '.gitignore');
    const gitignoreEntry = '\n# VSCode Copilot tracking - session specific\n.vscode/copilot-session/\n';
    
    try {
        if (fs.existsSync(gitignorePath)) {
            const content = fs.readFileSync(gitignorePath, 'utf8');
            if (!content.includes('VSCode Copilot tracking')) {
                fs.appendFileSync(gitignorePath, gitignoreEntry);
                console.log('Updated .gitignore with Copilot tracking exclusions');
            }
        } else {
            fs.writeFileSync(gitignorePath, gitignoreEntry);
            console.log('Created .gitignore with Copilot tracking exclusions');
        }
    } catch (err) {
        console.error('Failed to update .gitignore:', err);
    }
}

// Create session folder for temporary tracking data
function createSessionFolder() {
    const sessionDir = path.join(process.cwd(), '.vscode/copilot-session');
    if (!fs.existsSync(sessionDir)) {
        fs.mkdirSync(sessionDir, { recursive: true });
        console.log('Created Copilot session directory');
    }
}

// Add a function to create missing files
function createMissingFiles() {
    // Create snippets directory if it doesn't exist
    const snippetsDir = path.join(process.cwd(), '.vscode/snippets');
    if (!fs.existsSync(snippetsDir)) {
        fs.mkdirSync(snippetsDir, { recursive: true });
    }
    
    // Create or update each required file
    createSnippetsFile();
    createSettingsFile();
    createReadmeFile();
    createInitCopilotFile();
    createGithubInstructionsFile();
}

// Add implementations for the mentioned functions
function createSnippetsFile() {
    const snippetsDir = path.join(process.cwd(), '.vscode/snippets');
    const snippetsFile = path.join(snippetsDir, 'global.code-snippets');
    
    if (!fs.existsSync(snippetsFile)) {
        const snippetsContent = `{
  "File Header with COMMIT-TRACKING": {
    "scope": "shellscript,javascript,typescript,python,java,markdown,html,xml,yaml",
    "prefix": ["header", "trackingheader"],
    "body": [
      "\${LINE_COMMENT} COMMIT-TRACKING: UUID-$CURRENT_YEAR$CURRENT_MONTH$CURRENT_DATE-$CURRENT_HOUR$CURRENT_MINUTE$CURRENT_SECOND-\${1:XXXX}",
      "\${LINE_COMMENT} Description: \${2:Brief description of changes}",
      "\${LINE_COMMENT} Author: \${3:Mr K}",
      "\${LINE_COMMENT} ",
      "\${LINE_COMMENT} File location diagram:",
      "\${LINE_COMMENT} jetc/                          <- Main project folder",
      "\${LINE_COMMENT} ├── README.md                  <- Project documentation",
      "\${LINE_COMMENT} ├── \${4:directory}/            <- Current directory",
      "\${LINE_COMMENT} │   └── \${5:\${TM_FILENAME}}          <- THIS FILE",
      "\${LINE_COMMENT} └── ...                        <- Other project files",
      "$0"
    ],
    "description": "Add standard COMMIT-TRACKING header to file (adapts comment style)"
  }
}`;
        fs.writeFileSync(snippetsFile, snippetsContent);
        console.log('Created snippets file');
    }
}

function createSettingsFile() {
    const settingsFile = path.join(process.cwd(), '.vscode/settings.json');
    
    if (!fs.existsSync(settingsFile)) {
        const settingsContent = `{
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
}`;
        fs.writeFileSync(settingsFile, settingsContent);
        console.log('Created settings file');
    }
}

function createReadmeFile() {
    const readmeFile = path.join(process.cwd(), '.vscode/README.md');
    
    if (!fs.existsSync(readmeFile)) {
        const readmeContent = `# VSCode Copilot Configuration

This project uses custom VSCode settings to help maintain consistent code styles and headers.

## Features

1. **Header Templates**: Type \`header\` in any file to get the standard COMMIT-TRACKING header template
2. **Syntax Highlighting**: COMMIT-TRACKING tags are highlighted for visibility
3. **Snippets**: Common project patterns are available as snippets

## Usage

- In any new file, type \`header\` and press Tab to insert the tracking header
- The UUID timestamp is auto-populated based on current date/time
- Complete the XXXX portion and description manually
- Update the file location diagram to match the current file
- **Important**: If modifying a file that *already has* a \`COMMIT-TRACKING\` header, **reuse** the existing UUID instead of generating a new one for that commit.

## Installation and Setup

1. Make sure all files are in the \`.vscode\` directory:
   - \`snippets/global.code-snippets\` - Header template snippets
   - \`settings.json\` - VSCode configuration
   - \`init_copilot.js\` - UUID generation script
   - \`README.md\` - This documentation file

2. Run the setup script (requires Node.js):
   \`\`\`
   node .vscode/setup_tracking.js
   \`\`\`

3. Restart VSCode to apply all settings`;
        fs.writeFileSync(readmeFile, readmeContent);
        console.log('Created README file');
    }
}

function createInitCopilotFile() {
    const initFile = path.join(process.cwd(), '.vscode/init_copilot.js');
    
    if (!fs.existsSync(initFile)) {
        const today = new Date();
        const date = today.toISOString().slice(0,10).replace(/-/g,'');
        const time = today.toTimeString().slice(0,8).replace(/:/g,'');
        const uuid = `UUID-${date}-${time}-A000`;
        
        const initContent = `// COMMIT-TRACKING: ${uuid}
// Description: Setup script for initializing the tracking system
// Author: Mr K
//
// File location diagram:
// jetc/                          <- Main project folder
// ├── README.md                  <- Project documentation
// ├── .vscode/                   <- VSCode settings directory
// │   └── init_copilot.js        <- THIS FILE
// └── ...                        <- Other project files

// This script can be loaded by the VSCode Custom Editor API when available
// or used with VSCode extensions that support JS hooks

(function() {
  // Generate UUID in required format
  function generateTrackingID() {
    const now = new Date();
    const date = now.toISOString().slice(0,10).replace(/-/g,'');
    const time = now.toTimeString().slice(0,8).replace(/:/g,'');
    const random = Math.random().toString(16).substring(2,6).toUpperCase();
    return \`UUID-\${date}-\${time}-\${random}\`;
  }
  
  // Defines a hook that can be exported for extensions that support it
  const uuid = generateTrackingID();
  
  // Export for use by compatible extensions
  exports.copilotConfig = {
    fileHeaderTemplate: \`COMMIT-TRACKING: \${uuid}\`,
    trackingUUID: uuid,
    templatePath: ".copilot_instructions"
  };
})();`;
        fs.writeFileSync(initFile, initContent);
        console.log('Created init_copilot.js file');
    }
}

function createGithubInstructionsFile() {
    // Create .github directory if it doesn't exist
    const githubDir = path.join(process.cwd(), '.github');
    if (!fs.existsSync(githubDir)) {
        fs.mkdirSync(githubDir, { recursive: true });
    }
    
    const instructionsFile = path.join(githubDir, 'copilot-instructions.md');
    
    if (!fs.existsSync(instructionsFile)) {
        const today = new Date();
        const date = today.toISOString().slice(0,10).replace(/-/g,'');
        const time = today.toTimeString().slice(0,8).replace(/:/g,'');
        const uuid = `UUID-${date}-${time}-A000`;
        
        const instructionsContent = `# COMMIT-TRACKING: ${uuid}
# Description: Initial Copilot instructions
# Author: Mr K
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── .github/                   <- GitHub directory
# │   └── copilot-instructions.md<- THIS FILE
# └── ...                        <- Other project files

# LOCAL INSTRUCTIONS - DO NOT COMMIT TO GIT

## File Header Format

All modified files should include this header format at the very top. **Choose the comment style appropriate for the file type.**

**Common Comment Styles:**

*   **\`#\` Style:** (Shell scripts \`.sh\`, Python \`.py\`, Dockerfile, YAML \`.yml\`, etc.)
    \`\`\`
    # COMMIT-TRACKING: UUID-YYYYMMDD-HHMMSS-XXXX
    # Description: Brief description of changes
    # Author: Your name/identifier
    #
    # File location diagram:
    # jetc/                          <- Main project folder
    # ├── README.md                  <- Project documentation
    # ├── [directory]/               <- File's directory
    # │   └── [filename]             <- THIS FILE
    # └── ...                        <- Other project files
    \`\`\`
*   **\`//\` Style:** (JavaScript \`.js\`, TypeScript \`.ts\`/\`.tsx\`, JSON with Comments \`.jsonc\`, C/C++, Java, etc.)
    \`\`\`javascript
    // COMMIT-TRACKING: UUID-YYYYMMDD-HHMMSS-XXXX
    // Description: Brief description of changes
    // Author: Your name/identifier
    //
    // File location diagram:
    // jetc/                          <- Main project folder
    // ├── README.md                  <- Project documentation
    // ├── [directory]/               <- File's directory
    // │   └── [filename]             <- THIS FILE
    // └── ...                        <- Other project files
    \`\`\`
*   **\`<!-- -->\` Style (Recommended for Markdown \`.md\`, HTML \`.html\`, XML \`.xml\`):**
    *   For Markdown files (\`.md\`), especially \`README.md\`, using HTML comments hides the header from the default rendered view on platforms like GitHub.
    *   Place the standard \`#\` style header *inside* the HTML comment block for consistency.
    \`\`\`markdown
    <!--
    # COMMIT-TRACKING: UUID-YYYYMMDD-HHMMSS-XXXX
    # Description: Brief description of changes
    # Author: Your name/identifier
    #
    # File location diagram:
    # jetc/                          <- Main project folder
    # ├── README.md                  <- Project documentation
    # ├── [directory]/               <- File's directory
    # │   └── [filename]             <- THIS FILE
    # └── ...                        <- Other project files
    -->

    # Actual Markdown Content Starts Here...
    \`\`\`

**Important Note on JSON:**

*   Standard JSON files (\`.json\`) **do not support comments**. Do **not** add the \`COMMIT-TRACKING\` header to these files. Rely on Git history for tracking changes to \`.json\` files.
*   VS Code configuration files like \`settings.json\` and \`extensions.json\` are often \`.jsonc\` (JSON with Comments) and **can** use the \`//\` style header.

## How to Use

1.  When modifying a file, ensure the \`COMMIT-TRACKING\` header is present at the top. If adding a header to a new file or a file without one, place it at the very top.
2.  **UUID Management:**
    *   **If the file being modified *already has* a \`COMMIT-TRACKING\` header:** **Reuse** the existing \`UUID-YYYYMMDD-HHMMSS-XXXX\` value from that header for your current set of changes. Use this *same reused UUID* across all files modified in the same logical commit/change set.
    *   **If the file does *not* have a header, or you are creating a new file:** **Generate** a *new* UUID for the current commit using the format \`UUID-YYYYMMDD-HHMMSS-XXXX\` (YYYYMMDD = current date, HHMMSS = current time, XXXX = random identifier like last 4 chars of git commit hash or random hex). Use this *same new UUID* across all files modified or created in this commit.
3.  Update the \`Description:\` line in the header with a brief summary of the changes made in this commit/change set.
4.  Update the \`Author:\` line if necessary. (e.g., to Mr K)
5.  Ensure the \`File location diagram:\` accurately reflects the file's path within the \`jetc\` project structure.
6.  Use the *same* UUID (whether reused or newly generated) across all files modified in the same logical commit.

## Example

For a file located at \`jetc/buildx/build.sh\`:

\`\`\`
# COMMIT-TRACKING: UUID-20250418-113042-7E2D
# Description: Fixed Docker buildx script syntax errors and improved build output handling
# Author: Mr K
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Current directory
# │   └── build.sh               <- THIS FILE
# └── ...                        <- Other project files
\`\`\`

## Commit Messages

When committing, use the UUID as part of your commit message:

\`\`\`
UUID-20250418-113042-7E2D: Fixed Docker buildx script syntax errors
\`\`\`

This allows easy cross-referencing between commits and the files that were modified.

## Additional Guidelines

1. Keep descriptions concise but informative
2. Make sure the file location diagram is accurate for each file
3. For multi-file commits, use the same UUID across all files
4. The UUID should be determined **once per commit/change set** (either reused from an existing file or newly generated) and applied consistently to all files touched in that set.
5. Add this header (using the correct comment style) to all new files as well as modified files, **except for standard \`.json\` files**.
`;
        fs.writeFileSync(instructionsFile, instructionsContent);
        console.log('Created GitHub Copilot instructions file');
    }
}

// Main execution
console.log('Setting up Copilot tracking system...');
validateSetup();
updateGitignore();
createSessionFolder();
createMissingFiles(); // Add this line
console.log('Setup complete! To use, type "header" and press Tab in your files.');
