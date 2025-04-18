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

1. When modifying a file, add this header at the top
2. Generate a new UUID with format "UUID-YYYYMMDD-HHMMSS-XXXX" where:
   - YYYYMMDD = current date
   - HHMMSS = current time
   - XXXX = random identifier (e.g., last 4 chars of git commit or random hex)
3. Add a brief description of your changes
4. Update the file location diagram to reflect the actual location of the file
5. Use the same UUID across all files modified in the same commit

## Example

For a file located at `jetc/buildx/build.sh`:

```
# COMMIT-TRACKING: UUID-20250418-113042-7E2D
# Description: Fixed Docker buildx script syntax errors and improved build output handling
# Author: GitHub Copilot / User
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
4. The UUID should be generated once per commit, not per file
5. Add this header to all new files as well as modified files

