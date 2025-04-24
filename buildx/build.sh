#!/bin/bash
# Main build script for Jetson Container project

# Strict mode
set -euo pipefail # Re-enable -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export SCRIPT_DIR

# --- Source Core Dependencies (Order Matters!) ---
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/logging.sh" || { echo "Error: logging.sh not found."; exit 1; }
init_logging
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/env_setup.sh" || { echo "Error: env_setup.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/env_update.sh" || { echo "Error: env_update.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/dialog_ui.sh" || { echo "Error: dialog_ui.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/docker_helpers.sh" || { echo "Error: docker_helpers.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/verification.sh" || { echo "Error: verification.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/system_checks.sh" || { echo "Error: system_checks.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/buildx_setup.sh" || { echo "Error: buildx_setup.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/user_interaction.sh" || { echo "Error: user_interaction.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/build_order.sh" || { echo "Error: build_order.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/build_stages.sh" || { echo "Error: build_stages.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/tagging.sh" || { echo "Error: tagging.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/post_build_menu.sh" || { echo "Error: post_build_menu.sh not found."; exit 1; }


# --- Configuration ---\
export BUILD_DIR="$SCRIPT_DIR/build"

# --- Initialization ---\
log_start
check_dependencies "docker" "dialog" # This call should be fine now

# --- Main Build Process ---
# Carefully check the structure here
main() { # Line ~65
    log_info "Starting Jetson Container Build Process..."
    log_debug "JETC_DEBUG is set to: ${JETC_DEBUG}"
    BUILD_FAILED=0

    # 1. Handle User Interaction
    log_debug "Step 1: Handling user interaction..."
    # Rely on set -e: if handle_user_interaction fails (returns non-zero), script will exit
    if handle_user_interaction; then
        log_debug "handle_user_interaction seemed successful."
    else
        # This else block might not be reached if set -e exits first,
        # but handle_user_interaction should log its own errors/cancellation.
        log_error "Build cancelled or failed during user interaction (check previous logs)."
        BUILD_FAILED=1 # Set flag just in case set -e was bypassed somehow
    fi
    # If script proceeds, interaction was successful or set -e didn't trigger

    # 2. Setup Buildx Builder
    # No need for explicit BUILD_FAILED check if relying on set -e for previous steps
    log_debug "Step 2: Setting up Docker buildx builder..."
    if setup_buildx; then
        log_success "Docker buildx builder setup complete."
    else
        log_error "Failed to setup Docker buildx builder. Cannot proceed."
        BUILD_FAILED=1 # Explicitly set failure
        # Consider exiting here if buildx is absolutely required: exit 1
    fi


    # 3. Determine Build Order
    if [[ $BUILD_FAILED -eq 0 ]]; then # Check if previous steps failed explicitly
        log_debug "Step 3: Determining build order..."
        if determine_build_order "$BUILD_DIR" "${SELECTED_FOLDERS_LIST:-}"; then
            log_success "Build order determined."
        else
            log_error "Failed to determine build order."
            BUILD_FAILED=1
        fi
    else
         log_warning "Skipping Step 3 (Build Order) due to previous failure."
    fi

    # 4. Execute Build Stages
    if [[ $BUILD_FAILED -eq 0 ]]; then
        log_debug "Step 4: Executing build stages..."
        if build_selected_stages; then
            log_success "All selected build stages completed successfully."
        else
            log_error "Build process completed with errors during stages."
            BUILD_FAILED=1
            # Continue to post-build even on failure
        fi
        log_debug "LAST_SUCCESSFUL_TAG after build stages: ${LAST_SUCCESSFUL_TAG:-<unset>}"
    else
        log_warning "Skipping Step 4 (Build Stages) due to previous failure."
    fi

    # --- Post-Build Actions ---
    local final_image_tag="${LAST_SUCCESSFUL_TAG:-}"
    local final_timestamp_tag=""

    # 5. Pre-Tagging Verification, Tagging, Verification (Only if build SUCCEEDED)
    if [[ $BUILD_FAILED -eq 0 && -n "$final_image_tag" ]]; then
        log_debug "Step 5: Performing pre-tagging verification..."
        # Allow this to fail without stopping everything, just log warning
        if ! perform_pre_tagging_pull "$final_image_tag" "${skip_intermediate_push_pull:-y}"; then
             log_warning "Pre-tagging verification failed for ${final_image_tag}. Final tag may not be accessible."
        else
             log_success "Pre-tagging verification passed for ${final_image_tag}."
        fi

        log_debug "Step 6: Creating final timestamp tag..."
        local created_tag
        # Use a subshell to capture output without triggering set -e on potential internal failures
        created_tag=$(create_final_timestamp_tag "$final_image_tag" "$DOCKER_USERNAME" "$DOCKER_REPO_PREFIX" "${skip_intermediate_push_pull:-y}" "${DOCKER_REGISTRY:-}" || echo "")
        if [[ -z "$created_tag" ]]; then
            log_warning "Failed to create or push timestamp tag for ${final_image_tag} (function returned empty)."
        else
            final_timestamp_tag="$created_tag"
            log_success "Created timestamp tag: $final_timestamp_tag"
            log_debug "Updating DEFAULT_IMAGE_NAME in .env to $final_timestamp_tag"
            # Allow .env update to fail without stopping script
            if ! update_env_var "DEFAULT_IMAGE_NAME" "$final_timestamp_tag"; then
                 log_warning "Failed to update DEFAULT_IMAGE_NAME in .env file."
            fi
        fi

        log_debug "Step 7: Verifying all built images exist locally..."
        local all_tags=("$final_image_tag")
        [[ -n "$final_timestamp_tag" ]] && all_tags+=("$final_timestamp_tag")
        # Allow local verification to fail without stopping script
        if ! verify_all_images_exist_locally "${all_tags[@]}"; then
             log_warning "Final local verification failed."
        else
             log_success "All built images verified locally: ${all_tags[*]}"
        fi
    fi # End post-build tagging/verification block

    # 8. Post-Build Summary & Menu
    log_debug "Step 8: Post-Build Summary & Menu..."
    log_info "Build process completed."
    if [[ $BUILD_FAILED -eq 0 ]]; then
        log_success "Build SUCCEEDED."
        log_success "Final Image Tag: ${final_image_tag}"
        [[ -n "$final_timestamp_tag" ]] && log_success "Timestamp Tag:   ${final_timestamp_tag}"
    else
        log_error "Build process finished with ERRORS."
        if [[ -n "$final_image_tag" ]]; then
             log_warning "Last Successful Image Tag: ${final_image_tag}"
        else
             log_error "No successful image was built."
        fi
    fi

    # Run post-build menu regardless of build success if an image exists
    if [[ -n "$final_image_tag" ]]; then
        log_debug "Running post-build menu..."
        # Use || true to prevent post-build menu failure from stopping the script due to set -e
        run_post_build_menu "$final_image_tag" "$final_timestamp_tag" || true
        log_debug "run_post_build_menu finished."
    else
        log_warning "Skipping post-build menu as no image was successfully built."
    fi

    log_end # Log script end
    log_info "Returning overall build status: $BUILD_FAILED"
    # Return the status based on whether build stages failed
    return $BUILD_FAILED
} # <<< Ensure this closing brace matches the opening one for main()

# --- Script Execution ---\
# Ensure cleanup is defined (should be in system_checks.sh)
if ! declare -f cleanup > /dev/null; then
    # Define a basic cleanup if not found, to prevent trap errors
    cleanup() { log_debug "Basic cleanup trap triggered."; }
    log_warning "cleanup function not found in sourced scripts, using basic trap."
fi
trap cleanup EXIT INT TERM
main # Call the main function
exit $? # Exit with the return code of main

# --- Footer ---
# File location diagram: ... (omitted)
# Description: Main build script orchestrator. Simplified error handling, restored set -euo pipefail.
# Author: kairin / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-214000-RESTORESET-E
