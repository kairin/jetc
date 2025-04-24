#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/build_stages.sh

# =========================================================================
# Build Stages Execution Script
# Responsibility: Iterate through the determined build order and execute
#                 the build for each stage using docker_helpers.
# =========================================================================

# Set strict mode
set -euo pipefail

# --- Dependencies ---
SCRIPT_DIR_STAGES="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# Source required scripts (use fallbacks if sourcing fails)
# env_setup provides logging and global vars like PLATFORM
if [ -f "$SCRIPT_DIR_STAGES/env_setup.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_STAGES/env_setup.sh"
else
    echo "CRITICAL ERROR: env_setup.sh not found. Cannot proceed." >&2
    exit 1
fi
# docker_helpers provides build_folder_image
if [ -f "$SCRIPT_DIR_STAGES/docker_helpers.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_STAGES/docker_helpers.sh"
else
    log_error "docker_helpers.sh not found. Build stage execution will fail."
    exit 1
fi
# env_update provides update_available_images_in_env
if [ -f "$SCRIPT_DIR_STAGES/env_update.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_STAGES/env_update.sh"
else
    log_error "env_update.sh not found. .env updates will fail."
    # Allow to continue but warn, maybe updates aren't critical
    update_available_images_in_env() { log_warning "update_available_images_in_env: env_update.sh not loaded"; return 0; }
fi


# --- Global Variables ---
# ORDERED_FOLDERS, SELECTED_FOLDERS_MAP, DOCKER_USERNAME, DOCKER_REPO_PREFIX,
# DOCKER_REGISTRY, SELECTED_BASE_IMAGE, use_cache, use_squash,
# skip_intermediate_push_pull, use_builder, PLATFORM

# Declare global map for skipping specific apps within stages (initialize as empty)
declare -gA skip_apps_map=()

# --- Functions ---

# =========================================================================
# Function: Execute the build process for selected stages
# =========================================================================
build_selected_stages() {
    log_info "=================================================="
    log_info "Starting Build Stages..."
    log_info "=================================================="

    # Ensure required global variables are available
    if ! declare -p ORDERED_FOLDERS &>/dev/null || [[ ${#ORDERED_FOLDERS[@]} -eq 0 ]]; then
        log_warning "ORDERED_FOLDERS array is empty or not set. No stages to build."
        export LAST_SUCCESSFUL_TAG="${SELECTED_BASE_IMAGE}"
        return 0
    fi
     if [[ ! $(declare -p SELECTED_FOLDERS_MAP 2>/dev/null) =~ "declare -A" ]]; then
        log_error "SELECTED_FOLDERS_MAP associative array is not declared globally. Check build_order.sh."
        return 1
     fi
     if [[ ${#SELECTED_FOLDERS_MAP[@]} -eq 0 && -n "${SELECTED_FOLDERS_LIST:-}" ]]; then
         log_warning "SELECTED_FOLDERS_MAP is empty, but SELECTED_FOLDERS_LIST was not. Check build_order.sh."
     fi


    local current_base_image="${SELECTED_BASE_IMAGE}"
    local stage_build_failed=0
    export LAST_SUCCESSFUL_TAG=""

    log_info "Initial base image for build stages: $current_base_image"

    # Use process substitution for safer loop iteration
    while IFS= read -r build_folder_path; do
        [[ -z "$build_folder_path" ]] && continue

        local build_folder_basename
        build_folder_basename=$(basename "$build_folder_path")

        # <<< --- ADDED DEBUGGING: Check globals INSIDE loop --- >>>
        log_debug "LOOP START for '$build_folder_basename': Checking global vars..."
        log_debug "  -> use_cache='${use_cache:-<unset>}'"
        log_debug "  -> DOCKER_USERNAME='${DOCKER_USERNAME:-<unset>}'"
        log_debug "  -> use_squash='${use_squash:-<unset>}'"
        log_debug "  -> skip_intermediate_push_pull='${skip_intermediate_push_pull:-<unset>}'"
        log_debug "  -> current_base_image='${current_base_image:-<unset>}'"
        log_debug "  -> DOCKER_REPO_PREFIX='${DOCKER_REPO_PREFIX:-<unset>}'"
        log_debug "  -> DOCKER_REGISTRY='${DOCKER_REGISTRY:-<unset>}'"
        log_debug "  -> use_builder='${use_builder:-<unset>}'"
        log_debug "  -> PLATFORM='${PLATFORM:-<unset>}'"
        # <<< --- END DEBUGGING --- >>>


        # Check if this folder should be built using the map
        if [[ ${SELECTED_FOLDERS_MAP[$build_folder_basename]+_} ]]; then
             log_info "--- Processing Stage: $build_folder_basename ---" # This log appears
             # Try a simple echo right after the log_info that works
             echo "DEBUG ECHO: Processing $build_folder_basename" >&2

             # Assign arguments to local variables BEFORE logging them
             local arg1="$build_folder_path"
             local arg2="${use_cache:-n}"
             local arg3="${DOCKER_USERNAME}"
             local arg4="${use_squash:-n}"
             local arg5="${skip_intermediate_push_pull:-y}"
             local arg6="$current_base_image"
             local arg7="${DOCKER_REPO_PREFIX}"
             local arg8="${DOCKER_REGISTRY:-}"
             local arg9="${use_builder:-y}"

             # Log the arguments *from the local variables*
             log_debug "Arguments prepared (from local vars) for build_folder_image:"
             log_debug "  \$1 (folder_path):        '$arg1'"
             log_debug "  \$2 (use_cache):          '$arg2'"
             log_debug "  \$3 (docker_username):    '$arg3'"
             log_debug "  \$4 (use_squash):         '$arg4'"
             log_debug "  \$5 (skip_intermediate):  '$arg5'"
             log_debug "  \$6 (base_image_tag):     '$arg6'"
             log_debug "  \$7 (docker_repo_prefix): '$arg7'"
             log_debug "  \$8 (docker_registry):    '$arg8'"
             log_debug "  \$9 (use_builder):        '$arg9'"

             # Call the build function using the local variables
             log_debug ">>> Calling build_folder_image NOW..."
             build_folder_image "$arg1" "$arg2" "$arg3" "$arg4" "$arg5" "$arg6" "$arg7" "$arg8" "$arg9"
             local build_status=$?
             log_debug "<<< build_folder_image returned status: $build_status"


            # shellcheck disable=SC2154 # fixed_tag is exported by build_folder_image
            local current_fixed_tag="${fixed_tag:-}"

            if [[ $build_status -eq 0 && -n "$current_fixed_tag" ]]; then
                log_success "Stage '$build_folder_basename' completed successfully."
                log_info "  Output Image: $current_fixed_tag"
                current_base_image="$current_fixed_tag"
                export LAST_SUCCESSFUL_TAG="$current_fixed_tag"
                update_available_images_in_env "$current_fixed_tag"
            else
                log_error "Stage '$build_folder_basename' failed with exit code $build_status."
                log_debug "  Failed Tag (if generated): ${current_fixed_tag:-<none>}"
                stage_build_failed=1
                log_error "Aborting remaining build stages due to failure in '$build_folder_basename'."
                break
            fi
             log_info "--- Stage Complete: $build_folder_basename ---"
        else
            log_warning "Skipping folder '$build_folder_basename' as it wasn't found in SELECTED_FOLDERS_MAP (this might indicate an issue)."
        fi
    done < <(printf '%s\n' "${ORDERED_FOLDERS[@]}")

    log_info "=================================================="
    if [[ $stage_build_failed -eq 0 ]]; then
        log_success "All selected build stages completed."
        if [[ -z "${LAST_SUCCESSFUL_TAG:-}" ]]; then
             export LAST_SUCCESSFUL_TAG="${SELECTED_BASE_IMAGE}"
             log_debug "No stages built, setting LAST_SUCCESSFUL_TAG to initial base: $LAST_SUCCESSFUL_TAG"
        fi
        return 0
    else
        log_error "One or more build stages failed."
        if [[ -z "${LAST_SUCCESSFUL_TAG:-}" ]]; then
             log_warning "No stages completed successfully."
        fi
        return 1
    fi
}


# --- Main Execution (for testing) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Minimal setup for testing if run directly
    export SCRIPT_DIR_STAGES
     if ! command -v build_folder_image &> /dev/null; then
        echo "Warning: Mocking build_folder_image for testing." >&2
        build_folder_image() {
            local folder="$1" username="$3" repo_prefix="$7"
            local base_name
            base_name=$(basename "$folder")
            echo "INFO: Mock build_folder_image called for: $base_name"
            echo "DEBUG: Mock Args: $@"
            if [[ "$base_name" == 01-* ]]; then
                export fixed_tag="${username}/${repo_prefix}:${base_name}-success"
                echo "SUCCESS: -> Mock Success: $fixed_tag"
                return 0
            elif [[ "$base_name" == 02-* ]]; then
                 export fixed_tag="${username}/${repo_prefix}:${base_name}-fail"
                 echo "ERROR: -> Mock Failure" >&2
                 return 1
            else
                 export fixed_tag="${username}/${repo_prefix}:${base_name}-success"
                 echo "SUCCESS: -> Mock Success (default): $fixed_tag"
                 return 0
            fi
        }
    fi
     if ! command -v update_available_images_in_env &> /dev/null; then
        echo "Warning: Mocking update_available_images_in_env for testing." >&2
        update_available_images_in_env() { echo "INFO: Mock update_available_images_in_env called with: $1"; return 0; }
    fi
     if ! command -v log_info &> /dev/null; then
        log_info() { echo "INFO: $1"; }
        log_warning() { echo "WARNING: $1" >&2; }
        log_error() { echo "ERROR: $1" >&2; }
        log_success() { echo "SUCCESS: $1"; }
        log_debug() { echo "[DEBUG] build_stages_test: $1" >&2; } # Make debug visible in test
     fi

    # Set mock global variables
    ORDERED_FOLDERS=( "/tmp/build/01-first" "/tmp/build/02-second-fails" "/tmp/build/03-third" )
    declare -gA SELECTED_FOLDERS_MAP=( ["01-first"]=1 ["02-second-fails"]=1 ["03-third"]=1 )
    SELECTED_BASE_IMAGE="mock/repo:initial-base"
    DOCKER_USERNAME="mockuser"
    DOCKER_REPO_PREFIX="mockrepo"
    DOCKER_REGISTRY=""
    use_cache="n"
    use_squash="n"
    skip_intermediate_push_pull="y"
    use_builder="y"
    PLATFORM="linux/arm64"
    SELECTED_FOLDERS_LIST="01-first 02-second-fails 03-third"

    # --- Test Cases --- #
    log_info ""
    log_info "*** Test 1: Build sequence with one failure ***"
    if build_selected_stages; then
         log_success "Test 1 Result: build_selected_stages reported SUCCESS (unexpected)."
    else
         log_error "Test 1 Result: build_selected_stages reported FAILURE (expected)."
    fi
    log_info "Test 1 LAST_SUCCESSFUL_TAG: ${LAST_SUCCESSFUL_TAG:-<unset>}"
    echo "--------------------"

    # ... (rest of tests omitted for brevity) ...

    # --- Cleanup --- #
    log_info ""
    log_info "Build stages script test finished."
    exit 0
fi


# File location diagram: ... (omitted)
# Description: Iterates through build stages. Added extensive debugging around the build_folder_image call.
# Author: Mr K / GitHub Copilot / kairin
# COMMIT-TRACKING: UUID-20250424-221500-STAGESDEBUG2
