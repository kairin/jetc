# Jetson Container Development Instructions

## File Header and Footer Compliance (MANDATORY)

- **No file should have any commit tracking, file location diagram, or author information at the top.**
- **All such metadata must be placed at the BOTTOM of the file, as a Markdown comment block.**
- **If you find any commit tracking, file location diagram, or author block at the top, REMOVE it and move it to the bottom.**
- **The only allowed content at the top of a file is the actual code or documentation.**
- **If you see any non-compliant file, FIX IT.**
- **Do not leave old commit tracking or file location diagrams at the top under any circumstances.**

## Minimal Diff Rules

- Always use `# filepath: <path>` at the top of every code block.
- Never repeat unchanged code; use `# ...existing code...` for unchanged regions.
- For new files, output full content with filepath.
- For deleted files, output filepath + `// FILE DELETED`.
- For moved files, output old/new filepaths + `// FILE MOVED`.
- No full content for existing files unless requested.
- No explanations or extra context.

## Commit Tracking and Footer

- Place commit tracking information at the **BOTTOM** of all files, not the top.
- Use current date and time for new commit tracking UUIDs.
- Maintain consistent footer structure across all files.
- The footer must include:
  - File location diagram (showing the file's place in the project)
  - Description
  - Author
  - COMMIT-TRACKING UUID

## Request Interpretation Rules

- Analyze requests carefully before proposing code changes.
- Only generate code for: "create", "implement", "update", "fix", "modify".
- For analytical requests, prioritize explanation over code generation.
- Never assume file changes are needed unless explicitly requested.
- When in doubt, ask for clarification rather than suggesting changes.

## Coding Standards

- Follow all comment style, commit tracking, and minimal diff rules as defined in `/home/ks/apps/jetc/buildx/scripts/copilot-must-follow.md`.
- All scripts and markdown files must comply with these standards.

## Error Correction and Enforcement

- If you detect any non-compliance (e.g., old commit tracking at the top), your next response **must** include a minimal diff to correct it.
- Always check for compliance before and after making changes.
- If you are asked to review or update instructions, ensure these compliance rules are included and highlighted.

---

<!--
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Main project README
# ├── proposed-app-build-sh.md   <- Proposed build.sh UI/workflow
# ├── proposed-app-jetcrun-sh.md <- Proposed jetcrun.sh UI/workflow
# ├── .env                       <- Environment/config file
# ├── .gitattributes
# ├── .gitignore
# ├── .github/                   <- Copilot and git integration
# │   ├── copilot-instructions.md
# │   ├── git-template-setup.md
# │   ├── install-hooks.sh
# │   ├── pre-commit-hook.sh
# │   ├── prepare-commit-msg-hook.sh
# │   ├── setup-git-template.sh
# │   └── vs-code-snippets-guide.md
# ├── buildx/                    <- Build system and scripts
# │   ├── build/                 <- Build stages and Dockerfiles
# │   ├── build.sh               <- Main build orchestrator
# │   ├── jetcrun.sh             <- Container run utility
# │   ├── scripts/               <- Modular build scripts
# │   │   ├── build_ui.sh
# │   │   ├── commit_tracking.sh
# │   │   ├── copilot-must-follow.md
# │   │   ├── docker_helpers.sh
# │   │   ├── logging.sh
# │   │   ├── utils.sh
# │   │   └── verification.sh
# │   └── logs/                  <- Build logs
# └── ...                        <- Other project files
#
# Description: Development instructions for Jetson container project, including file header/footer compliance, minimal diff rules, commit tracking, request interpretation, coding standards, and error correction.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250422-064000-DEVINST
-->