/*
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

// LOCAL INSTRUCTIONS - DO NOT COMMIT TO GIT
*/

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

// Main execution
console.log('Setting up Copilot tracking system...');
validateSetup();
updateGitignore();
createSessionFolder();
createMissingFiles(); // Add this line
console.log('Setup complete! To use, type "header" and press Tab in your files.');
