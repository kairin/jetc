<!--le Header Rules
# COMMIT-TRACKING: UUID-20240801-155000-RFIR
# Description: Added request interpretation rules to prevent undesired behaviors
# Author: GitHub Copilot
#``yaml
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── copilot-must-follow.md <- THIS FILEone commit
# └── ...                        <- Other project files
--> - "COMMIT-TRACKING": UUID-YYYYMMDD-HHMMSS-XXXX
    - "Description": File-specific changes description
# File Header Rulesr name/identifier 
    - "File location diagram": Project structure showing file location
```yamlnt_styles:
commit_tracking: .py, Dockerfile, .yml, .yaml]
  uuid_format: "UUID-YYYYMMDD-HHMMSS-XXXX"cpp, .java, .go]
  uuid_rules:->": [.md, .html, .xml] # Place # style inside for .md
    - reuse: When editing file with header
    - generate: When creating new file
    - consistency: Same UUID across all files in one commit
  required_fields:
    - "COMMIT-TRACKING": UUID-YYYYMMDD-HHMMSS-XXXX
    - "Description": File-specific changes description
    - "Author": Your name/identifier 
    - "File location diagram": Project structure showing file location
  comment_styles:: UUID-20250418-113042-7E2D
    - "#": [.sh, .py, Dockerfile, .yml, .yaml]ax errors
    - "//": [.js, .ts, .tsx, .jsonc, .c, .cpp, .java, .go]
    - "<!-- -->": [.md, .html, .xml] # Place # style inside for .md
  exclusions:on diagram:
    - ".json": No comments supportedMain project folder
  commit_message: "{uuid}: {summary}"roject documentation
```── buildx/                    <- Current directory
# │   └── build.sh               <- THIS FILE
## Example Header                <- Other project files
```
```sh
# COMMIT-TRACKING: UUID-20250418-113042-7E2D
# Description: Fixed Docker buildx script syntax errors
# Author: Mr K / GitHub Copilot
#opilot_minimal_diff:
# File location diagram: at top of every code block
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Current directory
# │   └── build.sh               <- THIS FILE"
# └── ...                        <- Other project files
