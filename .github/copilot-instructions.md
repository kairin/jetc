# Jetson Container Development Instructions

> **This file is the canonical source for all coding standards, minimal diff rules, and commit tracking/footer requirements for the Jetson Container project. All contributors and automation must refer to this file for compliance.**

No full content for existing files unless requested
- No explanations or extra context

Come back to check this file again before responding to anything.

## Minimal Diff Rules

copilot_minimal_diff:
  - "# filepath: <path>" at top of every code block
  - Never repeat unchanged code
  - Use "# ...existing code..." for unchanged regions
  - New file: output full content with filepath
  - Deleted file: filepath + "// FILE DELETED"
  - Moved file: old/new filepaths + "// FILE MOVED"
  - No full content for existing files unless requested
  - No explanations or extra context

## Request Interpretation Rules

request_interpretation:
  - Analyze requests carefully before proposing code changes
  - Questions about how code works require explanations, not modifications
  - Use explanations for: "how does X work", "can you explain", "can we review"
  - Only generate code for: "create", "implement", "update", "fix", "modify"
  - Always check file status and confirm before making changes
  - Never load instructions when answering informational questions
  - Never assume file changes are needed unless explicitly requested
  - For analytical requests, prioritize explanation over code generation
  - When in doubt, ask for clarification rather than suggesting changes
  - Respond to the request type - explanation or code modification

## Coding Standards

The coding standards and footer rules for this project are defined here. All scripts and markdown files must comply with these standards.

- Place commit tracking information at the **BOTTOM** of all files, not the top.
- Use current date and time for new commit tracking UUIDs.
- Maintain consistent footer structure across all files.
- The footer must include:
  - File location diagram (showing the file's place in the project)
  - Description
  - Author
  - COMMIT-TRACKING UUID

See `.github/INSTRUCTIONS.md` for summary and enforcement rules.

---

<!--
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Main project README
# ├── .github/                   <- Copilot and git integration
# │   ├── copilot-instructions.md<- THIS FILE (canonical coding standards)
# │   ├── INSTRUCTIONS.md        <- Enforcement and summary
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
# │   └── scripts/               <- Modular build scripts
# └── ...                        <- Other project files
#
# Description: Canonical coding standards, minimal diff rules, and commit tracking/footer requirements for Jetson Container project. All contributors must comply.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20240805-200000-COPILOTINST
-->

