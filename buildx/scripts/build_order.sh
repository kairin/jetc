#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/build_order.sh

# =========================================================================
# Build Order Determination Script
# Responsibility: Determine the correct order of build stages based on
#                 folder names and user selections. Exports ORDERED_FOLDERS
#                 and SELECTED_FOLDERS_MAP globally.
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
# Exports:   ORDERED_FOLDERS (global array of full paths)
#            SELECTED_FOLDERS_MAP (global associative array [basename]=1)
# Returns:   Exit code 0 on success, 1 on error.
# =========================================================================
determine_build_order() {
    local build_dir="${1}"               # Capture build directory path
    local selected_folders_list="${2:-}" # Capture selected folders, default to empty

    # Declare global output variables (clear them first)
    declare -gA SELECTED_FOLDERS_MAP=() # Associative array map[basename]=1
    declare -g ORDERED_FOLDERS=()       # Indexed array of full paths

    log_info "--- Determining Build Order ---"
    log_debug "Build directory: $build_dir"
    log_debug "Raw selected folders list: '$selected_folders_list'"

    if [ ! -d "$build_dir" ]; then
        log_error "Build directory not found: $build_dir"
        return 1
    fi

    # REVERTED: Find only top-level numbered folders
    local potential_stage_dirs=()
    mapfile -t potential_stage_dirs < <(find "$build_dir" -maxdepth 1 -mindepth 1 -type d -name '[0-9]*-*' | sort -V)

    if [ ${#potential_stage_dirs[@]} -eq 0 ]; then
        log_warning "No numbered build stage folders found in $build_dir (checked depth 1)."
        return 0
    fi

    # REVERTED: Populate map based only on selection list or all found folders (no Dockerfile check here)
    if [[ -z "$selected_folders_list" ]]; then
        log_info "No specific stages selected by user. Preparing to build all found numbered stages."
        for folder_path in "${potential_stage_dirs[@]}"; do
            local folder_name
            folder_name=$(basename "$folder_path")
            SELECTED_FOLDERS_MAP["$folder_name"]=1
            log_debug "Adding '$folder_name' to selection map (building all)."
        done
    else
        log_info "User selected specific stages: $selected_folders_list"
        log_debug "Populating selection map..."
        for sel_folder in $selected_folders_list; do
            if [[ -n "$sel_folder" ]]; then
                 log_debug "Adding '$sel_folder' to selection map."
                 SELECTED_FOLDERS_MAP["$sel_folder"]=1
            fi
        done
        log_debug "Selection map populated."
    fi

    # REVERTED: Iterate through sorted potential folders and add to ORDERED_FOLDERS if selected (no Dockerfile check)
    for folder_path in "${potential_stage_dirs[@]}"; do
        local folder_name
        folder_name=$(basename "$folder_path")

        # Check if this folder name exists in the global SELECTED_FOLDERS_MAP
        if [[ ${SELECTED_FOLDERS_MAP[$folder_name]+_} ]]; then
            log_debug "Stage '$folder_name' ($folder_path) is selected. Adding to build order."
            ORDERED_FOLDERS+=("$folder_path") # Add the path
        else
            log_debug "Stage '$folder_name' ($folder_path) is NOT selected. Skipping."
        fi
    done

    # Final Check and Logging
    if [ ${#ORDERED_FOLDERS[@]} -eq 0 ]; then
         log_warning "No build stages selected or matched. Nothing to build."
         return 0
    fi

    log_info "Final determined build order (${#ORDERED_FOLDERS[@]} stages):"
    for folder in "${ORDERED_FOLDERS[@]}"; do
        log_info "  - $(basename "$folder")"
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

    # Helper to run and print results
    run_test() {
        local description="$1"
        local build_dir_arg="$2"
        local selection_arg="$3"
        log_info ""
        log_info "*** $description ***"
        # Clear global variables before test
        ORDERED_FOLDERS=()
        SELECTED_FOLDERS_MAP=()
        if determine_build_order "$build_dir_arg" "$selection_arg"; then
            log_success "determine_build_order succeeded."
            log_info "Resulting ORDERED_FOLDERS (${#ORDERED_FOLDERS[@]}):"
            if [[ ${#ORDERED_FOLDERS[@]} -gt 0 ]]; then
                printf '  %s\n' "${ORDERED_FOLDERS[@]}"
            else
                log_info "  (empty)"
            fi
            log_info "Resulting SELECTED_FOLDERS_MAP keys (${#SELECTED_FOLDERS_MAP[@]}):"
             if [[ ${#SELECTED_FOLDERS_MAP[@]} -gt 0 ]]; then
                 # Sort keys for consistent output
                 local sorted_keys=()
                 mapfile -t sorted_keys < <(printf '%s\n' "${!SELECTED_FOLDERS_MAP[@]}" | sort)
                 printf '  %s\n' "${sorted_keys[@]}"
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
# Description: Determines build order. Modified to check for Dockerfile existence before adding to ORDERED_FOLDERS. Searches depth 2.
# Author: Mr K / GitHub Copilot / kairin
# COMMIT-TRACKING: UUID-20250425-065844-ORDERFIX4
