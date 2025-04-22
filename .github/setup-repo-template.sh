#!/bin/bash

# COMMIT-TRACKING: UUID-20250422-083100-REPO
# Description: Script to set up a repository template based on the current repository
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── .github/                   <- GitHub directory
# │   └── setup-repo-template.sh <- THIS FILE
# └── ...                        <- Other project files

# Function to copy necessary files and directories
copy_files() {
  local src_dir=$1
  local dest_dir=$2

  # Create destination directory if it doesn't exist
  mkdir -p "$dest_dir"

  # Copy .github directory
  cp -r "$src_dir/.github" "$dest_dir"

  # Copy buildx directory
  cp -r "$src_dir/buildx" "$dest_dir"

  # Copy README.md
  cp "$src_dir/README.md" "$dest_dir"
}

# Function to update README.md file
update_readme() {
  local readme_file=$1
  local new_repo_name=$2

  # Update the repository name in the README.md file
  sed -i "s/kairin\/jetc/$new_repo_name/g" "$readme_file"
}

# Main script
main() {
  local src_dir=$(pwd)
  local dest_dir=$1
  local new_repo_name=$2

  if [ -z "$dest_dir" ] || [ -z "$new_repo_name" ]; then
    echo "Usage: $0 <destination_directory> <new_repository_name>"
    exit 1
  fi

  # Copy necessary files and directories
  copy_files "$src_dir" "$dest_dir"

  # Update README.md file
  update_readme "$dest_dir/README.md" "$new_repo_name"

  echo "Repository template setup complete!"
}

main "$@"

# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── .github/                   <- GitHub directory
# │   └── setup-repo-template.sh <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Script to set up a repository template based on the current repository
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250422-083100-REPO
