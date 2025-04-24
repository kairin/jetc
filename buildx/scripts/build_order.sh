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
# BUILD_DIR is now passed as an argument

# =========================================================================
# Function: Determine the build order based on numbered folders
# Arguments: $1 = build_dir (path to the build directory)
#            $2 = selected_folders_list (space-separated string of folder basenames from user interaction, or empty/null to build all)
# Returns: Echoes the ordered list of full folder paths, one per line. Exports ORDERED_FOLDERS array. Exit code 0 on success, 1 on error.
# =========================================================================
determine_build_order() {
    local build_dir="${1}"               # Capture build directory path
    local selected_folders_list="${2:-}" # Capture selected folders, default to empty
    # Use a global array to store the result, as echoing and capturing can be tricky with newlines/spaces
    declare -g ORDERED_FOLDERS=() # Declare as global array

    log_info "--- Determining Build Order ---"
    log_debug "Build directory: $build_dir"
    log_debug "Raw selected folders list: '$selected_folders_list'"

    if [ ! -d "$build_dir" ]; then
        log_error "Build directory not found: $build_dir"
        return 1
    fi

    # Find all numbered directories (e.g., 01-*, 10-*)
    # Use mapfile for safer handling of paths with spaces/special chars
    local numbered_folders=()
    mapfile -t numbered_folders < <(find "$build_dir" -maxdepth 1 -mindepth 1 -type d -name '[0-9]*-*' | sort -V)

    if [ ${#numbered_folders[@]} -eq 0 ]; then
        log_warning "No numbered build stage folders found in $build_dir."
        # ORDERED_FOLDERS remains empty, return success (nothing to build)
        return 0
    fi

    # If no specific folders were selected, build all numbered folders found
    if [[ -z "$selected_folders_list" ]]; then
        log_info "No specific stages selected by user. Building all found numbered stages."
        # Add all found folders to the global array
        for folder_path in "${numbered_folders[@]}"; do
            ORDERED_FOLDERS+=("$folder_path")
        done
    else
        log_info "User selected specific stages: $selected_folders_list"
        # Use an associative array for efficient lookup of selected folders
        declare -A temp_selected_map # Local associative array for lookup

        # Populate the map with selected folder names
        log_debug "Populating selection map..."
        for sel_folder in $selected_folders_list; do # Iterate over the words in the list
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
            # Use [[ ${temp_selected_map[$folder_name]+_} ]] for compatibility
            if [[ ${temp_selected_map[$folder_name]+_} ]]; then
                log_debug "Stage '$folder_name' is selected. Adding to build order."
                ORDERED_FOLDERS+=("$folder_path") # Add to global array
            else
                log_debug "Stage '$folder_name' is NOT selected. Skipping."
            fi
        done
    fi

    if [ ${#ORDERED_FOLDERS[@]} -eq 0 ]; then
         log_warning "No build stages selected or matched. Nothing to build."
         # ORDERED_FOLDERS remains empty, return success
         return 0
    fi


    log_info "Final determined build order (${#ORDERED_FOLDERS[@]} stages):"
    # Log the final order for verification
    for folder in "${ORDERED_FOLDERS[@]}"; do
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
    # export BUILD_DIR="$test_build_dir" # No longer needed, pass as arg

    # Helper to run and print results
    run_test() {
        local description="$1"
        local build_dir_arg="$2"
        local selection_arg="$3"
        log_info ""
        log_info "*** $description ***"
        # Clear global array before test
        ORDERED_FOLDERS=()
        if determine_build_order "$build_dir_arg" "$selection_arg"; then
            log_success "determine_build_order succeeded."
            log_info "Resulting ORDERED_FOLDERS (${#ORDERED_FOLDERS[@]}):"
            if [[ ${#ORDERED_FOLDERS[@]} -gt 0 ]]; then
                printf '  %s\n' "${ORDERED_FOLDERS[@]}"
            else
                log_info "  (empty)"
            fi
        else
            log_error "determine_build_order failed."
        fi
        echo "--------------------"
    }


    # --- Test Cases --- #
    run_test "Test 1: Build all" "$test_build_dir" ""
    run_test "Test 2: Select specific stages (01-first 10-last)" "$test_build_dir" "01-first 10-last"
    run_test "Test 3: Select specific stages (out of order: 05-middle 01-first)" "$test_build_dir" "05-middle 01-first"
    run_test "Test 4: Select non-existent stage (03-missing)" "$test_build_dir" "03-missing"
    run_test "Test 5: Select mixed existent and non-existent (01-first 03-missing 10-last)" "$test_build_dir" "01-first 03-missing 10-last"
    run_test "Test 6: Select non-numbered stage (should be ignored)" "$test_build_dir" "non-numbered"
    run_test "Test 7: Invalid build dir" "/tmp/nonexistent_dir_$$" ""


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
#              Accepts build_dir as $1, selection_list as $2. Exports ORDERED_FOLDERS array.
# Author: Mr K / GitHub Copilot / kairin
# COMMIT-TRACKING: UUID-20250424-195555-ORDERFIX2
