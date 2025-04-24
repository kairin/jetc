#!/bin/bash

# Interactive UI helpers (Dialog and Text) for Jetson Container system

SCRIPT_DIR_IUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR_IUI/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_IUI/env_helpers.sh" || { echo "Error: env_helpers.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_IUI/docker_helpers.sh" || { echo "Error: docker_helpers.sh not found."; exit 1; } # Needed for pull_image, verify_image_exists
# shellcheck disable=SC1091
source "$SCRIPT_DIR_IUI/verification.sh" || { echo "Error: verification.sh not found."; exit 1; } # Needed for post-build verify

# =========================================================================
# Generic UI Functions (Dialog with Text Fallback)
# =========================================================================

# Check dialog availability (uses function from utils.sh)
_is_dialog_available() {
  check_install_dialog >/dev/null 2>&1
}

# Show a message box or print to console
show_message() {
  local title="${1:-Message}"
  local message="${2:-}"
  local height=${3:-8}
  local width=${4:-60}

  if _is_dialog_available; then
    dialog --backtitle "Jetson Container System" --title "$title" --msgbox "$message" "$height" "$width"
  else
    echo "----------------------------------------"
    echo "$title:"
    echo "$message"
    echo "----------------------------------------"
    read -p "Press Enter to continue..." </dev/tty # Ensure prompt waits for user
  fi
}

# Ask a yes/no question, returns 0 for Yes, 1 for No/Cancel
confirm_action() {
  local question="${1:-Are you sure?}"
  local default_yes=${2:-true} # Default to Yes
  local height=${3:-8}
  local width=${4:-60}

  if _is_dialog_available; then
    local default_opt=""
    [[ "$default_yes" == "true" ]] && default_opt="--defaultno" # Inverted logic for dialog's default button focus
    
    dialog --backtitle "Jetson Container System" --title "Confirmation" --yesno "$question" "$height" "$width" $default_opt
    return $? # dialog returns 0 for Yes, 1 for No, 255 for Esc
  else
    local prompt_opts="y/N"
    local default_ans="n"
    if [[ "$default_yes" == "true" ]]; then
        prompt_opts="Y/n"
        default_ans="y"
    fi
    read -p "$question [$prompt_opts]: " answer </dev/tty
    answer=${answer:-$default_ans}
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      return 0 # Yes
    else
      return 1 # No or anything else
    fi
  fi
}

# =========================================================================
# Build Preferences UI (Moved from dialog_ui.sh)
# =========================================================================
get_build_preferences() {
  _log_debug "Entering get_build_preferences function."
  # Always load .env before presenting dialogs/prompts
  load_env_variables

  _log_debug "Checking dialog availability..."
  if ! _is_dialog_available; then
    _log_debug "Dialog check failed or not available. Falling back to basic prompts."
    get_build_preferences_basic
    return $?
  fi
  _log_debug "Dialog check succeeded. Proceeding with dialog UI."

  local PREFS_FILE="/tmp/build_prefs.sh" # Ensure this matches build_ui.sh/build.sh
  local temp_options temp_base_choice temp_custom_image temp_docker_info temp_folders
  temp_options=$(mktemp) || { echo "Failed to create temp file"; return 1; }
  temp_base_choice=$(mktemp) || { echo "Failed to create temp file"; rm -f "$temp_options"; return 1; }
  temp_custom_image=$(mktemp) || { echo "Failed to create temp file"; rm -f "$temp_options" "$temp_base_choice"; return 1; }
  temp_docker_info=$(mktemp) || { echo "Failed to create temp file"; rm -f "$temp_options" "$temp_base_choice" "$temp_custom_image"; return 1; }
  temp_folders=$(mktemp) || { echo "Failed to create temp file"; rm -f "$temp_options" "$temp_base_choice" "$temp_custom_image" "$temp_docker_info"; return 1; }

  _log_debug "Starting dialog subshell for build preferences..."
  (
    # Subshell inherits functions and sourced files
    trap 'rm -f "$temp_options" "$temp_base_choice" "$temp_custom_image" "$temp_docker_info" "$temp_folders"' EXIT TERM INT

    local DIALOG_HEIGHT=12
    local DIALOG_WIDTH=85
    local CHECKLIST_HEIGHT=6
    local FORM_HEIGHT=3
    local FOLDER_LIST_HEIGHT=10

    local temp_registry="$DOCKER_REGISTRY"
    local temp_username="$DOCKER_USERNAME"
    local temp_prefix="$DOCKER_REPO_PREFIX"

    # --- Step 0: Docker Info ---
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

      local form_exit_status=$?
      if [ $form_exit_status -ne 0 ]; then
        echo "Docker information entry canceled (exit code: $form_exit_status). Exiting." >&2
        exit 1 # Exit subshell with error
      fi

      mapfile -t lines < "$temp_docker_info"
      while [ "${#lines[@]}" -lt 3 ]; do lines+=(""); done
      temp_registry="$(echo -n "${lines[0]}" | tr -d '\r\n')"
      temp_username="$(echo -n "${lines[1]}" | tr -d '\r\n')"
      temp_prefix="$(echo -n "${lines[2]}" | tr -d '\r\n')"

      if [[ -z "$temp_username" || -z "$temp_prefix" ]]; then
        show_message "Validation Error" "Username and Repository Prefix are required.\\nPlease correct the entries." 10 $DIALOG_WIDTH
        continue
      fi

      DOCKER_REGISTRY="$temp_registry"
      DOCKER_USERNAME="$temp_username"
      DOCKER_REPO_PREFIX="$temp_prefix"
      export DOCKER_REGISTRY DOCKER_USERNAME DOCKER_REPO_PREFIX # Export for potential use within subshell if needed
      break
    done

    # --- Step 0.5: Select Build Stages ---
    local build_dir="$SCRIPT_DIR_IUI/../build"
    local folder_checklist_items=()
    local numbered_folders=()
    local folder_count=0
    if [ -d "$build_dir" ]; then
        mapfile -t numbered_folders < <(find "$build_dir" -maxdepth 1 -mindepth 1 -type d -name '[0-9]*-*' | sort)
        for folder_path in "${numbered_folders[@]}"; do
            folder_name=$(basename "$folder_path")
            folder_checklist_items+=("$folder_name" "$folder_name" "on") # Default to ON
            ((folder_count++))
        done
    fi

    local selected_folders_list=""
    if [[ $folder_count -gt 0 ]]; then
        dialog --backtitle "Docker Build Configuration" \
               --title "Step 0.5: Select Build Stages" \
               --ok-label "Next: Build Options" \
               --cancel-label "Exit Build" \
               --checklist "Select the build stages (folders) to include (Spacebar to toggle):" $DIALOG_HEIGHT $DIALOG_WIDTH $FOLDER_LIST_HEIGHT \
               "${folder_checklist_items[@]}" \
               2>"$temp_folders"
        local folders_exit_status=$?
        if [ $folders_exit_status -ne 0 ]; then
            echo "Folder selection canceled (exit code: $folders_exit_status). Exiting." >&2
            exit 1 # Exit subshell with error
        fi
        selected_folders_list=$(cat "$temp_folders" | sed 's/"//g')
    else
        selected_folders_list="" # No folders found or selected
    fi

    # --- Step 1: Build Options ---
    local use_cache="n" # Default OFF
    local use_squash="n" # Default OFF
    local skip_intermediate_push_pull="y" # Default ON (local build)
    local use_builder="y" # Default ON

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

    local checklist_exit_status=$?
    if [ $checklist_exit_status -ne 0 ]; then
      echo "Build options selection canceled (exit code: $checklist_exit_status). Exiting." >&2
      exit 1 # Exit subshell with error
    fi
    local selected_options
    selected_options=$(cat "$temp_options")
    [[ "$selected_options" == *'"cache"'* ]] && use_cache="y" || use_cache="n"
    [[ "$selected_options" == *'"squash"'* ]] && use_squash="y" || use_squash="n"
    [[ "$selected_options" == *'"local_build"'* ]] && skip_intermediate_push_pull="y" || skip_intermediate_push_pull="n"
    [[ "$selected_options" == *'"use_builder"'* ]] && use_builder="y" || use_builder="n"

    # --- Step 2: Base Image Selection ---
    local current_default_base_image_display="$DEFAULT_BASE_IMAGE" # From loaded .env
    local SELECTED_IMAGE_TAG="$DEFAULT_BASE_IMAGE" # Initialize
    local BASE_IMAGE_ACTION="use_default" # Default action

    local MENU_HEIGHT=4
    dialog --backtitle "Docker Build Configuration" \
           --title "Step 2: Base Image Selection" \
           --ok-label "Confirm Choice" \
           --cancel-label "Exit Build" \
           --radiolist "Choose the base image for the *first* build stage:" $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
           "use_default"    "Use Default (if locally available): $current_default_base_image_display"  "on" \
           "pull_default"   "Pull Default Image Now: $current_default_base_image_display"             "off" \
           "specify_custom" "Specify Custom Image (will attempt pull)"                "off" \
           2>"$temp_base_choice"

    local menu_exit_status=$?
    if [ $menu_exit_status -ne 0 ]; then
      echo "Base image selection canceled (exit code: $menu_exit_status). Exiting." >&2
      exit 1 # Exit subshell with error
    fi
    BASE_IMAGE_ACTION=$(cat "$temp_base_choice")

    case "$BASE_IMAGE_ACTION" in
      "specify_custom")
        dialog --backtitle "Docker Build Configuration" \
               --title "Step 2a: Custom Base Image" \
               --ok-label "Confirm Image" \
               --cancel-label "Exit Build" \
               --inputbox "Enter the full Docker image tag (e.g., user/repo:tag):" 10 $DIALOG_WIDTH "$current_default_base_image_display" \
               2>"$temp_custom_image"
        local input_exit_status=$?
        if [ $input_exit_status -ne 0 ]; then
          echo "Custom base image input canceled (exit code: $input_exit_status). Exiting." >&2
          exit 1 # Exit subshell with error
        fi
        local entered_image
        entered_image=$(cat "$temp_custom_image")
        if [ -z "$entered_image" ]; then
          show_message "Info" "No custom image entered. Reverting to default:\\n$current_default_base_image_display" 8 $DIALOG_WIDTH
          SELECTED_IMAGE_TAG="$current_default_base_image_display"
          BASE_IMAGE_ACTION="use_default"
        else
          SELECTED_IMAGE_TAG="$entered_image"
          show_message "Info" "Attempting to pull custom base image:\\n$SELECTED_IMAGE_TAG..." 5 $DIALOG_WIDTH # Use infobox style if possible, msgbox is fine
          if ! pull_image "$SELECTED_IMAGE_TAG"; then # Use docker_helper function
            if confirm_action "Failed to pull custom base image:\\n$SELECTED_IMAGE_TAG.\\nCheck tag/URL.\\n\\nContinue build using default ($current_default_base_image_display)? Warning: Build might fail." false 12 $DIALOG_WIDTH; then
               SELECTED_IMAGE_TAG="$current_default_base_image_display"
               BASE_IMAGE_ACTION="use_default"
               show_message "Info" "Proceeding with default base image:\\n$SELECTED_IMAGE_TAG" 8 $DIALOG_WIDTH
            else
               echo "User chose to exit after failed custom image pull." >&2
               exit 1 # Exit subshell with error
            fi
          else
            show_message "Success" "Successfully pulled custom base image:\\n$SELECTED_IMAGE_TAG" 8 $DIALOG_WIDTH
          fi
        fi
        ;;
      "pull_default")
        show_message "Info" "Attempting to pull default base image:\\n$current_default_base_image_display..." 5 $DIALOG_WIDTH
        if ! pull_image "$current_default_base_image_display"; then # Use docker_helper function
           if confirm_action "Failed to pull default base image:\\n$current_default_base_image_display.\\nBuild might fail if not local.\\n\\nContinue anyway?" false 12 $DIALOG_WIDTH; then
              show_message "Warning" "Default image not pulled. Using local if available." 8 $DIALOG_WIDTH
           else
              echo "User chose to exit after failed default image pull." >&2
              exit 1 # Exit subshell with error
           fi
        else
          show_message "Success" "Successfully pulled default base image:\\n$current_default_base_image_display" 8 $DIALOG_WIDTH
        fi
        SELECTED_IMAGE_TAG="$current_default_base_image_display"
        ;;
      "use_default")
        SELECTED_IMAGE_TAG="$current_default_base_image_display"
        show_message "Info" "Using default base image (local version if available):\\n$SELECTED_IMAGE_TAG" 8 $DIALOG_WIDTH
        ;;
      *)
        echo "Invalid base image action selected: '$BASE_IMAGE_ACTION'. Exiting." >&2
        exit 1 # Exit subshell with error
        ;;
    esac

    # --- Step 3: Confirmation ---
    local confirmation_message
    confirmation_message="Build Configuration Summary:\\n\\n"
    confirmation_message+="Docker Info:\\n"
    confirmation_message+="  - Registry:         ${DOCKER_REGISTRY:-Docker Hub}\\n"
    confirmation_message+="  - Username:         $DOCKER_USERNAME\\n"
    confirmation_message+="  - Repo Prefix:      $DOCKER_REPO_PREFIX\\n\\n"
    confirmation_message+="Selected Build Stages:\\n"
    if [[ -n "$selected_folders_list" ]]; then
        confirmation_message+="  - $(echo "$selected_folders_list" | wc -w) stages selected: $selected_folders_list\\n\\n"
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

    if ! confirm_action "$confirmation_message\\n\\nProceed with build?" true 25 $DIALOG_WIDTH; then
        echo "Build canceled by user at confirmation screen. Exiting." >&2
        exit 1 # Exit subshell with error
    fi

    # --- Save Preferences to File and .env ---
    # Update .env first (using function from env_helpers.sh)
    update_env_variable "DOCKER_USERNAME" "$DOCKER_USERNAME"
    update_env_variable "DOCKER_REGISTRY" "$DOCKER_REGISTRY"
    update_env_variable "DOCKER_REPO_PREFIX" "$DOCKER_REPO_PREFIX"
    update_env_variable "DEFAULT_BASE_IMAGE" "$SELECTED_IMAGE_TAG" # Save selected as new default base
    # Note: We don't save build options like cache/squash/load to .env by default

    # Export selections to the preferences file for the current build run
    {
      echo "export DOCKER_USERNAME=\"${DOCKER_USERNAME:-}\""
      echo "export DOCKER_REPO_PREFIX=\"${DOCKER_REPO_PREFIX:-}\""
      echo "export DOCKER_REGISTRY=\"${DOCKER_REGISTRY:-}\""
      echo "export use_cache=\"${use_cache:-n}\""
      echo "export use_squash=\"${use_squash:-n}\""
      echo "export skip_intermediate_push_pull=\"${skip_intermediate_push_pull:-n}\""
      echo "export use_builder=\"${use_builder:-y}\""
      echo "export SELECTED_BASE_IMAGE=\"${SELECTED_IMAGE_TAG:-}\""
      echo "export PLATFORM=\"${PLATFORM:-linux/arm64}\"" # Keep platform setting
      echo "export platform=\"${PLATFORM:-linux/arm64}\"" # Keep lowercase too
      echo "export SELECTED_FOLDERS_LIST=\"${selected_folders_list:-}\""
    } > "$PREFS_FILE"
    _log_debug "Build preferences saved to $PREFS_FILE"
    _log_debug "Dialog subshell finished successfully."
    exit 0 # Exit subshell successfully
  )
  local subshell_exit_code=$?
  _log_debug "Dialog subshell for build preferences exited with code: $subshell_exit_code"
  # Clean up temp files regardless of subshell exit code
  rm -f "$temp_options" "$temp_base_choice" "$temp_custom_image" "$temp_docker_info" "$temp_folders"
  _log_debug "Cleaned up build preference temp files."

  return $subshell_exit_code
}

get_build_preferences_basic() {
  _log_debug "Entering get_build_preferences_basic function."
  # Always load .env before presenting prompts
  load_env_variables

  local PREFS_FILE="/tmp/build_prefs.sh" # Ensure this matches build_ui.sh/build.sh
  trap 'rm -f "$PREFS_FILE"' EXIT TERM INT # Ensure cleanup on exit

  local temp_registry="$DOCKER_REGISTRY"
  local temp_username="$DOCKER_USERNAME"
  local temp_prefix="$DOCKER_REPO_PREFIX"

  # --- Step 0: Docker Info ---
  read -p "Docker Registry (leave empty for Docker Hub) [$temp_registry]: " input_registry </dev/tty
  temp_registry=${input_registry:-$temp_registry}

  while true; do
    read -p "Docker Username (required) [$temp_username]: " input_username </dev/tty
    temp_username=${input_username:-$temp_username}
    if [[ -n "$temp_username" ]]; then break; else echo "Username cannot be empty."; fi
  done

  while true; do
    read -p "Docker Repo Prefix (required) [$temp_prefix]: " input_prefix </dev/tty
    temp_prefix=${input_prefix:-$temp_prefix}
    if [[ -n "$temp_prefix" ]]; then break; else echo "Repo Prefix cannot be empty."; fi
  done
  DOCKER_REGISTRY="$temp_registry"
  DOCKER_USERNAME="$temp_username"
  DOCKER_REPO_PREFIX="$temp_prefix"
  echo "Using Registry: ${DOCKER_REGISTRY:-Docker Hub}, User: $DOCKER_USERNAME, Prefix: $DOCKER_REPO_PREFIX"
  echo "-------------------------"

  # --- Step 0.5: Select Build Stages ---
  local build_dir="$SCRIPT_DIR_IUI/../build"
  local numbered_folders=()
  local selected_folders_list=""
  local folder_options=()
  local folder_count=0

  if [ -d "$build_dir" ]; then
      mapfile -t numbered_folders < <(find "$build_dir" -maxdepth 1 -mindepth 1 -type d -name '[0-9]*-*' | sort)
      if [[ ${#numbered_folders[@]} -gt 0 ]]; then
          echo "Available build stages (folders):"
          for i in "${!numbered_folders[@]}"; do
              folder_name=$(basename "${numbered_folders[$i]}")
              echo "  $((i+1))) $folder_name"
              folder_options+=("$folder_name")
              ((folder_count++))
          done
          read -p "Enter numbers of stages to build (e.g., '1 3 4'), or leave empty for ALL: " selection_input </dev/tty
          if [[ -z "$selection_input" ]]; then
              selected_folders_list="${folder_options[*]}"
              echo "Building ALL stages."
          else
              local temp_selected=()
              for num in $selection_input; do
                  if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= folder_count )); then
                      temp_selected+=("${folder_options[$((num-1))]}")
                  else
                      echo "Warning: Invalid selection '$num' ignored." >&2
                  fi
              done
              selected_folders_list="${temp_selected[*]}"
          fi
      else
          echo "No numbered build folders found in $build_dir."
      fi
  else
      echo "Build directory $build_dir not found." >&2
  fi
  echo "Selected stages: ${selected_folders_list:-None}"
  echo "-------------------------"

  # --- Step 1: Build Options ---
  local use_cache="n" use_squash="n" skip_intermediate_push_pull="y" use_builder="y"

  read -p "Use build cache? (y/n) [n]: " use_cache_input </dev/tty; use_cache=${use_cache_input:-n}
  while [[ "$use_cache" != "y" && "$use_cache" != "n" ]]; do read -p "Invalid. Use cache? (y/n) [n]: " use_cache_input </dev/tty; use_cache=${use_cache_input:-n}; done

  read -p "Squash layers (experimental)? (y/n) [n]: " use_squash_input </dev/tty; use_squash=${use_squash_input:-n}
  while [[ "$use_squash" != "y" && "$use_squash" != "n" ]]; do read -p "Invalid. Squash? (y/n) [n]: " use_squash_input </dev/tty; use_squash=${use_squash_input:-n}; done

  read -p "Build locally only (skip push/pull)? (y/n) [y]: " skip_intermediate_input </dev/tty; skip_intermediate_push_pull=${skip_intermediate_input:-y}
   while [[ "$skip_intermediate_push_pull" != "y" && "$skip_intermediate_push_pull" != "n" ]]; do read -p "Invalid. Local build? (y/n) [y]: " skip_intermediate_input </dev/tty; skip_intermediate_push_pull=${skip_intermediate_input:-y}; done

  read -p "Use Optimized Jetson Builder? (y/n) [y]: " use_builder_input </dev/tty; use_builder=${use_builder_input:-y}
  while [[ "$use_builder" != "y" && "$use_builder" != "n" ]]; do read -p "Invalid. Use builder? (y/n) [y]: " use_builder_input </dev/tty; use_builder=${use_builder_input:-y}; done
  echo "-------------------------"

  # --- Step 2: Base Image Selection ---
  local current_default_base_image_display="$DEFAULT_BASE_IMAGE" # From loaded .env
  local SELECTED_IMAGE_TAG="$DEFAULT_BASE_IMAGE" # Initialize

  echo "Default base image: $current_default_base_image_display"
  read -p "Action? (u=Use existing, p=Pull default, c=Specify custom) [u]: " base_action_input </dev/tty
  local base_action=${base_action_input:-u}

  case "$base_action" in
    p|P)
      echo "Pulling base image: $current_default_base_image_display" >&2
      if ! pull_image "$current_default_base_image_display"; then echo "Warning: Failed to pull base image." >&2; fi
      SELECTED_IMAGE_TAG="$current_default_base_image_display"
      ;;
    c|C)
      read -p "Enter full URL/tag of the custom base image: " custom_image </dev/tty
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

  # --- Step 3: Confirmation ---
  echo "Summary:"
  echo "  Registry: ${DOCKER_REGISTRY:-Docker Hub}, User: $DOCKER_USERNAME, Prefix: $DOCKER_REPO_PREFIX"
  echo "  Selected Stages: ${selected_folders_list:-None (will build none)}"
  echo "  Use Cache: $use_cache, Squash: $use_squash, Local Build Only: $skip_intermediate_push_pull, Use Builder: $use_builder"
  echo "  Base Image for First Stage: $SELECTED_IMAGE_TAG"
  if ! confirm_action "Proceed with build?" true; then
      echo "Build cancelled." >&2
      trap - EXIT TERM INT # Disable trap before returning
      rm -f "$PREFS_FILE"
      return 1 # Indicate cancellation
  fi

  # --- Save Preferences to File and .env ---
  update_env_variable "DOCKER_USERNAME" "$DOCKER_USERNAME"
  update_env_variable "DOCKER_REGISTRY" "$DOCKER_REGISTRY"
  update_env_variable "DOCKER_REPO_PREFIX" "$DOCKER_REPO_PREFIX"
  update_env_variable "DEFAULT_BASE_IMAGE" "$SELECTED_IMAGE_TAG" # Save selected as new default base

  {
    echo "export DOCKER_USERNAME=\"${DOCKER_USERNAME:-}\""
    echo "export DOCKER_REPO_PREFIX=\"${DOCKER_REPO_PREFIX:-}\""
    echo "export DOCKER_REGISTRY=\"${DOCKER_REGISTRY:-}\""
    echo "export use_cache=\"${use_cache:-n}\""
    echo "export use_squash=\"${use_squash:-n}\""
    echo "export skip_intermediate_push_pull=\"${skip_intermediate_push_pull:-n}\""
    echo "export use_builder=\"${use_builder:-y}\""
    echo "export SELECTED_BASE_IMAGE=\"${SELECTED_IMAGE_TAG:-}\""
    echo "export PLATFORM=\"${PLATFORM:-linux/arm64}\"" # Keep platform setting
    echo "export platform=\"${PLATFORM:-linux/arm64}\"" # Keep lowercase too
    echo "export SELECTED_FOLDERS_LIST=\"${selected_folders_list:-}\""
  } > "$PREFS_FILE"
  _log_debug "Build preferences saved to $PREFS_FILE"
  _log_debug "Exiting get_build_preferences_basic function successfully."
  trap - EXIT TERM INT # Disable trap before returning
  return 0 # Indicate success
}

# =========================================================================
# Run Preferences UI (Moved from jetcrun.sh)
# Arguments:
#   $1: Default image name
#   $2: Default X11 setting (on/off)
#   $3: Default GPU setting (on/off)
#   $4: Default Workspace setting (on/off)
#   $5: Default Root setting (on/off)
#   $@: Array of available image names (starting from index 6)
# Exports:
#   SELECTED_IMAGE: The chosen image name
#   SELECTED_X11: 'true' or 'false'
#   SELECTED_GPU: 'true' or 'false'
#   SELECTED_WS: 'true' or 'false'
#   SELECTED_ROOT: 'true' or 'false'
#   SAVE_CUSTOM_IMAGE: 'true' if a new custom image should be saved, else 'false'
#   CUSTOM_IMAGE_NAME: The name of the custom image if entered and SAVE_CUSTOM_IMAGE is true
# Returns: 0 on success, 1 on cancellation/error
# =========================================================================
get_run_preferences() {
  local default_image_name="${1:-}"
  local default_enable_x11="${2:-on}"
  local default_enable_gpu="${3:-on}"
  local default_mount_workspace="${4:-on}"
  local default_user_root="${5:-on}"
  shift 5 # Remove the first 5 arguments
  local available_images_array=("$@") # Remaining arguments are the image names

  _log_debug "Entering get_run_preferences function."
  _log_debug "Defaults: Img=$default_image_name, X11=$default_enable_x11, GPU=$default_enable_gpu, WS=$default_mount_workspace, Root=$default_user_root"
  _log_debug "Available images: ${available_images_array[*]}"

  # Initialize export variables
  export SELECTED_IMAGE=""
  export SELECTED_X11="false"
  export SELECTED_GPU="false"
  export SELECTED_WS="false"
  export SELECTED_ROOT="false"
  export SAVE_CUSTOM_IMAGE="false"
  export CUSTOM_IMAGE_NAME=""

  if ! _is_dialog_available; then
    _log_debug "Dialog not available. Falling back to basic run prompts."
    get_run_preferences_basic "$default_image_name" "$default_enable_x11" "$default_enable_gpu" "$default_mount_workspace" "$default_user_root" "${available_images_array[@]}"
    return $?
  fi
  _log_debug "Dialog available. Proceeding with dialog UI for run preferences."

  local temp_file temp_menu_file temp_custom_file
  temp_file=$(mktemp) || { echo "Failed to create temp file"; return 1; }
  temp_menu_file=$(mktemp) || { echo "Failed to create temp file"; rm -f "$temp_file"; return 1; }
  temp_custom_file=$(mktemp) || { echo "Failed to create temp file"; rm -f "$temp_file" "$temp_menu_file"; return 1; }

  _log_debug "Starting dialog subshell for run preferences..."
  (
    trap 'rm -f "$temp_file" "$temp_menu_file" "$temp_custom_file"' EXIT TERM INT

    local DIALOG_HEIGHT=20
    local DIALOG_WIDTH=80
    local LIST_HEIGHT=${#available_images_array[@]}
    [[ $LIST_HEIGHT -lt 4 ]] && LIST_HEIGHT=4 # Minimum height
    [[ $LIST_HEIGHT -gt 10 ]] && LIST_HEIGHT=10 # Maximum height

    local current_image_selection="$default_image_name"
    local final_image_list=("${available_images_array[@]}") # Copy array

    # --- Step 1: Image Selection ---
    if [ ${#final_image_list[@]} -gt 0 ]; then
      local menu_items=()
      local default_selected_tag=""
      for ((i=0; i<${#final_image_list[@]}; i++)); do
        local status="off"
        local tag="$((i+1))"
        if [[ "${final_image_list[$i]}" == "$current_image_selection" ]]; then
          status="on"
          default_selected_tag="$tag"
        fi
        menu_items+=("$tag" "${final_image_list[$i]}" "$status")
      done
      # Add custom option
      menu_items+=("custom" "Enter a custom image name" "off")

      # If no default was found, select the first item if list is not empty
      if [[ -z "$default_selected_tag" ]] && [[ ${#menu_items[@]} -gt 0 ]]; then
          menu_items[2]="on" # Set status of the first item to 'on'
          default_selected_tag="1"
          _log_debug "No default image match, selecting first item."
      fi

      dialog --backtitle "Jetson Container Run" \
        --title "Select Container Image" \
        --default-item "$default_selected_tag" \
        --radiolist "Choose an image or enter a custom one (use Space to select):" $DIALOG_HEIGHT $DIALOG_WIDTH $LIST_HEIGHT \
        "${menu_items[@]}" 2>"$temp_menu_file"

      local menu_exit_status=$?
      local selection_tag
      selection_tag=$(cat "$temp_menu_file")

      if [[ $menu_exit_status -ne 0 ]]; then
        echo "Image selection canceled (exit code: $menu_exit_status). Exiting." >&2
        exit 1 # Exit subshell with error
      fi

      if [[ "$selection_tag" == "custom" ]]; then
        dialog --backtitle "Jetson Container Run" \
          --title "Custom Container Image" \
          --inputbox "Enter container image name:" 8 $DIALOG_WIDTH \
          2>"$temp_custom_file"
        local custom_exit_status=$?
        local custom_image_name
        custom_image_name=$(cat "$temp_custom_file")

        if [[ $custom_exit_status -ne 0 ]]; then
          echo "Custom image entry canceled (exit code: $custom_exit_status). Exiting." >&2
          exit 1 # Exit subshell with error
        fi
        if [[ -z "$custom_image_name" ]]; then
            show_message "Error" "Custom image name cannot be empty." 10 $DIALOG_WIDTH
            exit 1 # Exit subshell with error
        fi
        current_image_selection="$custom_image_name"
        # Ask if user wants to save this custom image to the list for future runs
        if confirm_action "Add '$current_image_selection' to your saved images list in .env?" false 8 $DIALOG_WIDTH; then
            # Signal to the main script to save this image
            echo "SAVE_CUSTOM_IMAGE=true" >> "$temp_file" # Use temp file to pass back info
            echo "CUSTOM_IMAGE_NAME=$current_image_selection" >> "$temp_file"
        fi
      else
        # User selected an existing image via its tag (index+1)
        local selected_index=$((selection_tag - 1))
        if [[ "$selected_index" -ge 0 ]] && [[ "$selected_index" -lt ${#final_image_list[@]} ]]; then
            current_image_selection="${final_image_list[$selected_index]}"
            _log_debug "Selected image: $current_image_selection"
        else
            echo "Error: Invalid selection tag '$selection_tag'. Exiting." >&2
            exit 1 # Exit subshell with error
        fi
      fi
    else
      # No available images, directly prompt for image name
      dialog --backtitle "Jetson Container Run" \
        --title "Container Image" \
        --inputbox "No saved images found. Enter container image name:" 8 $DIALOG_WIDTH "$current_image_selection" \
        2>"$temp_custom_file"
      local input_exit_status=$?
      current_image_selection=$(cat "$temp_custom_file" | tr -d '\n')
      if [[ $input_exit_status -ne 0 ]]; then
        echo "Image input canceled (exit code: $input_exit_status). Exiting." >&2
        exit 1 # Exit subshell with error
      fi
       if [[ -z "$current_image_selection" ]]; then
            show_message "Error" "Image name cannot be empty." 10 $DIALOG_WIDTH
            exit 1 # Exit subshell with error
        fi
    fi

    # --- Step 2: Runtime Options ---
    local enable_x11="$default_enable_x11"
    local enable_gpu="$default_enable_gpu"
    local mount_workspace="$default_mount_workspace"
    local user_root="$default_user_root"

    dialog --backtitle "Jetson Container Run" \
      --title "Runtime Options" \
      --checklist "Select runtime options:" 12 $DIALOG_WIDTH 4 \
      "X11" "Enable X11 forwarding" "$enable_x11" \
      "GPU" "Enable all GPUs (--gpus all)" "$enable_gpu" \
      "WORKSPACE" "Mount /media/kkk:/workspace & jtop" "$mount_workspace" \
      "ROOT" "Run as root user (--user root)" "$user_root" \
      2>"$temp_file" # Overwrite temp_file with checklist results

    local checklist_exit_status=$?
     if [[ $checklist_exit_status -ne 0 ]]; then
        echo "Runtime options selection canceled (exit code: $checklist_exit_status). Exiting." >&2
        exit 1 # Exit subshell with error
      fi

    local checklist_results
    checklist_results=$(cat "$temp_file")

    # --- Save selections to temp file for export ---
    echo "SELECTED_IMAGE=$current_image_selection" >> "$temp_file"
    [[ "$checklist_results" == *'"X11"'* ]] && echo "SELECTED_X11=true" >> "$temp_file" || echo "SELECTED_X11=false" >> "$temp_file"
    [[ "$checklist_results" == *'"GPU"'* ]] && echo "SELECTED_GPU=true" >> "$temp_file" || echo "SELECTED_GPU=false" >> "$temp_file"
    [[ "$checklist_results" == *'"WORKSPACE"'* ]] && echo "SELECTED_WS=true" >> "$temp_file" || echo "SELECTED_WS=false" >> "$temp_file"
    [[ "$checklist_results" == *'"ROOT"'* ]] && echo "SELECTED_ROOT=true" >> "$temp_file" || echo "SELECTED_ROOT=false" >> "$temp_file"
    # SAVE_CUSTOM_IMAGE and CUSTOM_IMAGE_NAME were potentially added earlier

    _log_debug "Dialog subshell for run preferences finished successfully."
    exit 0 # Exit subshell successfully
  )
  local subshell_exit_code=$?
  _log_debug "Dialog subshell for run preferences exited with code: $subshell_exit_code"

  # Process results from temp file if subshell succeeded
  if [[ $subshell_exit_code -eq 0 ]] && [[ -f "$temp_file" ]]; then
    # Source the temp file to export variables back to the main script's scope
    # shellcheck disable=SC1090
    source "$temp_file"
    _log_debug "Sourced run preferences from temp file."
    _log_debug "Exported: IMAGE=$SELECTED_IMAGE, X11=$SELECTED_X11, GPU=$SELECTED_GPU, WS=$SELECTED_WS, ROOT=$SELECTED_ROOT, SAVE_CUSTOM=$SAVE_CUSTOM_IMAGE, CUSTOM_NAME=$CUSTOM_IMAGE_NAME"
  fi

  # Clean up temp files
  rm -f "$temp_file" "$temp_menu_file" "$temp_custom_file"
  _log_debug "Cleaned up run preference temp files."

  # Return the exit code of the subshell
  return $subshell_exit_code
}

get_run_preferences_basic() {
  local default_image_name="${1:-}"
  local default_enable_x11="${2:-on}"
  local default_enable_gpu="${3:-on}"
  local default_mount_workspace="${4:-on}"
  local default_user_root="${5:-on}"
  shift 5
  local available_images_array=("$@")

  _log_debug "Entering get_run_preferences_basic function."

  local current_image_selection="$default_image_name"
  local final_image_list=("${available_images_array[@]}")

  # --- Step 1: Image Selection ---
  if [ ${#final_image_list[@]} -gt 0 ]; then
    echo "Available container images:"
    local default_choice_num=""
    for ((i=0; i<${#final_image_list[@]}; i++)); do
      echo "[$((i+1))] ${final_image_list[$i]}"
      if [[ "${final_image_list[$i]}" == "$current_image_selection" ]]; then
        default_choice_num="$((i+1))"
      fi
    done
    echo "[c] Enter a custom image name"

    local prompt_default="c"
    if [[ -n "$default_choice_num" ]]; then
        prompt_default="$default_choice_num"
    elif [[ ${#final_image_list[@]} -gt 0 ]]; then
        prompt_default="1" # Default to first item if current not found
    fi

    read -p "Select an option [1-${#final_image_list[@]}/c] (default: $prompt_default): " img_choice </dev/tty
    img_choice=${img_choice:-$prompt_default}

    if [[ "$img_choice" == "c" ]]; then
      read -p "Enter the container image name: " custom_image_name </dev/tty
      if [[ -z "$custom_image_name" ]]; then
          echo "Error: Custom image name cannot be empty." >&2
          return 1 # Error
      fi
      current_image_selection="$custom_image_name"
      if confirm_action "Add '$current_image_selection' to your saved images list?" false; then
        export SAVE_CUSTOM_IMAGE="true"
        export CUSTOM_IMAGE_NAME="$current_image_selection"
      fi
    elif [[ "$img_choice" =~ ^[0-9]+$ ]] && [ "$img_choice" -ge 1 ] && [ "$img_choice" -le ${#final_image_list[@]} ]; then
      current_image_selection="${final_image_list[$((img_choice-1))]}"
      _log_debug "Selected image: $current_image_selection"
    else
      echo "Invalid selection '$img_choice'. Exiting." >&2
      return 1 # Error
    fi
  else
    # No images in list, prompt directly
    read -p "No saved images found. Enter the container image name: " current_image_selection </dev/tty
     if [[ -z "$current_image_selection" ]]; then
        echo "Error: Image name cannot be empty." >&2
        return 1 # Error
    fi
  fi
  export SELECTED_IMAGE="$current_image_selection"
  echo "Selected image: $SELECTED_IMAGE"
  echo "-------------------------"

  # --- Step 2: Runtime Options ---
  local x11_prompt="y" gpu_prompt="y" ws_prompt="y" root_prompt="y"
  [[ "$default_enable_x11" == "off" ]] && x11_prompt="n"
  [[ "$default_enable_gpu" == "off" ]] && gpu_prompt="n"
  [[ "$default_mount_workspace" == "off" ]] && ws_prompt="n"
  [[ "$default_user_root" == "off" ]] && root_prompt="n"

  read -p "Enable X11 forwarding? (y/n) [$x11_prompt]: " x11 </dev/tty; x11=${x11:-$x11_prompt}
  read -p "Enable all GPUs? (y/n) [$gpu_prompt]: " gpu </dev/tty; gpu=${gpu:-$gpu_prompt}
  read -p "Mount /media/kkk:/workspace & jtop? (y/n) [$ws_prompt]: " ws </dev/tty; ws=${ws:-$ws_prompt}
  read -p "Run as root user? (y/n) [$root_prompt]: " root </dev/tty; root=${root:-$root_prompt}

  [[ "$x11" =~ ^[Yy]$ ]] && export SELECTED_X11="true" || export SELECTED_X11="false"
  [[ "$gpu" =~ ^[Yy]$ ]] && export SELECTED_GPU="true" || export SELECTED_GPU="false"
  [[ "$ws" =~ ^[Yy]$ ]] && export SELECTED_WS="true" || export SELECTED_WS="false"
  [[ "$root" =~ ^[Yy]$ ]] && export SELECTED_ROOT="true" || export SELECTED_ROOT="false"

  _log_debug "Basic run prompts finished successfully."
  _log_debug "Exported: IMAGE=$SELECTED_IMAGE, X11=$SELECTED_X11, GPU=$SELECTED_GPU, WS=$SELECTED_WS, ROOT=$SELECTED_ROOT, SAVE_CUSTOM=$SAVE_CUSTOM_IMAGE, CUSTOM_NAME=$CUSTOM_IMAGE_NAME"
  return 0 # Success
}

# =========================================================================
# Post Build Menu UI (Moved from post_build_menu.sh)
# Arguments: $1 = image tag
# Returns: Exit status of the chosen action (e.g., docker run) or 0 if skipped/cancelled
# =========================================================================
show_post_build_menu() {
  local image_tag=$1
  echo "--------------------------------------------------" >&2
  echo "Final Image Built: $image_tag" >&2
  echo "--------------------------------------------------" >&2
  if ! verify_image_exists "$image_tag"; then # Use docker_helper function
    show_message "Error" "Final image $image_tag not found locally, cannot proceed with post-build actions."
    return 1
  fi

  if _is_dialog_available; then
    local temp_file
    temp_file=$(mktemp) || { echo "Failed to create temp file"; return 1; }
    trap 'rm -f "$temp_file"' RETURN # Clean up on return

    local HEIGHT=20 WIDTH=70 LIST_HEIGHT=6
    local TITLE="Post-Build Operations"
    local TEXT="Select an action for image: $image_tag"
    local OPTIONS=(
      "shell"      "Start an interactive shell"                   "off"
      "verify"     "Run quick verification (common tools)"        "on" # Default ON
      "full"       "Run full verification (all packages)"         "off"
      "list"       "List installed apps in the container"         "off"
      "skip"       "Skip (do nothing)"                            "off"
    )
    dialog --clear \
           --backtitle "Docker Image Operations" \
           --title "$TITLE" \
           --default-item "verify" \
           --radiolist "$TEXT" $HEIGHT $WIDTH $LIST_HEIGHT \
           "${OPTIONS[@]}" \
           2>"$temp_file"
    local exit_status=$?
    local selection
    selection=$(cat "$temp_file")
    rm -f "$temp_file" # Clean up immediately
    clear # Clear dialog remnants

    if [ $exit_status -ne 0 ]; then
      echo "Operation cancelled." >&2
      return 0 # Treat cancel as skip
    fi

    case "$selection" in
      "shell")
        echo "Starting interactive shell for $image_tag..." >&2
        # Use run_container from docker_helpers? Or simpler direct run? Direct run is fine here.
        docker run -it --rm --gpus all "$image_tag" bash
        return $?
        ;;
      "verify")
        verify_container_apps "$image_tag" "quick" # Use verification helper
        return $?
        ;;
      "full")
        verify_container_apps "$image_tag" "all" # Use verification helper
        return $?
        ;;
      "list")
        list_installed_apps "$image_tag" # Use verification helper
        return $?
        ;;
      "skip"|"")
        echo "Skipping post-build container action." >&2
        return 0
        ;;
      *)
        show_message "Error" "Invalid choice '$selection'. Skipping container action."
        return 0
        ;;
    esac
  else
    # Text-based menu
    echo "--------------------------------------------------"
    echo "Post-Build Options for Image: $image_tag"
    echo "--------------------------------------------------"
    echo "1) Start an interactive shell"
    echo "2) Run quick verification (common tools and packages)"
    echo "3) Run full verification (all system packages, may be verbose)"
    echo "4) List installed apps in the container"
    echo "5) Skip (do nothing)"
    read -p "Enter your choice [1-5, default: 2]: " user_choice </dev/tty
    user_choice=${user_choice:-2}
    case "$user_choice" in
      1)
        echo "Starting interactive shell for $image_tag..." >&2
        docker run -it --rm --gpus all "$image_tag" bash
        return $?
        ;;
      2)
        verify_container_apps "$image_tag" "quick"
        return $?
        ;;
      3)
        verify_container_apps "$image_tag" "all"
        return $?
        ;;
      4)
        list_installed_apps "$image_tag"
        return $?
        ;;
      5)
        echo "Skipping post-build container action." >&2
        return 0
        ;;
      *)
        echo "Invalid choice '$user_choice'. Skipping container action." >&2
        return 0
        ;;
    esac
  fi
}


# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── interactive_ui.sh  <- THIS FILE (Renamed from dialog_ui.sh)
# └── ...                        <- Other project files
#
# Description: Interactive UI functions (Dialog/Text) for build/run preferences and post-build actions.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20240806-103000-MODULAR
