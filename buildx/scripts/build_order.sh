#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/build_order.sh

# =========================================================================
# Build Order Determination Script
# Responsibility: Determine the correct order of build stages based on
#                 folder names and user selections.
# =========================================================================

# --- Dependencies ---
SCRIPT_DIR_ORDER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# --- Constants ---
BUILD_DIR="$(realpath "$SCRIPT_DIR_ORDER/../build")" # Assumes build dir is one level up

# =========================================================================
# Function: Determine the build order based on numbered folders
# Arguments: $1 = selected_folders_list (space-separated string of folder basenames from user interaction, or empty/null to build all)
# Returns: Echoes the ordered list of full folder paths, one per line. Exit code 0 on success, 1 on error.
# =========================================================================
determine_build_order() {
    local selected_folders_list="${1:-}" # Capture selected folders, default to empty
    local ordered_build_folders=()

    log_info "--- Determining Build Order ---"
    log_debug "Build directory: $BUILD_DIR"
    log_debug "Raw selected folders list: '$selected_folders_list'"

    if [ ! -d "$BUILD_DIR" ]; then
        log_error "Build directory not found: $BUILD_DIR"
        return 1
    fi

    # Find all numbered directories (e.g., 01-*, 10-*)
    # Use mapfile for safer handling of paths with spaces/special chars
    local numbered_folders=()
    mapfile -t numbered_folders < <(find "$BUILD_DIR" -maxdepth 1 -mindepth 1 -type d -name '[0-9]*-*' | sort -V)

    if [ ${#numbered_folders[@]} -eq 0 ]; then
        log_warning "No numbered build stage folders found in $BUILD_DIR."
        # Echo nothing, return success (nothing to build)
        return 0
    fi

    # If no specific folders were selected, build all numbered folders found
    if [[ -z "$selected_folders_list" ]]; then
        log_info "No specific stages selected by user. Building all found numbered stages."
        # Add all found folders to the ordered list
        for folder_path in "${numbered_folders[@]}"; do
            ordered_build_folders+=("$folder_path")
        done
    else
        log_info "User selected specific stages: $selected_folders_list"
        # Use an associative array for efficient lookup of selected folders
        declare -A temp_selected_map # <-- FIX: Declare the associative array

        # Populate the map with selected folder names
        log_debug "Populating selection map..."
        for sel_folder in $selected_folders_list; do
            if [[ -n "$sel_folder" ]]; then # Avoid adding empty strings if list had extra spaces
                 log_debug "Adding '$sel_folder' to selection map."
                 temp_selected_map["$sel_folder"]=1
            fi
        done
        log_debug "Selection map populated."


        # Iterate through the *sorted* list of all found numbered folders
        for folder_path in "${numbered_folders[@]}"; do
            local folder_name
            folder_name=$(basename "$folder_path")

            # Check if this folder name exists in the selected map
            # Use [[ -v ... ]] which is the correct way to check key existence in bash 4.3+
            # Use [[ ${temp_selected_map[$folder_name]+_} ]] for older bash versions (safer)
            # if [[ -v temp_selected_map[$folder_name] ]]; then # Bash 4.3+
            if [[ ${temp_selected_map[$folder_name]+_} ]]; then # <-- FIX: Check if key exists
                log_debug "Stage '$folder_name' is selected. Adding to build order."
                ordered_build_folders+=("$folder_path")
            else
                log_debug "Stage '$folder_name' is NOT selected. Skipping."
            fi
        done
    fi

    if [ ${#ordered_build_folders[@]} -eq 0 ]; then
         log_warning "No build stages selected or matched. Nothing to build."
         # Echo nothing, return success
         return 0
    fi


    log_info "Final determined build order (${#ordered_build_folders[@]} stages):"
    # Echo the full paths, one per line
    for folder in "${ordered_build_folders[@]}"; do
        echo "$folder"
        log_info "  - $(basename "$folder")" # Log just the basename for readability
    done
    log_info "--- Build Order Determined ---"

    return 0
}

# --- Main Execution (for testing) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_info "Running build_order.sh directly for testing..."

    # --- Test Setup --- #
    test_build_dir="/tmp/test_build_order_$$"
    mkdir -p "$test_build_dir"/{01-first,05-middle,10-last,non-numbered,02-second}
    log_info "Created dummy build dir: $test_build_dir"
    export BUILD_DIR="$test_build_dir" # Override for testing

    # --- Test Cases --- #
    log_info ""
    log_info "*** Test 1: Build all ***"
    determine_build_order "" # Pass empty string for 'build all'

    log_info ""
    log_info "*** Test 2: Select specific stages (01-first 10-last) ***"
    determine_build_order "01-first 10-last"

    log_info ""
    log_info "*** Test 3: Select specific stages (out of order: 05-middle 01-first) ***"
    determine_build_order "05-middle 01-first"

    log_info ""
    log_info "*** Test 4: Select non-existent stage (03-missing) ***"
    determine_build_order "03-missing"

    log_info ""
    log_info "*** Test 5: Select mixed existent and non-existent (01-first 03-missing 10-last) ***"
    determine_build_order "01-first 03-missing 10-last"

    log_info ""
    log_info "*** Test 6: Select non-numbered stage (should be ignored) ***"
    determine_build_order "non-numbered"


    # --- Cleanup --- #
    log_info ""
    log_info "Cleaning up test directory: $test_build_dir"
    rm -rf "$test_build_dir"
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
#              Fixed unbound variable error by declaring and populating associative map.
# Author: Mr K / GitHub Copilot / kairin
# COMMIT-TRACKING: UUID-20250424-194646-ORDERFIX
