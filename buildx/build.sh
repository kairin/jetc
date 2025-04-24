#!/bin/bash
# Main build script for Jetson Container project

# Strict mode
set -euo pipefail

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR # Export for use in sourced scripts

# Source utility scripts
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# Source logging functions FIRST - This also initializes logging
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/env_setup.sh" || { echo "Error: env_setup.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/docker_helpers.sh" || { echo "Error: docker_helpers.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/verification.sh" || { echo "Error: verification.sh not found."; exit 1; }
# Source the NEW user interaction handler
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/user_interaction.sh" || { echo "Error: user_interaction.sh not found."; exit 1; }
# Source the NEW build order handler
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/build_order.sh" || { echo "Error: build_order.sh not found."; exit 1; }
# Source the build stages execution script
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/build_stages.sh" || { echo "Error: build_stages.sh not found."; exit 1; }
# Source buildx setup
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/buildx_setup.sh" || { echo "Error: buildx_setup.sh not found."; exit 1; }
# Source tagging helper
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/tagging.sh" || { echo "Error: tagging.sh not found."; exit 1; }
# Source the post-build menu
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/post_build_menu.sh" || { echo "Error: post_build_menu.sh not found."; exit 1; }
# Source system checks (NOW SOURCES env_setup.sh itself)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/system_checks.sh" || { echo "Error: system_checks.sh not found."; exit 1; }
# Source env update helpers (needed for update_env_var)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/env_update.sh" || { echo "Error: env_update.sh not found."; exit 1; }


# --- Configuration ---\
export BUILD_DIR="$SCRIPT_DIR/build"
# LOG_DIR, MAIN_LOG, ERROR_LOG are now set by env_setup.sh/init_logging
export JETC_DEBUG="${JETC_DEBUG:-false}" # Enable debug logging if JETC_DEBUG=true

# --- Initialization ---\
# Logging is already initialized by sourcing env_setup.sh
# REMOVED: init_logging "$LOG_DIR" "$MAIN_LOG" "$ERROR_LOG"
log_start # Log script start

# Check essential dependencies (uses function from system_checks.sh)
check_dependencies "docker" "dialog"

# --- Main Build Process ---\
main() {
    log_message "INFO" "Starting Jetson Container Build Process..." # Use log_message directly or log_info
    log_debug "JETC_DEBUG is set to: ${JETC_DEBUG}"

    # Track overall build status
    BUILD_FAILED=0

    # 1. Handle User Interaction (Gets prefs, updates .env, exports vars for this run)
    log_debug "Step 1: Handling user interaction..."
    if ! handle_user_interaction; then
        log_error "Build cancelled by user or error during interaction."
        BUILD_FAILED=1
        # No return here, allow cleanup and exit at the end
    fi

    # Proceed only if user interaction succeeded
    if [[ $BUILD_FAILED -eq 0 ]]; then
        log_debug "User interaction successful. Exported variables:"
        log_debug "  DOCKER_USERNAME=${DOCKER_USERNAME:-<unset>}"
        log_debug "  DOCKER_REPO_PREFIX=${DOCKER_REPO_PREFIX:-<unset>}"
        log_debug "  DOCKER_REGISTRY=${DOCKER_REGISTRY:-<unset>}"
        log_debug "  SELECTED_BASE_IMAGE=${SELECTED_BASE_IMAGE:-<unset>}"
        log_debug "  SELECTED_FOLDERS_LIST=${SELECTED_FOLDERS_LIST:-<unset>}"
        log_debug "  use_cache=${use_cache:-<unset>}"
        log_debug "  use_squash=${use_squash:-<unset>}"
        log_debug "  skip_intermediate_push_pull=${skip_intermediate_push_pull:-<unset>}"
        log_debug "  use_builder=${use_builder:-<unset>}"
        log_debug "  platform=${PLATFORM:-<unset>}" # Use uppercase PLATFORM from env

        # 2. Setup Buildx Builder
        log_debug "Step 2: Setting up Docker buildx builder..."
        # Use the corrected function name from buildx_setup.sh
        if ! setup_buildx; then
            log_error "Failed to setup Docker buildx builder. Cannot proceed."
            BUILD_FAILED=1
        else
            log_success "Docker buildx builder setup complete."
        fi
    fi

    # Proceed only if buildx setup succeeded
    if [[ $BUILD_FAILED -eq 0 ]]; then
        # 3. Determine Build Order (Based on SELECTED_FOLDERS_LIST from user interaction)
        log_debug "Step 3: Determining build order..."
        # This function exports ORDERED_FOLDERS and SELECTED_FOLDERS_MAP
        if ! determine_build_order "$BUILD_DIR" "${SELECTED_FOLDERS_LIST:-}"; then
            log_error "Failed to determine build order. Check build directory structure and selections."
            BUILD_FAILED=1
        else
            log_success "Build order determined."
            log_debug "ORDERED_FOLDERS: ${ORDERED_FOLDERS[*]}"
            # log_debug "SELECTED_FOLDERS_MAP keys: ${!SELECTED_FOLDERS_MAP[@]}" # Requires Bash 4+
        fi
    fi

    # Proceed only if build order determined
    if [[ $BUILD_FAILED -eq 0 ]]; then
        # 4. Execute Build Stages (Uses exported variables from steps 1 & 2)
        log_debug "Step 4: Executing build stages..."
        # build_selected_stages uses ORDERED_FOLDERS, SELECTED_FOLDERS_MAP, and other prefs
        # It exports LAST_SUCCESSFUL_TAG
        if ! build_selected_stages; then
            log_error "Build process completed with errors during stages. Check logs in $LOG_DIR."
            BUILD_FAILED=1
            # Continue to post-build menu even on failure
        else
            log_success "All selected build stages completed successfully."
        fi
        log_debug "LAST_SUCCESSFUL_TAG after build stages: ${LAST_SUCCESSFUL_TAG:-<unset>}"
    fi

    # Skip verification and tagging if build failed during stages
    if [[ $BUILD_FAILED -eq 0 ]]; then
        # 5. Pre-Tagging Verification - Check the built image can be pulled
        log_debug "Step 5: Performing pre-tagging verification..."
        if [[ -z "${LAST_SUCCESSFUL_TAG:-}" ]]; then
             log_error "Cannot perform pre-tagging verification: LAST_SUCCESSFUL_TAG is not set."
             BUILD_FAILED=1
        elif ! perform_pre_tagging_pull "${LAST_SUCCESSFUL_TAG}"; then
            log_warning "Pre-tagging verification failed for ${LAST_SUCCESSFUL_TAG}. Final tag may not be accessible."
            # Continue despite warnings - this is just a verification step
        else
            log_success "Pre-tagging verification passed for ${LAST_SUCCESSFUL_TAG}."
        fi
    fi

    # Proceed only if build stages succeeded (pre-tagging warning is ok)
    if [[ $BUILD_FAILED -eq 0 ]]; then
         # 6. Final Tagging - Generate timestamp tag
        log_debug "Step 6: Creating final timestamp tag..."
        local timestamp_tag
        # Capture stdout from create_final_timestamp_tag
        if ! timestamp_tag=$(create_final_timestamp_tag "${LAST_SUCCESSFUL_TAG}" "${DOCKER_USERNAME}" "${DOCKER_REPO_PREFIX}" "${DOCKER_REGISTRY:-}"); then
            log_warning "Failed to create timestamp tag for ${LAST_SUCCESSFUL_TAG}. Continuing without timestamp tag."
            # Ensure FINAL_TIMESTAMP_TAG is unset or empty
            export FINAL_TIMESTAMP_TAG=""
        else
            log_success "Created timestamp tag: $timestamp_tag"
            export FINAL_TIMESTAMP_TAG="$timestamp_tag"

            # Update environment variables with the new tag
            log_debug "Updating DEFAULT_IMAGE_NAME in .env to $timestamp_tag"
            if ! update_env_var "DEFAULT_IMAGE_NAME" "$timestamp_tag"; then
                log_warning "Failed to update DEFAULT_IMAGE_NAME in .env file."
            fi
        fi
    fi

    # Proceed only if build stages succeeded (tagging warning is ok)
    if [[ $BUILD_FAILED -eq 0 ]]; then
        # 7. Verify all images exist locally
        log_debug "Step 7: Verifying all built images exist locally..."
        local all_tags=()
        [[ -n "${LAST_SUCCESSFUL_TAG:-}" ]] && all_tags+=("$LAST_SUCCESSFUL_TAG")
        [[ -n "${FINAL_TIMESTAMP_TAG:-}" ]] && all_tags+=("$FINAL_TIMESTAMP_TAG")

        if [[ ${#all_tags[@]} -eq 0 ]]; then
             log_warning "No tags found to verify locally."
        elif ! verify_all_images_exist_locally "${all_tags[@]}"; then
            log_warning "Final local verification failed. Some expected images might be missing locally."
            # Should this set BUILD_FAILED=1? Maybe not, as push might have succeeded. Keep as warning.
        else
            log_success "All built images verified locally: ${all_tags[*]}"
        fi
    fi

    # 8. Post-Build Actions (Menu)
    log_debug "Step 8: Post-Build Actions..."
    log_message "INFO" "Build process completed." # Use log_message directly or log_info
    if [[ $BUILD_FAILED -eq 0 ]]; then
        log_success "Final Image Tag: ${LAST_SUCCESSFUL_TAG}"
        [[ -n "${FINAL_TIMESTAMP_TAG:-}" ]] && log_success "Timestamp Tag: ${FINAL_TIMESTAMP_TAG}"
    else
        log_error "Build process finished with errors."
        if [[ -n "${LAST_SUCCESSFUL_TAG:-}" ]]; then
            log_warning "Last Successful Image Tag: ${LAST_SUCCESSFUL_TAG}"
        else
            log_error "No successful image was built."
            # Allow post-build menu? Maybe not useful if nothing built. Exit early?
            # For now, continue to menu if requested, but return failure code later.
        fi
    fi

    # Run the post-build menu regardless of BUILD_FAILED status?
    # Only run if at least one image was successfully built.
    if [[ -n "${LAST_SUCCESSFUL_TAG:-}" ]]; then
        log_debug "Running post-build menu..."
        run_post_build_menu "${LAST_SUCCESSFUL_TAG}" "${FINAL_TIMESTAMP_TAG:-}"
    else
        log_warning "Skipping post-build menu as no image was successfully built."
    fi

    log_end # Log script end
    # Return the overall build status
    log_debug "Main function finished. Returning status: $BUILD_FAILED"
    return $BUILD_FAILED
}


# --- Script Execution ---\
# Ensure cleanup runs on exit (cleanup function is in system_checks.sh)
trap cleanup EXIT INT TERM

# Run the main function and exit with its status code
main
exit $?

# --- Footer ---
# File location diagram: ... (omitted for brevity)
# Description: Main build script orchestrator. Fixed logging initialization and calls.
# Author: Mr K / GitHub Copilot / kairin
# COMMIT-TRACKING: UUID-20250424-202828-MAINFIX
