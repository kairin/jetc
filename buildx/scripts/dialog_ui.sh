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
      dialog --backtitle "Docker Build Configuration" \
             --title "Step 0: Docker Information" \
             --ok-label "Next: Select Stages" \
             --cancel-label "Exit Build" \
             --form "Confirm or edit Docker details (loaded from .env):" $DIALOG_HEIGHT $DIALOG_WIDTH $FORM_HEIGHT \
             "Registry (optional, empty=Docker Hub):" 1 1 "$temp_registry"     1 40 70 0 \
             "Username (required):"                   2 1 "$temp_username"    2 40 70 0 \
             "Repository Prefix (required):"          3 1 "$temp_prefix" 3 40 70 0 \
             2>"$temp_docker_info"

      capture_screenshot "step0_docker_info" # Assumes capture_screenshot is in utils.sh
      local form_exit_status=$?
      if [ $form_exit_status -ne 0 ]; then
        echo "Docker information entry canceled (exit code: $form_exit_status). Exiting." >&2
        exit 1 # Exit subshell on cancel
      fi

      # Read values back from temp file
      mapfile -t lines < "$temp_docker_info"
      # Ensure array has enough elements to avoid unbound errors
      while [ "${#lines[@]}" -lt 3 ]; do lines+=(""); done
      temp_registry="$(echo -n "${lines[0]}" | tr -d '\r\n')"
      temp_username="$(echo -n "${lines[1]}" | tr -d '\r\n')"
      temp_prefix="$(echo -n "${lines[2]}" | tr -d '\r\n')"

      # Validate required fields
      if [[ -z "$temp_username" || -z "$temp_prefix" ]]; then
        dialog --msgbox "Validation Error:\\n\\nUsername and Repository Prefix are required.\\nPlease correct the entries." 10 $DIALOG_WIDTH
        capture_screenshot "step0_docker_info_validation_error"
        continue # Loop back to the form
      fi

      # Valid, assign to exported vars and break loop
      DOCKER_REGISTRY="$temp_registry"
      DOCKER_USERNAME="$temp_username"
      DOCKER_REPO_PREFIX="$temp_prefix"
      export DOCKER_REGISTRY DOCKER_USERNAME DOCKER_REPO_PREFIX # Make available outside subshell if needed? No, write to PREFS_FILE later.
      break
    done

    # --- Step 0.5: Select Build Stages ---
    local build_dir="$SCRIPT_DIR_DLG/../build"
    local folder_checklist_items=()
    local numbered_folders=()
    local folder_count=0
    if [ -d "$build_dir" ]; then
        mapfile -t numbered_folders < <(find "$build_dir" -maxdepth 1 -mindepth 1 -type d -name '[0-9]*-*' | sort -V) # Use -V for natural sort
        for folder_path in "${numbered_folders[@]}"; do
            folder_name=$(basename "$folder_path")
            folder_checklist_items+=("$folder_name" "" "on") # Default ON
            ((folder_count++))
        done
    fi

    local selected_folders_list=""
    if [[ $folder_count -gt 0 ]]; then
        local list_height=$(( FOLDER_LIST_HEIGHT < folder_count ? FOLDER_LIST_HEIGHT : folder_count + 2 )) # Add margin
        list_height=$(( list_height > DIALOG_HEIGHT - 4 ? DIALOG_HEIGHT - 4 : list_height )) # Ensure fits dialog
        dialog --backtitle "Docker Build Configuration" \
               --title "Step 0.5: Select Build Stages" \
               --ok-label "Next: Build Options" \
               --cancel-label "Exit Build" \
               --checklist "Select the build stages (folders) to include (Spacebar to toggle):" $DIALOG_HEIGHT $DIALOG_WIDTH $list_height \
               "${folder_checklist_items[@]}" \
               2>"$temp_folders"
        local folders_exit_status=$?
        capture_screenshot "step0.5_select_stages"
        if [ $folders_exit_status -ne 0 ]; then
            echo "Folder selection canceled (exit code: $folders_exit_status). Exiting." >&2
            exit 1 # Exit subshell on cancel
        fi
        # Read selection - dialog returns quoted strings, remove them
        # Use mapfile and join with space for safety
        local temp_sel_array=()
        mapfile -t temp_sel_array < <(sed 's/"//g' "$temp_folders")
        selected_folders_list="${temp_sel_array[*]}"
    else
        # Optionally show a message if no folders found
        dialog --msgbox "No numbered build stage folders found in '$build_dir'.\nProceeding without stage selection." 8 $DIALOG_WIDTH
        capture_screenshot "step0.5_no_stages_found"
        selected_folders_list="" # Explicitly empty
    fi

    # --- Step 1: Build Options ---
    # Defaults (can be pre-set based on .env if desired)
    local use_cache="n"
    local use_squash="n"
    local skip_intermediate_push_pull="y"
    local use_builder="y"

    dialog --backtitle "Docker Build Configuration" \
           --title "Step 1: Build Options" \
           --ok-label "Next: Base Image" \
           --cancel-label "Exit Build" \
           --checklist "Use Spacebar to toggle options, Enter to confirm:" $DIALOG_HEIGHT $DIALOG_WIDTH $CHECKLIST_HEIGHT \
           "cache"         "Use Build Cache (Faster, uses previous layers)"        "$([ "$use_cache" == "y" ] && echo "on" || echo "off")" \
           "squash"        "Squash Layers (Smaller final image, experimental)"     "$([ "$use_squash" == "y" ] && echo "on" || echo "off")" \
           "local_build"   "Build Locally Only (Faster, no registry push/pull)"    "$([ "$skip_intermediate_push_pull" == "y" ] && echo "on" || echo "off")" \
           "use_builder"   "Use Optimized Jetson Builder (Recommended)"            "$([ "$use_builder" == "y" ] && echo "on" || echo "off")" \
            2>"$temp_options"

    capture_screenshot "step1_build_options"
    local checklist_exit_status=$?
    if [ $checklist_exit_status -ne 0 ]; then
      echo "Build options selection canceled (exit code: $checklist_exit_status). Exiting." >&2
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
           --ok-label "Confirm Choice" \
           --cancel-label "Exit Build" \
           --radiolist "Choose the base image for the *first* build stage:" $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
           "use_default"    "Use Default (if locally available): $current_default_base_image_display"  "on" \
           "pull_default"   "Pull Default Image Now: $current_default_base_image_display"             "off" \
           "specify_custom" "Specify Custom Image (will attempt pull)"                "off" \
           2>"$temp_base_choice"

    capture_screenshot "step2_base_image_selection"
    local menu_exit_status=$?
    if [ $menu_exit_status -ne 0 ]; then
      echo "Base image selection canceled (exit code: $menu_exit_status). Exiting." >&2
      exit 1 # Exit subshell on cancel
    fi
    BASE_IMAGE_ACTION=$(cat "$temp_base_choice")

    # Handle chosen action
    case "$BASE_IMAGE_ACTION" in
      "specify_custom")
        dialog --backtitle "Docker Build Configuration" \
               --title "Step 2a: Custom Base Image" \
               --ok-label "Confirm Image" \
               --cancel-label "Exit Build" \
               --inputbox "Enter the full Docker image tag (e.g., user/repo:tag):" 10 $DIALOG_WIDTH "$current_default_base_image_display" \
               2>"$temp_custom_image"
        local input_exit_status=$?
        capture_screenshot "step2a_custom_base_image_input"
        if [ $input_exit_status -ne 0 ]; then
          echo "Custom base image input canceled (exit code: $input_exit_status). Exiting." >&2
          exit 1 # Exit subshell on cancel
        fi
        local entered_image
        entered_image=$(cat "$temp_custom_image")
        if [ -z "$entered_image" ]; then
          dialog --msgbox "No custom image entered. Reverting to default:\\n$current_default_base_image_display" 8 $DIALOG_WIDTH
          capture_screenshot "step2a_custom_base_image_revert"
          # Check msgbox exit status? Usually not necessary.
          SELECTED_IMAGE_TAG="$current_default_base_image_display"
          BASE_IMAGE_ACTION="use_default" # Update action for summary
        else
          SELECTED_IMAGE_TAG="$entered_image"
          dialog --infobox "Attempting to pull custom base image:\\n$SELECTED_IMAGE_TAG..." 5 $DIALOG_WIDTH
          capture_screenshot "step2a_custom_base_image_pull_attempt"
          sleep 1 # Give user time to see infobox
          # Use pull_image from docker_helpers.sh
          if ! pull_image "$SELECTED_IMAGE_TAG"; then
            if dialog --yesno "Failed to pull custom base image:\\n$SELECTED_IMAGE_TAG.\\nCheck tag/URL.\\n\\nContinue build using default ($current_default_base_image_display)? Warning: Build might fail." 14 $DIALOG_WIDTH; then
               capture_screenshot "step2a_custom_base_image_pull_fail_continue"
               SELECTED_IMAGE_TAG="$current_default_base_image_display"
               BASE_IMAGE_ACTION="use_default" # Update action for summary
               dialog --msgbox "Proceeding with default base image:\\n$SELECTED_IMAGE_TAG" 8 $DIALOG_WIDTH
               capture_screenshot "step2a_custom_base_image_pull_fail_revert_msg"
            else
               capture_screenshot "step2a_custom_base_image_pull_fail_exit"
               echo "User chose to exit after failed custom image pull." >&2
               exit 1 # Exit subshell
            fi
          else
            dialog --msgbox "Successfully pulled custom base image:\\n$SELECTED_IMAGE_TAG" 8 $DIALOG_WIDTH
            capture_screenshot "step2a_custom_base_image_pull_success"
          fi
        fi
        ;;
      "pull_default")
        dialog --infobox "Attempting to pull default base image:\\n$current_default_base_image_display..." 5 $DIALOG_WIDTH
        capture_screenshot "step2_pull_default_attempt"
        sleep 1
        if ! pull_image "$current_default_base_image_display"; then
           if dialog --yesno "Failed to pull default base image:\\n$current_default_base_image_display.\\nBuild might fail if not local.\\n\\nContinue anyway?" 12 $DIALOG_WIDTH; then
              capture_screenshot "step2_pull_default_fail_continue"
              dialog --msgbox "Warning: Default image not pulled. Using local if available." 8 $DIALOG_WIDTH
              capture_screenshot "step2_pull_default_fail_continue_msg"
           else
              capture_screenshot "step2_pull_default_fail_exit"
              echo "User chose to exit after failed default image pull." >&2
              exit 1 # Exit subshell
           fi
        else
          dialog --msgbox "Successfully pulled default base image:\\n$current_default_base_image_display" 8 $DIALOG_WIDTH
          capture_screenshot "step2_pull_default_success"
        fi
        SELECTED_IMAGE_TAG="$current_default_base_image_display"
        ;;
      "use_default")
        SELECTED_IMAGE_TAG="$current_default_base_image_display"
        dialog --msgbox "Using default base image (local version if available):\\n$SELECTED_IMAGE_TAG" 8 $DIALOG_WIDTH
        capture_screenshot "step2_use_default_msg"
        ;;
      *)
        echo "Invalid base image action selected: '$BASE_IMAGE_ACTION'. Exiting." >&2
        exit 1 # Exit subshell
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
      echo "export use_cache=\"${use_cache:-n}\""
      echo "export use_squash=\"${use_squash:-n}\""
      echo "export skip_intermediate_push_pull=\"${skip_intermediate_push_pull:-y}\""
      echo "export use_builder=\"${use_builder:-y}\""
      echo "export SELECTED_BASE_IMAGE=\"${SELECTED_IMAGE_TAG:-}\""
      echo "export PLATFORM=\"${PLATFORM:-linux/arm64}\"" # Use global PLATFORM
      echo "export SELECTED_FOLDERS_LIST=\"${selected_folders_list:-}\"" # Quote list
    } > "$PREFS_FILE"
    echo "DEBUG: Dialog subshell finished internal commands." >&2
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
