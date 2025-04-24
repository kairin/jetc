#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/build_order.sh

# =========================================================================
# Build Order Determination Script
# Responsibility: Determine the sequence of build stages based on folder names
#                 and user selection.
# =========================================================================

# --- Dependencies ---
SCRIPT_DIR_ORDER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$(realpath "$SCRIPT_DIR_ORDER/../build")"

# Source required scripts (use fallbacks if sourcing fails)
if [ -f "$SCRIPT_DIR_ORDER/env_setup.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_ORDER/env_setup.sh"
else
    echo "Warning: env_setup.sh not found. Logging/colors may be basic." >&2
    log_info() { echo "INFO: $1"; }
    log_warning() { echo "WARNING: $1" >&2; }
    log_error() { echo "ERROR: $1" >&2; }
    log_success() { echo "SUCCESS: $1"; }
    log_debug() { :; }
fi

# --- Functions --- #

# Determine the build order based on numbered folders and user selection.
# Input: $1 = SELECTED_FOLDERS_LIST (space-separated string of folder basenames, optional)
# Exports: ORDERED_FOLDERS (array of full paths)
# Exports: SELECTED_FOLDERS_MAP (associative array: [folder_basename]=1)
# Return: 0 on success, 1 if build directory not found.
determine_build_order() {
    local selected_list="$1"
    log_info "--- Determining Build Order ---"

    if [ ! -d "$BUILD_DIR" ]; then
        log_error "Build directory not found: $BUILD_DIR"
        return 1
    fi

    # Find all numbered directories and sort them naturally
    local all_folders=()
    mapfile -t all_folders < <(find "$BUILD_DIR" -maxdepth 1 -mindepth 1 -type d -name '[0-9]*-*' | sort -V)

    if [ ${#all_folders[@]} -eq 0 ]; then
        log_warning "No numbered build stage directories found in $BUILD_DIR."
        export ORDERED_FOLDERS=()
        declare -gA SELECTED_FOLDERS_MAP=()
        export SELECTED_FOLDERS_MAP
        return 0
    fi

    log_debug "Found ${#all_folders[@]} potential build stages:"
    for folder in "${all_folders[@]}"; do
        log_debug "  - $(basename "$folder")"
    done

    # Filter based on user selection if provided
    declare -gA temp_selected_map # Use a temporary map
    local use_all=1 # Assume all folders are used unless a specific list is given

    if [ -n "$selected_list" ]; then
        use_all=0
        log_info "User selected specific stages: $selected_list"
        for folder_name in $selected_list; do
            temp_selected_map["$folder_name"]=1
        done
    else
        log_info "No specific stages selected by user, including all found numbered stages."
    fi

    # Build the final ordered list and the map
    local final_ordered_folders=()
    declare -gA final_selected_map # Use -gA to make it globally available

    for folder_path in "${all_folders[@]}"; do
        local folder_name
        folder_name=$(basename "$folder_path")
        if [[ $use_all -eq 1 || -n "${temp_selected_map[$folder_name]}" ]]; then
            final_ordered_folders+=("$folder_path")
            final_selected_map["$folder_name"]=1
            log_debug " -> Including stage: $folder_name"
        else
            log_debug " -> Excluding stage (not selected): $folder_name"
        fi
    done

    # Export the results
    export ORDERED_FOLDERS=("${final_ordered_folders[@]}")
    # Exporting associative arrays requires careful handling; declare -p is one way
    # However, simply declaring it with -gA makes it available to sourced scripts
    export SELECTED_FOLDERS_MAP # Make the name known
    # The actual map 'final_selected_map' is now globally available as SELECTED_FOLDERS_MAP
    # due to the naming convention and -gA. Let's rename for clarity.
    declare -gA SELECTED_FOLDERS_MAP="${final_selected_map[@]@A}" # Copy content

    log_success "Build order determined. ${#ORDERED_FOLDERS[@]} stages selected."
    if [ ${#ORDERED_FOLDERS[@]} -gt 0 ]; then
        log_debug "Final build order:"
        for folder in "${ORDERED_FOLDERS[@]}"; do
            log_debug "  - $(basename "$folder")"
        done
    fi

    return 0
}

# --- Main Execution (for testing) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_info "Running build_order.sh directly for testing..."

    # --- Test Setup --- #
    # Create dummy build directories
    test_build_dir="/tmp/test_build_order_$$/build"
    mkdir -p "$test_build_dir/01-first-stage"
    mkdir -p "$test_build_dir/10-last-stage"
    mkdir -p "$test_build_dir/02-second-stage"
    mkdir -p "$test_build_dir/non-numbered-stage"
    log_info "Created dummy build dir: $test_build_dir"
    export BUILD_DIR="$test_build_dir" # Override for testing

    # --- Test Cases --- #
    log_info "Test 1: No specific selection (should include all numbered)"
    determine_build_order ""
    echo "ORDERED_FOLDERS: ${ORDERED_FOLDERS[*]}"
    declare -p SELECTED_FOLDERS_MAP
    echo "--------------------"

    log_info "Test 2: Specific selection"
    determine_build_order "01-first-stage 10-last-stage"
    echo "ORDERED_FOLDERS: ${ORDERED_FOLDERS[*]}"
    declare -p SELECTED_FOLDERS_MAP
    echo "--------------------"

    log_info "Test 3: Selection with non-existent stage"
    determine_build_order "01-first-stage non-existent-stage"
    echo "ORDERED_FOLDERS: ${ORDERED_FOLDERS[*]}"
    declare -p SELECTED_FOLDERS_MAP
    echo "--------------------"

    # --- Cleanup --- #
    log_info "Cleaning up test directory: $(dirname "$test_build_dir")"
    rm -rf "$(dirname "$test_build_dir")"
    log_info "Build order script test finished."
    exit 0
fi

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── build_order.sh     <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Determines the build order of stages based on folder names and user selection.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-094000-BLDORD
