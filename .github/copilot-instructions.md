<!--
# COMMIT-TRACKING: UUID-20240729-101500-B4E1
# Description: Add machine-readable YAML summary of instructions
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── .github/                   <- GitHub directory
# │   └── copilot-instructions.md<- THIS FILE
# └── ...                        <- Other project files
-->

# LOCAL INSTRUCTIONS - DO NOT COMMIT TO GIT

## File Header Format

All modified files should include this header format at the very top. **Choose the comment style appropriate for the file type.**

**Common Comment Styles:**

*   **`#` Style:** (Shell scripts `.sh`, Python `.py`, Dockerfile, YAML `.yml`, etc.)
    ```
    # COMMIT-TRACKING: UUID-YYYYMMDD-HHMMSS-XXXX
    # Description: Brief description of changes SPECIFIC TO THIS FILE
    # Author: Your name/identifier
    #
    # File location diagram:
    # jetc/                          <- Main project folder
    # ├── README.md                  <- Project documentation
    # ├── [directory]/               <- File's directory
    # │   └── [filename]             <- THIS FILE
    # └── ...                        <- Other project files
    ```
*   **`//` Style:** (JavaScript `.js`, TypeScript `.ts`/`.tsx`, JSON with Comments `.jsonc`, C/C++, Java, etc.)
    ```javascript
    // COMMIT-TRACKING: UUID-YYYYMMDD-HHMMSS-XXXX
    // Description: Brief description of changes SPECIFIC TO THIS FILE
    // Author: Your name/identifier
    //
    // File location diagram:
    // jetc/                          <- Main project folder
    // ├── README.md                  <- Project documentation
    // ├── [directory]/               <- File's directory
    // │   └── [filename]             <- THIS FILE
    // └── ...                        <- Other project files
    ```
*   **`<!-- -->` Style (Recommended for Markdown `.md`, HTML `.html`, XML `.xml`):**
    *   For Markdown files (`.md`), especially `README.md`, using HTML comments hides the header from the default rendered view on platforms like GitHub.
    *   Place the standard `#` style header *inside* the HTML comment block for consistency.
    ```markdown
    <!--
    # COMMIT-TRACKING: UUID-YYYYMMDD-HHMMSS-XXXX
    # Description: Brief description of changes SPECIFIC TO THIS FILE
    # Author: Your name/identifier
    #
    # File location diagram:
    # jetc/                          <- Main project folder
    # ├── README.md                  <- Project documentation
    # ├── [directory]/               <- File's directory
    # │   └── [filename]             <- THIS FILE
    # └── ...                        <- Other project files
    -->

    # Actual Markdown Content Starts Here...
    ```

**Important Note on JSON:**

*   Standard JSON files (`.json`) **do not support comments**. Do **not** add the `COMMIT-TRACKING` header to these files. Rely on Git history for tracking changes to `.json` files.
*   VS Code configuration files like `settings.json` and `extensions.json` are often `.jsonc` (JSON with Comments) and **can** use the `//` style header.

## How to Use

1.  When modifying a file, ensure the `COMMIT-TRACKING` header is present at the top. If adding a header to a new file or a file without one, place it at the very top.
2.  **UUID Management:**
    *   **If the file being modified *already has* a `COMMIT-TRACKING` header:** **Reuse** the existing `UUID-YYYYMMDD-HHMMSS-XXXX` value from that header for your current set of changes. Use this *same reused UUID* across all files modified in the same logical commit/change set.
    *   **If the file does *not* have a header, or you are creating a new file:** **Generate** a *new* UUID for the current commit using the format `UUID-YYYYMMDD-HHMMSS-XXXX` (YYYYMMDD = current date, HHMMSS = current time, XXXX = random identifier like last 4 chars of git commit hash or random hex). Use this *same new UUID* across all files modified or created in this commit.
3.  **Update the `Description:` line uniquely for each file:**
    *   While the UUID should be the same across all files in a commit, the description should describe the **specific changes made to that particular file**.
    *   Example: A commit that adds logging might have "Add logging functionality" in one file's header and "Update imports for new logging module" in another file's header, but both would share the same UUID.
    *   Avoid using generic descriptions that don't indicate what changed in the specific file.
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

## Machine-Readable Summary (YAML)

```yaml
# Summary of commit tracking and header rules for potential automation
commit_tracking:
  enabled: true
  header_required: true
  uuid_format: "UUID-YYYYMMDD-HHMMSS-XXXX" # XXXX = random identifier (e.g., hex)
  uuid_management:
    reuse_existing: true # Reuse UUID from file if present for the commit set
    generate_new: true   # Generate new UUID if no header exists in any modified file for the commit set
    consistency: "commit_set" # Use the same UUID across all files in one commit/change set
  fields:
    - name: "COMMIT-TRACKING"
      value_format: "UUID-YYYYMMDD-HHMMSS-XXXX"
      required: true
    - name: "Description"
      value_format: "string"
      required: true
      scope: "file_specific" # Description must be specific to the changes in THIS file
    - name: "Author"
      value_format: "string"
      required: true
    - name: "File location diagram"
      value_format: "multiline_string"
      required: true
      template: |
        jetc/                          <- Main project folder
        ├── README.md                  <- Project documentation
        ├── [directory]/               <- File's directory
        │   └── [filename]             <- THIS FILE
        └── ...                        <- Other project files
  comment_styles:
    - style: "#"
      extensions: [".sh", ".py", "Dockerfile", ".yml", ".yaml"]
      template: |
        # COMMIT-TRACKING: {uuid}
        # Description: {description}
        # Author: {author}
        #
        # File location diagram:
        # {diagram}
    - style: "//"
      extensions: [".js", ".ts", ".tsx", ".jsonc", ".c", ".cpp", ".java", ".go"] # Add other relevant extensions
      template: |
        // COMMIT-TRACKING: {uuid}
        // Description: {description}
        // Author: {author}
        //
        // File location diagram:
        // {diagram}
    - style: "<!-- -->"
      extensions: [".md", ".html", ".xml"]
      template: |
        <!--
        # COMMIT-TRACKING: {uuid}
        # Description: {description}
        # Author: {author}
        #
        # File location diagram:
        # {diagram}
        -->
  exclusions:
    - extension: ".json" # Standard JSON files do not support comments
  commit_message_format: "{uuid}: {summary}" # Example: UUID-20250418-113042-7E2D: Fixed Docker buildx script syntax errors
```

# COPILOT INSTRUCTIONS (STRICT MACHINE FORMAT)

- All code blocks must start with a filepath comment (e.g. `# filepath: ...`).
- Only show changed lines. For unchanged regions, use a single comment line: `...existing code...` (with correct comment style).
- Never repeat unchanged code.
- For new files: output full content, starting with filepath comment.
- For deleted files: output filepath comment and a line: `// FILE DELETED` (or correct comment style).
- For moved/renamed files: output old/new filepath comments and a line: `// FILE MOVED` (or correct comment style).
- Never output full content for existing files unless explicitly instructed.
- No explanations or extra context.

