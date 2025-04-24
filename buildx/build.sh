#!/bin/bash
# Main build script for Jetson Container project

# Strict mode - Keep pipefail, temporarily manage errexit (-e)
set -uo pipefail # REMOVED -e temporarily

# Get the directory where the script is located
# Use fallback for BASH_SOURCE[0] to be robust with set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)" # <<< MODIFIED LINE
export SCRIPT_DIR # Export for use in sourced scripts

# --- Source Core Dependencies (Order Matters!) ---
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/logging.sh" || { echo "Error: logging.sh not found."; exit 1; }
init_logging
# ... (rest of sourcing) ...
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/build_order.sh" || { echo "Error: build_order.sh not found."; exit 1; }
# ... (rest of sourcing) ...

# --- Configuration ---\
export BUILD_DIR="$SCRIPT_DIR/build"

# --- Initialization ---\
log_start
# Enable errexit after sourcing and basic setup
set -e
check_dependencies "docker" "dialog"

# --- Main Build Process ---
main() {
    # ... (main function remains the same as the previous version with set +e / set -e wrappers) ...
    log_info "Starting Jetson Container Build Process..."
    log_debug "JETC_DEBUG is set to: ${JETC_DEBUG}"
    BUILD_FAILED=0

    # 1. Handle User Interaction
    log_debug "Step 1: Handling user interaction..."
    local interaction_status=0
    set +e
    handle_user_interaction
    interaction_status=$?
    set -e
    if [[ $interaction_status -ne 0 ]]; then
        log_error "Build cancelled by user or error during interaction (Exit Code: $interaction_status)."
        BUILD_FAILED=1
    else
        log_debug "handle_user_interaction finished successfully (Exit Code: $interaction_status)."
    fi
    log_debug "After Step 1: BUILD_FAILED=$BUILD_FAILED"

    # 2. Setup Buildx Builder
    if [[ $BUILD_FAILED -eq 0 ]]; then
        log_debug "Step 2: Setting up Docker buildx builder..."
        local buildx_status=0
        set +e
        setup_buildx
        buildx_status=$?
        set -e
        if [[ $buildx_status -ne 0 ]]; then
            log_error "Failed to setup Docker buildx builder (Exit Code: $buildx_status). Cannot proceed."
            BUILD_FAILED=1
        else
            log_success "Docker buildx builder setup complete."
        fi
    else
        log_warning "Skipping Step 2 (Buildx Setup) because BUILD_FAILED is $BUILD_FAILED."
    fi
    log_debug "After Step 2: BUILD_FAILED=$BUILD_FAILED"

    # 3. Determine Build Order
    if [[ $BUILD_FAILED -eq 0 ]]; then
        log_debug "Step 3: Determining build order..."
        local build_order_status=0
        set +e
        determine_build_order "$BUILD_DIR" "${SELECTED_FOLDERS_LIST:-}"
        build_order_status=$?
        set -e
        log_debug "determine_build_order finished with exit code: $build_order_status"
        if [[ $build_order_status -ne 0 ]]; then
            log_error "Failed to determine build order (Exit Code: $build_order_status)."
            BUILD_FAILED=1
        else
            log_success "Build order determined."
        fi
    else
        log_warning "Skipping Step 3 (Build Order) because BUILD_FAILED is $BUILD_FAILED."
    fi
    log_debug "After Step 3: BUILD_FAILED=$BUILD_FAILED"

    # 4. Execute Build Stages
    if [[ $BUILD_FAILED -eq 0 ]]; then
        log_debug "Step 4: Executing build stages..."
        local build_stages_status=0
        set +e
        build_selected_stages
        build_stages_status=$?
        set -e
        log_debug "build_selected_stages finished with exit code: $build_stages_status" # Added exit code log
        if [[ $build_stages_status -ne 0 ]]; then
            log_error "Build process completed with errors during stages (Exit Code: $build_stages_status)."
            BUILD_FAILED=1
        else
            log_success "All selected build stages completed successfully."
        fi
        log_debug "LAST_SUCCESSFUL_TAG after build stages: ${LAST_SUCCESSFUL_TAG:-<unset>}"
    else
        log_warning "Skipping Step 4 (Build Stages) because BUILD_FAILED is $BUILD_FAILED."
    fi
    log_debug "After Step 4: BUILD_FAILED=$BUILD_FAILED"

    # --- Post-Build Actions ---
    local final_image_tag="${LAST_SUCCESSFUL_TAG:-}"
    local final_timestamp_tag=""

    # 5. Pre-Tagging Verification, Tagging, Verification (Only if build SUCCEEDED)
    if [[ $BUILD_FAILED -eq 0 && -n "$final_image_tag" ]]; then
        log_debug "Step 5: Performing pre-tagging verification..."
        local pre_tag_status=0
        set +e
        perform_pre_tagging_pull "$final_image_tag" "${skip_intermediate_push_pull:-y}"
        pre_tag_status=$?
        set -e
        log_debug "perform_pre_tagging_pull finished with exit code: $pre_tag_status"
        if [[ $pre_tag_status -ne 0 ]]; then
            log_warning "Pre-tagging verification failed for ${final_image_tag} (Exit Code: $pre_tag_status). Final tag may not be accessible."
        else
            log_success "Pre-tagging verification passed for ${final_image_tag}."
        fi

        log_debug "Step 6: Creating final timestamp tag..."
        local create_tag_status=0
        local created_tag=""
        set +e
        created_tag=$(create_final_timestamp_tag "$final_image_tag" "$DOCKER_USERNAME" "$DOCKER_REPO_PREFIX" "${skip_intermediate_push_pull:-y}" "${DOCKER_REGISTRY:-}")
        create_tag_status=$? # $? reflects the docker tag/push command inside, not the echo. We need to check if created_tag is empty.
        set -e
        log_debug "create_final_timestamp_tag attempt finished (tag: '$created_tag', status: $create_tag_status)"
        # Check if the function *outputted* a tag, as $? might be 0 from the echo even if tagging failed internally
        if [[ $create_tag_status -ne 0 || -z "$created_tag" ]]; then
             log_warning "Failed to create or push timestamp tag for ${final_image_tag} (Status: $create_tag_status)."
        else
            final_timestamp_tag="$created_tag"
            log_success "Created timestamp tag: $final_timestamp_tag"
            log_debug "Updating DEFAULT_IMAGE_NAME in .env to $final_timestamp_tag"
            local update_env_status=0
            set +e
            update_env_var "DEFAULT_IMAGE_NAME" "$final_timestamp_tag"
            update_env_status=$?
            set -e
            if [[ $update_env_status -ne 0 ]]; then
                log_warning "Failed to update DEFAULT_IMAGE_NAME in .env file (Exit Code: $update_env_status)."
            fi
        fi

        log_debug "Step 7: Verifying all built images exist locally..."
        local verify_local_status=0
        local all_tags=("$final_image_tag")
        [[ -n "$final_timestamp_tag" ]] && all_tags+=("$final_timestamp_tag")
        set +e
        verify_all_images_exist_locally "${all_tags[@]}"
        verify_local_status=$?
        set -e
        log_debug "verify_all_images_exist_locally finished with exit code: $verify_local_status"
        if [[ $verify_local_status -ne 0 ]]; then
            log_warning "Final local verification failed (Exit Code: $verify_local_status)."
        else
            log_success "All built images verified locally: ${all_tags[*]}"
        fi
    fi # End post-build tagging/verification block

    # 8. Post-Build Summary & Menu
    log_debug "Step 8: Post-Build Summary & Menu..."
    # (Summary logging remains the same)
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

    if [[ -n "$final_image_tag" ]]; then
        log_debug "Running post-build menu..."
        local post_menu_status=0
        set +e
        run_post_build_menu "$final_image_tag" "$final_timestamp_tag"
        post_menu_status=$?
        set -e
        log_debug "run_post_build_menu finished with exit code: $post_menu_status"
        # Don't change BUILD_FAILED based on post-build menu
    else
        log_warning "Skipping post-build menu as no image was successfully built."
    fi

    log_end # Log script end
    log_info "Returning overall build status: $BUILD_FAILED"
    return $BUILD_FAILED
}

# --- Script Execution ---\
trap cleanup EXIT INT TERM
main
exit $?

# --- Footer ---
# Description: Main build script orchestrator. Fixed unbound variable error with fallback for BASH_SOURCE. Added more exit code checks.
# Author: kairin / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-212500-UNBOUNDFIX
