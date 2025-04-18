# COMMIT-TRACKING: UUID-20240729-004815-A3B1
# Description: Clarify UUID reuse policy in instructions
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

All modified files should include this header format:

```
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
```

## How to Use

1.  When modifying a file, ensure the `COMMIT-TRACKING` header is present at the top. If adding a header to a new file or a file without one, place it at the very top.
2.  **UUID Management:**
    *   **If the file being modified *already has* a `COMMIT-TRACKING` header:** **Reuse** the existing `UUID-YYYYMMDD-HHMMSS-XXXX` value from that header for your current set of changes. Use this *same reused UUID* across all files modified in the same logical commit/change set.
    *   **If the file does *not* have a header, or you are creating a new file:** **Generate** a *new* UUID for the current commit using the format `UUID-YYYYMMDD-HHMMSS-XXXX` (YYYYMMDD = current date, HHMMSS = current time, XXXX = random identifier like last 4 chars of git commit hash or random hex). Use this *same new UUID* across all files modified or created in this commit.
3.  Update the `Description:` line in the header with a brief summary of the changes made in this commit/change set.
4.  Update the `Author:` line if necessary. (e.g., to Mr K)
5.  Ensure the `File location diagram:` accurately reflects the file's path within the `jetc` project structure.
6.  Use the *same* UUID (whether reused or newly generated) across all files modified in the same logical commit.

## Example

For a file located at `jetc/buildx/build.sh`:

```
# COMMIT-TRACKING: UUID-20250418-113042-7E2D
# Description: Fixed Docker buildx script syntax errors and improved build output handling
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Current directory
# │   └── build.sh               <- THIS FILE
# └── ...                        <- Other project files
```

## Commit Messages

When committing, use the UUID as part of your commit message:

```
UUID-20250418-113042-7E2D: Fixed Docker buildx script syntax errors
```

This allows easy cross-referencing between commits and the files that were modified.

## Additional Guidelines

1. Keep descriptions concise but informative
2. Make sure the file location diagram is accurate for each file
3. For multi-file commits, use the same UUID across all files
4. The UUID should be determined **once per commit/change set** (either reused from an existing file or newly generated) and applied consistently to all files touched in that set.
5. Add this header to all new files as well as modified files

