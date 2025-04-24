#!/bin/bash
# Main build script for Jetson Container project

# Strict mode
set -euo pipefail

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR # Export for use in sourced scripts

# --- Source Core Dependencies (Order Matters!) ---

# 1. Logging (Must be first)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/logging.sh" || { echo "Error: logging.sh not found."; exit 1; }
init_logging # Initialize logging AFTER sourcing

# 2. Environment Setup (Loads .env, sets basic ARCH, PLATFORM, AVAILABLE_IMAGES etc.)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/env_setup.sh" || { echo "Error: env_setup.sh not found."; exit 1; }

# 3. Utilities (General helpers, needed by many others)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }

# 4. .env Update Functions (Needed by user_interaction)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/env_update.sh" || { echo "Error: env_update.sh not found."; exit 1; }

# 5. Dialog UI Functions (Needed by user_interaction, post_build_menu)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/dialog_ui.sh" || { echo "Error: dialog_ui.sh not found."; exit 1; }

# 6. Docker Helpers (Needed by build_stages, verification, tagging)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/docker_helpers.sh" || { echo "Error: docker_helpers.sh not found."; exit 1; }

# 7. Verification Functions (Host launchers needed by post_build_menu)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/verification.sh" || { echo "Error: verification.sh not found."; exit 1; }

# 8. System Checks (Needed early for dependency checks)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/system_checks.sh" || { echo "Error: system_checks.sh not found."; exit 1; }

# 9. Buildx Setup (Needed before build stages)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/buildx_setup.sh" || { echo "Error: buildx_setup.sh not found."; exit 1; }

# 10. User Interaction (Needs dialog_ui, env_update, env_setup)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/user_interaction.sh" || { echo "Error: user_interaction.sh not found."; exit 1; }

# 11. Build Order Logic (Needs user_interaction results implicitly)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/build_order.sh" || { echo "Error: build_order.sh not found."; exit 1; }

# 12. Build Stages Execution (Needs docker_helpers, build_order vars)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/build_stages.sh" || { echo "Error: build_stages.sh not found."; exit 1; }

# 13. Tagging Functions (Needs docker_helpers, env_setup)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/tagging.sh" || { echo "Error: tagging.sh not found."; exit 1; }

# 14. Post-Build Menu (Needs dialog_ui, verification, docker_helpers)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/post_build_menu.sh" || { echo "Error: post_build_menu.sh not found."; exit 1; }


# --- Configuration ---\
export BUILD_DIR="$SCRIPT_DIR/build"
# LOG_DIR, MAIN_LOG, ERROR_LOG are set by logging.sh/init_logging
# JETC_DEBUG is loaded/defaulted by env_setup.sh

# --- Initialization ---\
log_start # Log script start

# Check essential dependencies (uses function from system_checks.sh)
# Run this *after* all sourcing is done
check_dependencies "docker" "dialog"

# --- Main Build Process ---\
main() {
    log_info "Starting Jetson Container Build Process..."
    log_debug "JETC_DEBUG is set to: ${JETC_DEBUG}"

    # Track overall build status
    BUILD_FAILED=0

    # 1. Handle User Interaction (Gets prefs, updates .env, exports vars for this run)
    log_debug "Step 1: Handling user interaction..."
    # Needs: user_interaction.sh, dialog_ui.sh, env_update.sh
    if ! handle_user_interaction; then
        log_error "Build cancelled by user or error during interaction."
        BUILD_FAILED=1
    fi

    # 2. Setup Buildx Builder (Only if Step 1 succeeded)
    if [[ $BUILD_FAILED -eq 0 ]]; then
        log_debug "Step 2: Setting up Docker buildx builder..."
        # Needs: buildx_setup.sh
        if ! setup_buildx; then
            log_error "Failed to setup Docker buildx builder. Cannot proceed."
            BUILD_FAILED=1
        else
            log_success "Docker buildx builder setup complete."
        fi
    fi

    # 3. Determine Build Order (Only if previous steps succeeded)
    if [[ $BUILD_FAILED -eq 0 ]]; then
        log_debug "Step 3: Determining build order..."
        # Needs: build_order.sh, vars from user_interaction
        if ! determine_build_order "$BUILD_DIR" "${SELECTED_FOLDERS_LIST:-}"; then
            log_error "Failed to determine build order."
            BUILD_FAILED=1
        else
            log_success "Build order determined."
        fi
    fi

    # 4. Execute Build Stages (Only if previous steps succeeded)
    if [[ $BUILD_FAILED -eq 0 ]]; then
        log_debug "Step 4: Executing build stages..."
        # Needs: build_stages.sh, docker_helpers.sh, build_order vars
        if ! build_selected_stages; then
            log_error "Build process completed with errors during stages."
            BUILD_FAILED=1
            # Continue to post-build even on failure to allow cleanup/info
        else
            log_success "All selected build stages completed successfully."
        fi
        log_debug "LAST_SUCCESSFUL_TAG after build stages: ${LAST_SUCCESSFUL_TAG:-<unset>}"
    fi

    # --- Post-Build Actions (Run even if build failed, but skip tagging/verification) ---

    local final_image_tag="${LAST_SUCCESSFUL_TAG:-}" # Use last successful tag if any
    local final_timestamp_tag=""

    # 5. Pre-Tagging Verification, Tagging, Verification (Only if build SUCCEEDED)
    if [[ $BUILD_FAILED -eq 0 && -n "$final_image_tag" ]]; then
        log_debug "Step 5: Performing pre-tagging verification..."
        # Needs: tagging.sh (perform_pre_tagging_pull), docker_helpers.sh (pull_image, verify_image_exists)
        if ! perform_pre_tagging_pull "$final_image_tag" "${skip_intermediate_push_pull:-y}"; then
            log_warning "Pre-tagging verification failed for ${final_image_tag}. Final tag may not be accessible."
        else
            log_success "Pre-tagging verification passed for ${final_image_tag}."
        fi

        log_debug "Step 6: Creating final timestamp tag..."
        # Needs: tagging.sh (create_final_timestamp_tag), docker_helpers.sh (generate_timestamped_tag)
        local created_tag
        if ! created_tag=$(create_final_timestamp_tag "$final_image_tag" "$DOCKER_USERNAME" "$DOCKER_REPO_PREFIX" "${skip_intermediate_push_pull:-y}" "${DOCKER_REGISTRY:-}"); then
            log_warning "Failed to create or push timestamp tag for ${final_image_tag}."
        else
            final_timestamp_tag="$created_tag" # Assign only on success
            log_success "Created timestamp tag: $final_timestamp_tag"
            # Needs: env_update.sh (update_env_var)
            log_debug "Updating DEFAULT_IMAGE_NAME in .env to $final_timestamp_tag"
            if ! update_env_var "DEFAULT_IMAGE_NAME" "$final_timestamp_tag"; then
                log_warning "Failed to update DEFAULT_IMAGE_NAME in .env file."
            fi
        fi

        log_debug "Step 7: Verifying all built images exist locally..."
        # Needs: tagging.sh (verify_all_images_exist_locally), docker_helpers.sh (verify_image_exists)
        local all_tags=("$final_image_tag")
        [[ -n "$final_timestamp_tag" ]] && all_tags+=("$final_timestamp_tag")
        if ! verify_all_images_exist_locally "${all_tags[@]}"; then
            log_warning "Final local verification failed."
        else
            log_success "All built images verified locally: ${all_tags[*]}"
        fi
    fi

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

    # Run the post-build menu only if at least one image was built
    if [[ -n "$final_image_tag" ]]; then
        log_debug "Running post-build menu..."
        # Needs: post_build_menu.sh, dialog_ui.sh, verification.sh, docker_helpers.sh
        run_post_build_menu "$final_image_tag" "$final_timestamp_tag"
    else
        log_warning "Skipping post-build menu as no image was successfully built."
    fi

    log_end # Log script end
    return $BUILD_FAILED # Return overall status
}


# --- Script Execution ---\
# Ensure cleanup runs on exit (cleanup function is in system_checks.sh)
trap cleanup EXIT INT TERM

# Run the main function and exit with its status code
main
exit $?

# --- Footer ---
# File location diagram: ... (omitted)
# Description: Main build script orchestrator. Corrected sourcing order for dependencies.
# Author: kairin / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-205555-LOGGINGREFACTOR
