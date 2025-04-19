<!--
# COMMIT-TRACKING: UUID-20240729-101500-B4E1
# Description: Condensed instructions to essential rules and minimal format
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── .github/                   <- GitHub directory
# │   └── copilot-instructions.md<- THIS FILE
# └── ...                        <- Other project files
-->

# File Header Rules

```yaml
commit_tracking:
  uuid_format: "UUID-YYYYMMDD-HHMMSS-XXXX"
  uuid_rules:
    - reuse: When editing file with header
    - generate: When creating new file
    - consistency: Same UUID across all files in one commit
  required_fields:
    - "COMMIT-TRACKING": UUID-YYYYMMDD-HHMMSS-XXXX
    - "Description": File-specific changes description
    - "Author": Your name/identifier 
    - "File location diagram": Project structure showing file location
  comment_styles:
    - "#": [.sh, .py, Dockerfile, .yml, .yaml]
    - "//": [.js, .ts, .tsx, .jsonc, .c, .cpp, .java, .go]
    - "<!-- -->": [.md, .html, .xml] # Place # style inside for .md
  exclusions:
    - ".json": No comments supported
  commit_message: "{uuid}: {summary}"
```

## Example Header

```sh
# COMMIT-TRACKING: UUID-20250418-113042-7E2D
# Description: Fixed Docker buildx script syntax errors
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Current directory
# │   └── build.sh               <- THIS FILE
# └── ...                        <- Other project files
```

## Minimal Diff Rules

```yaml
copilot_minimal_diff:
  - "# filepath: <path>" at top of every code block
  - Never repeat unchanged code
  - Use "# ...existing code..." for unchanged regions
  - New file: output full content with filepath
  - Deleted file: filepath + "// FILE DELETED"
  - Moved file: old/new filepaths + "// FILE MOVED"
  - No full content for existing files unless requested
  - No explanations or extra context
```

### Example:
```python
# filepath: /path/to/file.py
# ...existing code...
def new_func(): pass
# ...existing code...
```

