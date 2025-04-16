#!/bin/bash

# =========================================================================
# IMPORTANT: This build system requires Docker with buildx extension.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# =========================================================================
# Script to add a prominent note about Docker buildx to all scripts and Dockerfiles

# Define the notes
SCRIPT_NOTE="# =========================================================================
# IMPORTANT: This build system requires Docker with buildx extension.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# ========================================================================="

DOCKERFILE_NOTE="# =========================================================================
# IMPORTANT: This Dockerfile is designed to be built with Docker buildx.
# All builds MUST use Docker buildx to ensure consistent
# multi-platform and efficient build processes.
# ========================================================================="

# Root directory of repository
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"

# Function to add note to a file
add_note_to_file() {
    local file="$1"
    local note="$2"
    local shebang=""
    
    # Check if file has a shebang line
    if grep -q "^#!" "$file"; then
        # Extract the shebang line
        shebang=$(head -n 1 "$file")
        # Remove the shebang line for processing
        sed -i.bak '1d' "$file"
        # Add shebang, note, and original content
        echo "$shebang" > "$file.new"
        echo "" >> "$file.new"
        echo "$note" >> "$file.new"
        cat "$file" >> "$file.new"
    else
        # Add note and original content
        echo "$note" > "$file.new"
        echo "" >> "$file.new"
        cat "$file" >> "$file.new"
    fi
    
    # Replace original with new file
    mv "$file.new" "$file"
    rm -f "$file.bak"
}

# Find all shell scripts
echo "Adding buildx note to shell scripts..."
find "$REPO_ROOT" -name "*.sh" -o -name "*.bash" | while read -r script; do
    echo "Processing: $script"
    add_note_to_file "$script" "$SCRIPT_NOTE"
done

# Find all Dockerfiles
echo "Adding buildx note to Dockerfiles..."
find "$REPO_ROOT" -name "Dockerfile" -o -name "*.dockerfile" | while read -r dockerfile; do
    echo "Processing: $dockerfile"
    add_note_to_file "$dockerfile" "$DOCKERFILE_NOTE"
done

echo "Completed adding buildx notes to all scripts and Dockerfiles."
