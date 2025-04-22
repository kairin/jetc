#!/bin/bash
echo "Determining build order and filtering selected stages..."
BUILD_DIR="build"
if [ ! -d "$BUILD_DIR" ]; then
    echo "Error: Build directory '$BUILD_DIR' not found."
    exit 1
fi
declare -A selected_folders_map
if [[ -n "$SELECTED_FOLDERS_LIST" ]]; then
    for folder_name in $SELECTED_FOLDERS_LIST; do
        selected_folders_map["$folder_name"]=1
        echo "  Will build stage: $folder_name"
    done
else
    echo "  No specific stages selected by user. No numbered stages will be built."
fi
mapfile -t all_numbered_dirs < <(find "$BUILD_DIR" -maxdepth 1 -mindepth 1 -type d -name '[0-9]*-*' | sort)
numbered_dirs=()
if [[ ${#selected_folders_map[@]} -gt 0 ]]; then
    for dir in "${all_numbered_dirs[@]}"; do
        basename=$(basename "$dir")
        if [[ -v selected_folders_map[$basename] ]]; then
            numbered_dirs+=("$dir")
        fi
    done
    echo "Filtered numbered stages to build: ${#numbered_dirs[@]}"
elif [[ -z "$SELECTED_FOLDERS_LIST" ]]; then
     echo "No numbered stages were selected, skipping numbered builds."
fi
mapfile -t other_dirs < <(find "$BUILD_DIR" -maxdepth 1 -mindepth 1 -type d ! -name '[0-9]*-*' | sort)
