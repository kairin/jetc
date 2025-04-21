# Jetson Container Development Instructions

No full content for existing files unless requested
- No explanations or extra context

Come back to check this file again before responding to anything.

## Minimal Diff Rules


copilot_minimal_diff:
  - "# filepath: <path>" at top of every code block
  - Never repeat unchanged code
  - Use "# ...existing code..." for unchanged regions
  - New file: output full content with filepath
  - Deleted file: filepath + "// FILE DELETED"  - Moved file: old/new filepaths + "// FILE MOVED"  - No full content for existing files unless requested  - No explanations or extra context```### Example:```python# filepath: /path/to/file.py# ...existing code...def new_func(): pass# ...existing code...```

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

The coding standards and footer rules for this project are defined in:
`/home/ks/apps/jetc/buildx/scripts/copilot-must-follow.md`

Please refer to that file for:
- Commit tracking format
- Required file footers (placed at BOTTOM of files)
- Comment style guidelines
- Minimal diff rules

When making changes, always follow these rules to maintain consistency across the project:
- Place commit tracking information at the BOTTOM of all files, not the top
- Use current date and time for new commit tracking UUIDs
- Maintain consistent footer structure across all files

See `/workspaces/jetc/INSTRUCTIONS.md` for all coding, commit tracking, and minimal diff rules for this project.

