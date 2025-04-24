#!/bin/bash
# Main build script for Jetson Container project

# Strict mode - Keep pipefail, temporarily manage errexit (-e)
set -uo pipefail # REMOVED -e temporarily

# ... (Sourcing commands remain the same) ...
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

# --- Main Build Process ---\
main() {
    log_info "Starting Jetson Container Build Process..."
    log_debug "JETC_DEBUG is set to: ${JETC_DEBUG}"
    BUILD_FAILED=0

    # 1. Handle User Interaction
    log_debug "Step 1: Handling user interaction..."
    local interaction_status=0
    # Temporarily disable errexit around interaction if it's complex
    set +e
    handle_user_interaction
    interaction_status=$?
    set -e # Re-enable errexit
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
        set +e # <<< Disable errexit BEFORE calling the function
        determine_build_order "$BUILD_DIR" "${SELECTED_FOLDERS_LIST:-}"
        build_order_status=$? # <<< Capture the actual exit code
        set -e # <<< Re-enable errexit AFTER the function call
        log_debug "determine_build_order finished with exit code: $build_order_status" # <<< Log the exit code

        if [[ $build_order_status -ne 0 ]]; then
            log_error "Failed to determine build order (Exit Code: $build_order_status)."
            BUILD_FAILED=1
        else
            # Log success only if exit code was 0
            log_success "Build order determined."
        fi
    else
        log_warning "Skipping Step 3 (Build Order) because BUILD_FAILED is $BUILD_FAILED."
    fi
    log_debug "After Step 3: BUILD_FAILED=$BUILD_FAILED" # <<< Check BUILD_FAILED status


    # 4. Execute Build Stages
    if [[ $BUILD_FAILED -eq 0 ]]; then
        log_debug "Step 4: Executing build stages..." # <<< Check if this appears now
        local build_stages_status=0
        set +e
        build_selected_stages
        build_stages_status=$?
        set -e
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

    # ... (rest of steps 5-8 need similar set +e / set -e wrappers and status checks) ...

    log_end # Log script end
    log_info "Returning overall build status: $BUILD_FAILED"
    return $BUILD_FAILED
}


# --- Script Execution ---\
trap cleanup EXIT INT TERM
main
exit $?

# --- Footer ---
# Description: Main build script orchestrator. Added set +e / set -e around function calls to check exit codes.
# Author: kairin / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-212000-EXITCODEDEBUG
