# COMMIT-TRACKING: UUID-20240729-004815-A3B1
# Description: Add header, update author
# Author: Mr K
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── .vscode/                   <- VSCode settings directory
# │   └── init_copilot.js        <- THIS FILE
# └── ...                        <- Other project files

// This script can be loaded by the VSCode Custom Editor API when available
// or used with VSCode extensions that support JS hooks

(function() {
  // Generate UUID in required format
  function generateTrackingID() {
    const now = new Date();
    const date = now.toISOString().slice(0,10).replace(/-/g,'');
    const time = now.toTimeString().slice(0,8).replace(/:/g,'');
    const random = Math.random().toString(16).substring(2,6).toUpperCase();
    return `UUID-${date}-${time}-${random}`;
  }
  
  // Defines a hook that can be exported for extensions that support it
  const uuid = generateTrackingID();
  
  // Export for use by compatible extensions
  exports.copilotConfig = {
    fileHeaderTemplate: `COMMIT-TRACKING: ${uuid}`,
    trackingUUID: uuid,
    templatePath: ".copilot_instructions"
  };
})();
