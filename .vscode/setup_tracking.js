/**
 * COMMIT-TRACKING: UUID-20250418-131520-2F4C
 * Description: Setup script for initializing the tracking system
 * Author: GitHub Copilot / User
 *
 * File location diagram:
 * jetc/                          <- Main project folder
 * ├── README.md                  <- Project documentation
 * ├── .vscode/                   <- VSCode settings directory
 * │   └── setup_tracking.js      <- THIS FILE
 * └── ...                        <- Other project files
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

// Main execution
console.log('Setting up Copilot tracking system...');
validateSetup();
updateGitignore();
createSessionFolder();
console.log('Setup complete! To use, type "header" and press Tab in your files.');
