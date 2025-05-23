<!--
# COMMIT-TRACKING: UUID-20240802-160045-CFMT
# Description: Updated file with instructions to use system time for commit tracking and improved formatting
# Author: GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── copilot-must-follow.md <- THIS FILE
# └── ...                        <- Other project files
-->

# File Header Rules

## Commit Tracking Format

```yaml
commit_tracking:
  uuid_format: "UUID-YYYYMMDD-HHMMSS-XXXX"  # Use current system datetime for YYYYMMDD-HHMMSS
  uuid_rules:
    - reuse: When editing file with header
    - generate: When creating new file 
    - consistency: Same UUID across all files in one commit
    - datetime: Always use current system time when generating new UUIDs
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

## File Deletion/Consolidation Markers

When a file has been consolidated or incorporated elsewhere and should be deleted:

```yaml
deletion_markers:
  format: |
    ######################################################################
    # THIS FILE CAN BE DELETED
    # Reason for deletion (e.g., "All content consolidated in ../other-file.md")
    # You do NOT need this file anymore.
    ######################################################################
  placement: At the top of the file header, before the commit tracking info
  requirements:
    - Clearly state the file can be deleted
    - Specify where content was moved/consolidated
    - Include normal commit tracking after the deletion marker
  example: |
    ######################################################################
    # THIS FILE CAN BE DELETED
    # All content consolidated in ../parent-directory/main-file.md
    # You do NOT need this file anymore.
    ######################################################################
    # COMMIT-TRACKING: UUID-YYYYMMDD-HHMMSS-XXXX
    # Description: Marked for deletion - content moved to main file
    # Author: Your name
    # ...
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

## Additional Requirements

- Always retrieve the current date and time from the system when creating new commit tracking UUIDs
- For example, it is April 20th 2025 right now and the time is 09:05 hrs. By the time you are reading this, it has already passed this date and time.
- Follow minimal diff rules when modifying files (see copilot-instructions.md)
- Maintain consistent header structure across all files
- For new files, create a complete header with all required fields
- For edited files, update the description and consolidate the UUIDs if there are multiples.

## Dockerfile Standards for Jetson Compatibility

```yaml
dockerfile_standards:
  platform:
    - Use ARG for platform instead of hardcoding: "ARG TARGETPLATFORM=linux/arm64"
    - Reference with: "FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}"
    - Never use: "FROM --platform=linux/arm64 ${BASE_IMAGE}"
  base_image:
    - Always include: "ARG BASE_IMAGE=\"kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu\""
    - This ensures images work on Jetson Orin with Ubuntu 22.04+
  environment:
    - Target OS: Ubuntu 22.04 LTS (Jammy Jellyfish) or newer
    - Architecture: ARM64/AARCH64 (Jetson Orin specific)
    - CUDA compatibility: CUDA 11.4+ required
  recommendations:
    - Check ARM compatibility for all installed packages
    - Prefer apt packages when available over building from source
    - Test CUDA operations with small examples before heavy computation
```

## Example Dockerfile Header

```dockerfile
# COMMIT-TRACKING: UUID-YYYYMMDD-HHMMSS-XXXX
# Description: Description of this Dockerfile
# Author: Your Name
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Build directory
# │   └── build/                 <- Component directory
# │       └── component-name/    <- Current directory
# │           └── Dockerfile     <- THIS FILE
# └── ...                        <- Other project files

ARG TARGETPLATFORM=linux/arm64
ARG BASE_IMAGE="kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu"
FROM --platform=$TARGETPLATFORM ${BASE_IMAGE}

# Rest of Dockerfile...
```
