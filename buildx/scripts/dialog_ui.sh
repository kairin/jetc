#!/bin/bash

# Dialog UI helpers for Jetson Container build system

SCRIPT_DIR_DLG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR_DLG/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# shellcheck disable=SC1091
# source "$SCRIPT_DIR_DLG/env_helpers.sh" || { echo "Error: env_helpers.sh not found."; exit 1; } # env_helpers seems removed/merged? Ensure load_env_variables is available.
# shellcheck disable=SC1091
source "$SCRIPT_DIR_DLG/env_setup.sh" || { echo "Error: env_setup.sh not found (needed for load_env_variables)."; exit 1; }
# Source docker_helpers for pull_image and check_install_dialog
# shellcheck disable=SC1091
source "$SCRIPT_DIR_DLG/docker_helpers.sh" || { echo "Error: docker_helpers.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_DLG/system_checks.sh" || { echo "Error: system_checks.sh not found (needed for check_install_dialog)."; exit 1; }


# --- Fallback Basic Prompts (No dialog) ---
# Renamed to _show_main_menu_basic
_show_main_menu_basic() {
  echo "DEBUG: Entering _show_main_menu_basic function." >&2
  # Always load .env before presenting prompts
  load_env_variables # From env_setup.sh

  local PREFS_FILE="/tmp/build_prefs.sh"
  # Ensure trap cleans up PREFS_FILE on exit/error
  trap 'rm -f "$PREFS_FILE"' EXIT TERM INT

  local temp_registry="$DOCKER_REGISTRY"
  local temp_username="$DOCKER_USERNAME"
  local temp_prefix="$DOCKER_REPO_PREFIX"

  # --- Docker Info ---
  read -p "Docker Registry (leave empty for Docker Hub) [$temp_registry]: " input_registry
  temp_registry=${input_registry:-$temp_registry}

  while true; do
    read -p "Docker Username (required) [$temp_username]: " input_username
    temp_username=${input_username:-$temp_username}
    if [[ -n "$temp_username" ]]; then break; else echo "Username cannot be empty."; fi
  done

  while true; do
    read -p "Docker Repo Prefix (required) [$temp_prefix]: " input_prefix
    temp_prefix=${input_prefix:-$temp_prefix}
    if [[ -n "$temp_prefix" ]]; then break; else echo "Repo Prefix cannot be empty."; fi
  done
  DOCKER_REGISTRY="$temp_registry"
  DOCKER_USERNAME="$temp_username"
  DOCKER_REPO_PREFIX="$temp_prefix"
  echo "Using Registry: ${DOCKER_REGISTRY:-Docker Hub}, User: $DOCKER_USERNAME, Prefix: $DOCKER_REPO_PREFIX"
  echo "-------------------------"

  # --- Select Stages ---
  local build_dir="$SCRIPT_DIR_DLG/../build"
  local numbered_folders=()
  local selected_folders_list=""
  local folder_options=()
  local folder_count=0

  if [ -d "$build_dir" ]; then
      mapfile -t numbered_folders < <(find "$build_dir" -maxdepth 1 -mindepth 1 -type d -name '[0-9]*-*' | sort -V)
      if [[ ${#numbered_folders[@]} -gt 0 ]]; then
          echo "Available build stages (folders):"
          for i in "${!numbered_folders[@]}"; do
              folder_name=$(basename "${numbered_folders[$i]}")
              echo "  $((i+1))) $folder_name"
              folder_options+=("$folder_name")
              ((folder_count++))
          done
          read -p "Enter numbers of stages to build (e.g., '1 3 4'), or leave empty for ALL: " selection_input
          if [[ -z "$selection_input" ]]; then
              selected_folders_list="${folder_options[*]}" # Assign all options if empty
              echo "Building ALL stages."
          else
              local temp_selected=()
              # Properly handle space-separated input
              read -r -a selection_array <<< "$selection_input"
              for num in "${selection_array[@]}"; do
                  if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= folder_count )); then
                      # Add the folder name corresponding to the number (index is num-1)
                      temp_selected+=("${folder_options[$((num-1))]}")
                  else
                      echo "Warning: Invalid selection '$num' ignored." >&2
                  fi
              done
              selected_folders_list="${temp_selected[*]}" # Join selected names with spaces
          fi
      else
          echo "No numbered build folders found in $build_dir."
      fi
  else
      echo "Build directory $build_dir not found." >&2
  fi
  echo "Selected stages: ${selected_folders_list:-None}"
  echo "-------------------------"

  # --- Build Options ---
  local use_cache="n" use_squash="n" skip_intermediate_push_pull="y" use_builder="y"

  read -p "Use build cache? (y/n) [n]: " use_cache_input; use_cache=${use_cache_input:-n}
  while [[ "$use_cache" != "y" && "$use_cache" != "n" ]]; do read -p "Invalid. Use cache? (y/n) [n]: " use_cache_input; use_cache=${use_cache_input:-n}; done

  read -p "Squash layers (experimental)? (y/n) [n]: " use_squash_input; use_squash=${use_squash_input:-n}
  while [[ "$use_squash" != "y" && "$use_squash" != "n" ]]; do read -p "Invalid. Squash? (y/n) [n]: " use_squash_input; use_squash=${use_squash_input:-n}; done

  read -p "Build locally only (skip push/pull)? (y/n) [y]: " skip_intermediate_input; skip_intermediate_push_pull=${skip_intermediate_input:-y}
  while [[ "$skip_intermediate_push_pull" != "y" && "$skip_intermediate_push_pull" != "n" ]]; do read -p "Invalid. Local build? (y/n) [y]: " skip_intermediate_input; skip_intermediate_push_pull=${skip_intermediate_input:-y}; done

  read -p "Use Optimized Jetson Builder? (y/n) [y]: " use_builder_input; use_builder=${use_builder_input:-y}
  while [[ "$use_builder" != "y" && "$use_builder" != "n" ]]; do read -p "Invalid. Use builder? (y/n) [y]: " use_builder_input; use_builder=${use_builder_input:-y}; done
  echo "-------------------------"

  # --- Base Image ---
  local current_default_base_image_display="$DEFAULT_BASE_IMAGE"
  local SELECTED_IMAGE_TAG="$DEFAULT_BASE_IMAGE"

  echo "Default base image: $current_default_base_image_display"
  read -p "Action? (u=Use existing, p=Pull default, c=Specify custom) [u]: " base_action_input
  local base_action=${base_action_input:-u}

  case "$base_action" in
    p|P)
      echo "Pulling base image: $current_default_base_image_display" >&2
      if ! pull_image "$current_default_base_image_display"; then echo "Warning: Failed to pull base image." >&2; fi
      SELECTED_IMAGE_TAG="$current_default_base_image_display"
      ;;
    c|C)
      read -p "Enter full URL/tag of the custom base image: " custom_image
      if [ -z "$custom_image" ]; then
        echo "No image specified, using default: $current_default_base_image_display" >&2
        SELECTED_IMAGE_TAG="$current_default_base_image_display"
      else
        SELECTED_IMAGE_TAG="$custom_image"
        echo "Attempting to pull custom base image: $SELECTED_IMAGE_TAG" >&2
         if ! pull_image "$SELECTED_IMAGE_TAG"; then echo "Warning: Failed to pull custom base image." >&2; fi
      fi
      ;;
    *) # Includes 'u' or invalid input
      echo "Using existing base image (no pull): $current_default_base_image_display" >&2
      SELECTED_IMAGE_TAG="$current_default_base_image_display"
      ;;
  esac
  echo "-------------------------"

  # --- Confirmation ---
  echo "Summary:"
  echo "  Registry: ${DOCKER_REGISTRY:-Docker Hub}, User: $DOCKER_USERNAME, Prefix: $DOCKER_REPO_PREFIX"
  echo "  Selected Stages: ${selected_folders_list:-None (will build none)}"
  echo "  Use Cache: $use_cache, Squash: $use_squash, Local Build Only: $skip_intermediate_push_pull, Use Builder: $use_builder"
  echo "  Base Image for First Stage: $SELECTED_IMAGE_TAG"
  read -p "Proceed with build? (y/n) [y]: " confirm_build
  if [[ "${confirm_build:-y}" != "y" ]]; then
      echo "Build cancelled." >&2
      # Explicitly remove trap and temp file on cancellation
      trap - EXIT TERM INT
      rm -f "$PREFS_FILE"
      return 1 # Return failure code
  fi

  # Write selected preferences to the temp file
  {
    echo "export DOCKER_USERNAME=\"${DOCKER_USERNAME:-}\""
    echo "export DOCKER_REPO_PREFIX=\"${DOCKER_REPO_PREFIX:-}\""
    echo "export DOCKER_REGISTRY=\"${DOCKER_REGISTRY:-}\""
    echo "export use_cache=\"${use_cache:-n}\""
    echo "export use_squash=\"${use_squash:-n}\""
    echo "export skip_intermediate_push_pull=\"${skip_intermediate_push_pull:-y}\""
    echo "export use_builder=\"${use_builder:-y}\""
    echo "export SELECTED_BASE_IMAGE=\"${SELECTED_IMAGE_TAG:-}\""
    echo "export PLATFORM=\"${PLATFORM:-linux/arm64}\""
    echo "export SELECTED_FOLDERS_LIST=\"${selected_folders_list:-}\"" # Quote list
  } > "$PREFS_FILE"
  echo "DEBUG: Exiting _show_main_menu_basic function." >&2
  # Remove the trap *only* on successful completion, PREFS_FILE will be sourced by caller
  trap - EXIT TERM INT
  return 0
}


# --- Main Dialog Function ---
# Renamed from get_user_preferences
# This is the function that should be called externally
show_main_menu() {
  echo "DEBUG: Entering show_main_menu function." >&2
  # Always load .env before presenting dialogs
  load_env_variables # From env_setup.sh

  # Check if dialog is available, fallback if not
  echo "DEBUG: Checking dialog availability..." >&2
  # check_install_dialog is now in system_checks.sh
  if ! check_install_dialog; then
    echo "DEBUG: Dialog check failed or not available. Falling back to basic prompts." >&2
    _show_main_menu_basic # Call the renamed basic function
    return $?
  fi
  echo "DEBUG: Dialog check succeeded. Proceeding with dialog UI." >&2

  # --- Dialog Implementation ---
  local PREFS_FILE="/tmp/build_prefs.sh"
  local temp_options temp_base_choice temp_custom_image temp_docker_info temp_folders
  temp_options=$(mktemp) || { echo "Failed to create temp file"; return 1; }
  temp_base_choice=$(mktemp) || { echo "Failed to create temp file"; rm -f "$temp_options"; return 1; }
  temp_custom_image=$(mktemp) || { echo "Failed to create temp file"; rm -f "$temp_options" "$temp_base_choice"; return 1; }
  temp_docker_info=$(mktemp) || { echo "Failed to create temp file"; rm -f "$temp_options" "$temp_base_choice" "$temp_custom_image"; return 1; }
  temp_folders=$(mktemp) || { echo "Failed to create temp file"; rm -f "$temp_options" "$temp_base_choice" "$temp_custom_image" "$temp_docker_info"; return 1; }

  echo "DEBUG: Starting dialog subshell..." >&2
  ( # Start subshell for dialogs
    # Ensure temp files are cleaned up if subshell exits unexpectedly
    trap 'rm -f "$temp_options" "$temp_base_choice" "$temp_custom_image" "$temp_docker_info" "$temp_folders"' EXIT TERM INT

    # Dialog settings
    local DIALOG_HEIGHT=12
    local DIALOG_WIDTH=85
    local CHECKLIST_HEIGHT=6
    local FORM_HEIGHT=3
    local FOLDER_LIST_HEIGHT=10

    # Pre-populate from environment variables loaded by load_env_variables
    local temp_registry="$DOCKER_REGISTRY"
    local temp_username="$DOCKER_USERNAME"
    local temp_prefix="$DOCKER_REPO_PREFIX"

    # --- Step 0: Docker Information ---
    while true; do
      # Use --form for Docker info
      dialog --backtitle "Docker Build Configuration" \
             --title "Step 0: Docker Information" \
             --form "Enter your Docker repository details:" \
             $DIALOG_HEIGHT $DIALOG_WIDTH $FORM_HEIGHT \
             "Registry (optional):" 1 1 "$temp_registry" 1 25 50 0 \
             "Username (required):" 2 1 "$temp_username" 2 25 50 0 \
             "Repo Prefix (required):" 3 1 "$temp_prefix" 3 25 50 0 \
             2> "$temp_docker_info"

      local form_exit_status=$?
      if [ $form_exit_status -ne 0 ]; then
        exit 1 # Exit subshell on cancel
      fi

      # Read values back from temp file (newline separated)
      local input_registry input_username input_prefix
      read -r input_registry < <(sed -n '1p' "$temp_docker_info")
      read -r input_username < <(sed -n '2p' "$temp_docker_info")
      read -r input_prefix < <(sed -n '3p' "$temp_docker_info")

      # Validate required fields
      if [[ -z "$input_username" || -z "$input_prefix" ]]; then
        dialog --msgbox "Username and Repo Prefix are required. Please fill them in." 6 50
        # Re-populate for next loop iteration
        temp_registry="$input_registry"
        temp_username="$input_username"
        temp_prefix="$input_prefix"
      else
        # Update variables and break loop
        DOCKER_REGISTRY="$input_registry"
        DOCKER_USERNAME="$input_username"
        DOCKER_REPO_PREFIX="$input_prefix"
        break
      fi
    done
    capture_screenshot "step0_docker_info"

    # --- Step 0.5: Select Build Stages ---
    local build_dir="$SCRIPT_DIR_DLG/../build"
    local folder_checklist_items=()
    local numbered_folders=()
    local folder_count=0
    if [ -d "$build_dir" ]; then
        # Find numbered folders up to depth 2 (handles 01-04-cuda/001-cuda structure)
        mapfile -t numbered_folders < <(find "$build_dir" -maxdepth 2 -mindepth 1 -type d -name '[0-9]*-*' | sort -V)
        if [[ ${#numbered_folders[@]} -gt 0 ]]; then
            folder_count=${#numbered_folders[@]}
            local i=1
            for folder_path in "${numbered_folders[@]}"; do
                local folder_name=$(basename "$folder_path")
                # Check if it's a sub-stage for display purposes
                local display_name="$folder_name"
                local parent_dir=$(dirname "$folder_path")
                if [[ "$parent_dir" != "$build_dir" ]]; then
                    display_name="  -> $(basename "$parent_dir")/$folder_name"
                fi
                # Add path as tag, name as item, default OFF
                folder_checklist_items+=("$folder_path" "$display_name" "off")
                i=$((i+1))
            done

            # Use --checklist for stages
            dialog --backtitle "Docker Build Configuration" \
                   --title "Step 0.5: Select Build Stages ($folder_count found)" \
                   --separate-output \
                   --checklist "Use SPACE to select stages to build:" \
                   $((DIALOG_HEIGHT + FOLDER_LIST_HEIGHT)) $DIALOG_WIDTH $FOLDER_LIST_HEIGHT \
                   "${folder_checklist_items[@]}" \
                   2> "$temp_folders"

            local checklist_exit_status=$?
            if [ $checklist_exit_status -ne 0 ]; then
              exit 1 # Exit subshell on cancel
            fi
            capture_screenshot "step0.5_select_stages"
        else
            dialog --msgbox "No numbered build stage folders found in '$build_dir' (checked depth 2)." 6 60
        fi
    else
        dialog --msgbox "Build directory '$build_dir' not found. Cannot select stages." 6 60
    fi

    local selected_folders_list=""
    if [[ -s "$temp_folders" ]]; then # Check if temp file is not empty
        # Read selected paths (tags) into an array
        local temp_sel_array=()
        mapfile -t temp_sel_array < "$temp_folders"
        # Convert paths back to basenames for SELECTED_FOLDERS_LIST
        local selected_basenames=()
        for sel_path in "${temp_sel_array[@]}"; do
            selected_basenames+=("$(basename "$sel_path")")
        done
        selected_folders_list="${selected_basenames[*]}" # Space separated list of basenames
    else
        selected_folders_list="" # Explicitly empty if nothing selected or no stages found
    fi
    local stage_count=${#temp_sel_array[@]} # Count selected stages

    # --- Step 1: Build Options ---
    # Defaults (can be pre-set based on .env if desired)
    local use_cache="n"
    local use_squash="n"
    local skip_intermediate_push_pull="y"
    local use_builder="y"

    dialog --backtitle "Docker Build Configuration" \
           --title "Step 1: Build Options" \
           --checklist "Select build options (SPACE to toggle):" \
           $DIALOG_HEIGHT $DIALOG_WIDTH $CHECKLIST_HEIGHT \
           "cache"       "Use build cache (--no-cache if off)"             "${use_cache}" \
           "squash"      "Squash layers (--squash, experimental)"          "${use_squash}" \
           "local_build" "Build locally only (--load if on, --push if off)" "${skip_intermediate_push_pull}" \
           "use_builder" "Use Buildx builder (jetson-builder)"             "${use_builder}" \
           2> "$temp_options"

    capture_screenshot "step1_build_options"
    local checklist_exit_status=$?
    if [ $checklist_exit_status -ne 0 ]; then
      exit 1 # Exit subshell on cancel
    fi
    local selected_options
    selected_options=$(cat "$temp_options")
    # Update variables based on selection
    [[ "$selected_options" == *'"cache"'* ]] && use_cache="y" || use_cache="n"
    [[ "$selected_options" == *'"squash"'* ]] && use_squash="y" || use_squash="n"
    [[ "$selected_options" == *'"local_build"'* ]] && skip_intermediate_push_pull="y" || skip_intermediate_push_pull="n"
    [[ "$selected_options" == *'"use_builder"'* ]] && use_builder="y" || use_builder="n"

    # --- Step 2: Base Image Selection ---
    local current_default_base_image_display="$DEFAULT_BASE_IMAGE" # From env_setup.sh
    local SELECTED_IMAGE_TAG="$DEFAULT_BASE_IMAGE" # Start with default
    local BASE_IMAGE_ACTION="use_default" # Default action

    local MENU_HEIGHT=4 # Number of radio list items
    dialog --backtitle "Docker Build Configuration" \
           --title "Step 2: Base Image Selection" \
           --radiolist "Select the base image for the *first* build stage:" \
           $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
           "use_default"  "Use default: $current_default_base_image_display" "on" \
           "pull_default" "Pull default: $current_default_base_image_display" "off" \
           "specify_custom" "Specify a custom image tag" "off" \
           "list_available" "Choose from previously built images" "off" \
           2> "$temp_base_choice"

    capture_screenshot "step2_base_image_selection"
    local menu_exit_status=$?
    if [ $menu_exit_status -ne 0 ]; then
      exit 1 # Exit subshell on cancel
    fi
    BASE_IMAGE_ACTION=$(cat "$temp_base_choice")

    # Handle chosen action
    case "$BASE_IMAGE_ACTION" in
      "pull_default")
        # Attempt to pull the default image
        dialog --infobox "Pulling default base image: $DEFAULT_BASE_IMAGE..." 5 60
        if pull_docker_image "$DEFAULT_BASE_IMAGE"; then
            SELECTED_IMAGE_TAG="$DEFAULT_BASE_IMAGE"
            dialog --msgbox "Successfully pulled $DEFAULT_BASE_IMAGE." 6 60
        else
            dialog --msgbox "Failed to pull $DEFAULT_BASE_IMAGE. Check Docker connection and image name. Reverting to default tag without pulling." 8 70
            SELECTED_IMAGE_TAG="$DEFAULT_BASE_IMAGE" # Revert to default tag name
        fi
        ;;
      "specify_custom")
        # Ask for custom image tag
        dialog --inputbox "Enter custom base image tag (e.g., user/repo:tag):" $DIALOG_HEIGHT $DIALOG_WIDTH "$DEFAULT_BASE_IMAGE" 2> "$temp_custom_image"
        local input_exit_status=$?
        if [ $input_exit_status -ne 0 ]; then exit 1; fi # Exit on cancel
        local custom_tag
        custom_tag=$(cat "$temp_custom_image")
        if [[ -n "$custom_tag" ]]; then
            SELECTED_IMAGE_TAG="$custom_tag"
        else
            dialog --msgbox "No custom tag entered. Using default: $DEFAULT_BASE_IMAGE" 6 60
            SELECTED_IMAGE_TAG="$DEFAULT_BASE_IMAGE"
        fi
        ;;
      "list_available")
        # Fetch available images from .env
        local available_images_str="$AVAILABLE_IMAGES" # From env_setup.sh
        local image_options=()
        local image_count=0
        if [[ -n "$available_images_str" ]]; then
            local IFS=$'\n' # Split by newline
            local images_array=($available_images_str)
            local i=1
            for img in "${images_array[@]}"; do
                image_options+=("$i" "$img")
                i=$((i+1))
            done
            image_count=${#images_array[@]}

            dialog --title "Available Images" --menu "Select a previously built image:" $((DIALOG_HEIGHT + image_count)) $DIALOG_WIDTH $((image_count + 2)) "${image_options[@]}" 2> "$temp_custom_image"
            local menu_exit_status=$?
            if [ $menu_exit_status -eq 0 ]; then
                local selected_index
                selected_index=$(cat "$temp_custom_image")
                # Array index is selected_index - 1
                SELECTED_IMAGE_TAG="${images_array[$((selected_index - 1))]}"
            else
                # Cancelled or no selection, revert to default
                dialog --msgbox "No image selected or cancelled. Using default: $DEFAULT_BASE_IMAGE" 6 60
                SELECTED_IMAGE_TAG="$DEFAULT_BASE_IMAGE"
                BASE_IMAGE_ACTION="use_default" # Update action display
            fi
        else
            dialog --msgbox "No previously built images found in .env (AVAILABLE_IMAGES). Using default: $DEFAULT_BASE_IMAGE" 7 70
            SELECTED_IMAGE_TAG="$DEFAULT_BASE_IMAGE"
            BASE_IMAGE_ACTION="use_default" # Update action display
        fi
        ;;
      "use_default"|*) # Default case
        SELECTED_IMAGE_TAG="$DEFAULT_BASE_IMAGE"
        ;;
    esac

    # --- Final Confirmation ---
    local confirmation_message
    confirmation_message="Build Configuration Summary:\\n\\n"
    confirmation_message+="Docker Info:\\n"
    confirmation_message+="  - Registry:         ${DOCKER_REGISTRY:-Docker Hub}\\n"
    confirmation_message+="  - Username:         $DOCKER_USERNAME\\n"
    confirmation_message+="  - Repo Prefix:      $DOCKER_REPO_PREFIX\\n\\n"
    confirmation_message+="Selected Build Stages:\\n"
    if [[ -n "$selected_folders_list" ]]; then
        local stage_count
        # Use wc -w to count space-separated words
        stage_count=$(echo "$selected_folders_list" | wc -w)
        confirmation_message+="  - $stage_count stages selected: $selected_folders_list\\n\\n"
    else
        confirmation_message+="  - No numbered stages selected (or none found).\\n\\n"
    fi
    confirmation_message+="Build Options:\\n"
    confirmation_message+="  - Use Cache:          $( [[ "$use_cache" == "y" ]] && echo "Yes" || echo "No (--no-cache)" )\\n"
    confirmation_message+="  - Squash Layers:      $( [[ "$use_squash" == "y" ]] && echo "Yes (--squash)" || echo "No" )\\n"
    confirmation_message+="  - Build Locally Only: $( [[ "$skip_intermediate_push_pull" == "y" ]] && echo "Yes (--load)" || echo "No (--push)" )\\n"
    confirmation_message+="  - Use Builder:        $( [[ "$use_builder" == "y" ]] && echo "Yes (jetson-builder)" || echo "No (Default Docker)" )\\n\\n"
    confirmation_message+="Base Image for First Stage:\\n"
    confirmation_message+="  - Action Chosen:      $BASE_IMAGE_ACTION\\n"
    confirmation_message+="  - Image Tag To Use:   $SELECTED_IMAGE_TAG"

    # Dynamically calculate height? Maybe later. Use 25 for now.
    if ! dialog --yes-label "Start Build" --no-label "Cancel Build" --yesno "$confirmation_message\\n\\nProceed with build?" 25 $DIALOG_WIDTH; then
        capture_screenshot "final_confirmation_cancel"
        echo "Build canceled by user at confirmation screen. Exiting." >&2
        exit 1 # Exit subshell on cancel
    fi
    capture_screenshot "final_confirmation_proceed"

    # Write selected preferences to the temp file for the main script to source
    # Ensure PLATFORM uses the globally determined value from env_setup.sh
    {
      echo "export DOCKER_USERNAME=\"${DOCKER_USERNAME:-}\""
      echo "export DOCKER_REPO_PREFIX=\"${DOCKER_REPO_PREFIX:-}\""
      echo "export DOCKER_REGISTRY=\"${DOCKER_REGISTRY:-}\""
      # Export SELECTED_* variables for build_stages.sh
      echo "export SELECTED_USE_CACHE=\"${use_cache:-n}\""
      echo "export SELECTED_USE_SQUASH=\"${use_squash:-n}\""
      echo "export SELECTED_SKIP_INTERMEDIATE=\"${skip_intermediate_push_pull:-y}\""
      echo "export SELECTED_USE_BUILDER=\"${use_builder:-y}\""
      echo "export SELECTED_BASE_IMAGE=\"${SELECTED_IMAGE_TAG:-}\""
      echo "export PLATFORM=\"${PLATFORM:-linux/arm64}\""
      echo "export SELECTED_FOLDERS_LIST=\"${selected_folders_list:-}\"" # Quote list
    } > "$PREFS_FILE"
    exit 0 # Successful exit from subshell
  ) # End subshell
  local subshell_exit_code=$?
  echo "DEBUG: Dialog subshell exited with code: $subshell_exit_code" >&2

  # Clean up temp files regardless of subshell exit code
  rm -f "$temp_options" "$temp_base_choice" "$temp_custom_image" "$temp_docker_info" "$temp_folders"
  echo "DEBUG: Cleaned up temp files." >&2

  # Return the exit code of the subshell (0 for success, 1 for cancel)
  return $subshell_exit_code
}


# --- Footer ---
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── dialog_ui.sh       <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Provides UI elements using the 'dialog' command.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250425-080000-42595D
