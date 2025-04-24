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
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/logging.sh" || { echo "Error: logging.sh not found."; exit 1; }
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


# --- Configuration ---
export BUILD_DIR="$SCRIPT_DIR/build"
export LOG_DIR="$SCRIPT_DIR/logs"
export MAIN_LOG="$LOG_DIR/build-$(get_system_datetime).log"
export ERROR_LOG="$LOG_DIR/errors-$(get_system_datetime).log"
export JETC_DEBUG="${JETC_DEBUG:-false}" # Enable debug logging if JETC_DEBUG=true

# --- Initialization ---
init_logging "$LOG_DIR" "$MAIN_LOG" "$ERROR_LOG"
log_start "$MAIN_LOG"
check_dependencies "docker" "dialog" # Check essential dependencies

# --- Main Build Process ---
main() {
    log_message "Starting Jetson Container Build Process..."

    # 1. Handle User Interaction (Gets prefs, updates .env, exports vars for this run)
    if ! handle_user_interaction; then
        log_error "Build cancelled by user or error during interaction." "$ERROR_LOG"
        exit 1
    fi
    # Variables like DOCKER_USERNAME, SELECTED_BASE_IMAGE, use_cache, etc.,
    # SELECTED_FOLDERS_LIST are now exported by handle_user_interaction sourcing the prefs file.
    
    # 2. Setup Buildx Builder
    log_message "Setting up Docker buildx builder..."
    if ! setup_buildx_builder; then
        log_error "Failed to setup Docker buildx builder. Cannot proceed." "$ERROR_LOG"
        exit 1
    fi
    log_message "Docker buildx builder setup complete."

    # 3. Determine Build Order (Based on SELECTED_FOLDERS_LIST from user interaction)
    # This function exports ORDERED_FOLDERS and SELECTED_FOLDERS_MAP
    if ! determine_build_order "$BUILD_DIR" "${SELECTED_FOLDERS_LIST:-}"; then
        log_error "Failed to determine build order. Check build directory structure and selections." "$ERROR_LOG"
        exit 1
    fi
    # ORDERED_FOLDERS and SELECTED_FOLDERS_MAP are now available

    # 4. Execute Build Stages (Uses exported variables from steps 1 & 2)
    # build_selected_stages uses ORDERED_FOLDERS, SELECTED_FOLDERS_MAP, and other prefs
    if ! build_selected_stages; then
        log_error "Build process completed with errors. Check logs in $LOG_DIR." "$ERROR_LOG"
        # Optionally run post-build menu even on failure?
        run_post_build_menu "${LAST_SUCCESSFUL_TAG:-No image built}"
        exit 1
    fi

    # 5. Pre-Tagging Verification - Check the built image can be pulled
    log_message "Performing pre-tagging verification on ${LAST_SUCCESSFUL_TAG}..."
    if ! perform_pre_tagging_pull "${LAST_SUCCESSFUL_TAG}"; then
        log_warning "Pre-tagging verification failed. Final tag may not be accessible." "$ERROR_LOG"
        # Continue despite warnings - this is just a verification step
    else
        log_success "Pre-tagging verification passed."
    fi

    # 6. Final Tagging - Generate timestamp tag
    log_message "Creating timestamp tag for final image..."
    local timestamp_tag
    if ! timestamp_tag=$(create_final_timestamp_tag "${LAST_SUCCESSFUL_TAG}" "${DOCKER_USERNAME}" "${DOCKER_REPO_PREFIX}" "${DOCKER_REGISTRY:-}"); then
        log_warning "Failed to create timestamp tag for ${LAST_SUCCESSFUL_TAG}. Continuing without timestamp tag." "$ERROR_LOG"
    else
        log_success "Created timestamp tag: $timestamp_tag"
        export FINAL_TIMESTAMP_TAG="$timestamp_tag"
        
        # Update environment variables with the new tag
        if ! update_env_var "DEFAULT_IMAGE_NAME" "$timestamp_tag"; then
            log_warning "Failed to update DEFAULT_IMAGE_NAME in .env file." "$ERROR_LOG"
        fi
    fi

    # 7. Verify all images exist locally
    log_message "Verifying all built images exist locally..."
    local all_tags=("${LAST_SUCCESSFUL_TAG}")
    [[ -n "${FINAL_TIMESTAMP_TAG:-}" ]] && all_tags+=("$FINAL_TIMESTAMP_TAG")
    
    if ! verify_all_images_exist_locally "${all_tags[@]}"; then
        log_warning "Final verification failed. Some expected images might be missing locally." "$ERROR_LOG"
    else
        log_success "All built images verified locally."
    fi

    # 8. Post-Build Actions (Verification, Menu)
    log_message "Build process completed successfully."
    log_message "Final Image Tag: ${LAST_SUCCESSFUL_TAG}"
    [[ -n "${FINAL_TIMESTAMP_TAG:-}" ]] && log_message "Timestamp Tag: ${FINAL_TIMESTAMP_TAG}"

    # Run the post-build menu
    run_post_build_menu "${LAST_SUCCESSFUL_TAG}" "${FINAL_TIMESTAMP_TAG:-}"

    log_end "$MAIN_LOG"
    exit 0
}

# --- Script Execution ---
# Ensure cleanup runs on exit
trap cleanup EXIT INT TERM
# Run the main function
main

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Current directory
# │   └── build.sh               <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Main build orchestrator script. Refactored to use user_interaction.sh and build_order.sh.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-095000-BUILDREF