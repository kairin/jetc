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
# Source logging functions if available
# shellcheck disable=SC1091
source "$SCRIPT_DIR_IUI/env_setup.sh" 2>/dev/null || true

# =========================================================================
# Generic UI Functions (Dialog with Text Fallback)
# =========================================================================

# Check dialog availability (uses function from utils.sh)
_is_dialog_available() {
  log_debug "Checking dialog availability via check_install_dialog"
  check_install_dialog >/dev/null 2>&1
}

# Show a message box or print to console
show_message() {
  local title="${1:-Message}"
  local message="${2:-}"
  local height=${3:-8}
  local width=${4:-60}
  log_debug "Showing message: Title='$title', Message='$message'"

  if _is_dialog_available; then
    dialog --backtitle "Jetson Container System" --title "$title" --msgbox "$message" "$height" "$width"
  else
    echo "----------------------------------------" >&2 # Output to stderr
    echo "$title:" >&2
    echo "$message" >&2
    echo "----------------------------------------" >&2
    read -p "Press Enter to continue..." </dev/tty # Ensure prompt waits for user
  fi
}

# Ask a yes/no question, returns 0 for Yes, 1 for No/Cancel
confirm_action() {
  local question="${1:-Are you sure?}"
  local default_yes=${2:-true} # Default to Yes
  local height=${3:-8}
  local width=${4:-60}
  log_debug "Confirming action: Question='$question', DefaultYes=$default_yes"

  if _is_dialog_available; then
    local default_opt=""
    [[ "$default_yes" == "true" ]] && default_opt="--defaultno" # Inverted logic for dialog's default button focus
    
    dialog --backtitle "Jetson Container System" --title "Confirmation" --yesno "$question" "$height" "$width" $default_opt
    local exit_code=$?
    log_debug "Dialog confirm_action exit code: $exit_code" # 0=Yes, 1=No, 255=Esc
    # Map Esc (255) to No (1)
    [[ $exit_code -eq 255 ]] && return 1
    return $exit_code
  else
    local prompt_opts="y/N"
    local default_ans="n"
    if [[ "$default_yes" == "true" ]]; then
        prompt_opts="Y/n"
        default_ans="y"
    fi
    # Ensure prompt goes to stderr, read from tty
    echo -n "$question [$prompt_opts]: " >&2
    read answer </dev/tty
    answer=${answer:-$default_ans}
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      log_debug "Text confirm_action result: Yes"
      return 0 # Yes
    else
      log_debug "Text confirm_action result: No"
      return 1 # No or anything else
    fi
  fi
}

# =========================================================================
# Build Preferences UI (Moved from dialog_ui.sh)
# =========================================================================
get_build_preferences() {
  log_debug "Entering get_build_preferences function."
  # Always load .env before presenting dialogs/prompts
  load_env_variables

  log_debug "Checking dialog availability..."
  if ! _is_dialog_available; then
    log_warning "Dialog not available. Falling back to basic text prompts." # Use log_warning
    get_build_preferences_basic
    return $?
  fi
  log_debug "Dialog available. Proceeding with dialog UI."

  local PREFS_FILE="/tmp/build_prefs.sh" # Ensure this matches build_ui.sh/build.sh
  local temp_options temp_base_choice temp_custom_image temp_docker_info temp_folders
  temp_options=$(mktemp) || { log_error "Failed to create temp file for options"; return 1; }
  temp_base_choice=$(mktemp) || { log_error "Failed to create temp file for base choice"; rm -f "$temp_options"; return 1; }
  temp_custom_image=$(mktemp) || { log_error "Failed to create temp file for custom image"; rm -f "$temp_options" "$temp_base_choice"; return 1; }
  temp_docker_info=$(mktemp) || { log_error "Failed to create temp file for docker info"; rm -f "$temp_options" "$temp_base_choice" "$temp_custom_image"; return 1; }
  temp_folders=$(mktemp) || { log_error "Failed to create temp file for folders"; rm -f "$temp_options" "$temp_base_choice" "$temp_custom_image" "$temp_docker_info"; return 1; }

  log_debug "Starting dialog subshell for build preferences..."
  (
    # Subshell inherits functions and sourced files
    trap 'rm -f "$temp_options" "$temp_base_choice" "$temp_custom_image" "$temp_docker_info" "$temp_folders"' EXIT TERM INT

    # Define minimal logging for subshell if needed (or rely on inherited)
    _log_debug_sub() { if [[ "${JETC_DEBUG}" == "true" || "${JETC_DEBUG}" == "1" ]]; then echo "[DEBUG SUB] $(date '+%Y-%m-%d %H:%M:%S') - ${FUNCNAME[1]}: $1" >&2; fi; }

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
      _log_debug_sub "Displaying Docker Info form."
      dialog --backtitle "Docker Build Configuration" \
             --title "Step 0: Docker Information" \
             --ok-label "Next: Select Stages" \
             --cancel-label "Exit Build" \
             --form "Confirm or edit Docker details (loaded from .env):" $DIALOG_HEIGHT $DIALOG_WIDTH $FORM_HEIGHT \
             "Registry (optional, empty=Docker Hub):" 1 1 "$temp_registry"     1 40 70 0 \
             "Username (required):"                   2 1 "$temp_username"    2 40 70 0 \
             "Repository Prefix (required):"          3 1 "$temp_prefix" 3 40 70 0 \
             2>"$temp_docker_info" # Capture form output to temp file

      local form_exit_status=$?
      _log_debug_sub "Docker Info form exit status: $form_exit_status"
      if [ $form_exit_status -ne 0 ]; then
        _log_debug_sub "Docker information entry canceled. Exiting subshell."
        exit 1 # Exit subshell with error
      fi

      mapfile -t lines < "$temp_docker_info"
      while [ "${#lines[@]}" -lt 3 ]; do lines+=(""); done
      temp_registry="$(echo -n "${lines[0]}" | tr -d '\r\n')"
      temp_username="$(echo -n "${lines[1]}" | tr -d '\r\n')"
      temp_prefix="$(echo -n "${lines[2]}" | tr -d '\r\n')"
      _log_debug_sub "Read Docker Info: Reg='$temp_registry', User='$temp_username', Prefix='$temp_prefix'"

      if [[ -z "$temp_username" || -z "$temp_prefix" ]]; then
        _log_debug_sub "Validation failed: Username or Prefix empty."
        # Use inherited show_message
        show_message "Validation Error" "Username and Repository Prefix are required.\\nPlease correct the entries." 10 $DIALOG_WIDTH
        continue
      fi

      DOCKER_REGISTRY="$temp_registry"
      DOCKER_USERNAME="$temp_username"
      DOCKER_REPO_PREFIX="$temp_prefix"
      export DOCKER_REGISTRY DOCKER_USERNAME DOCKER_REPO_PREFIX # Export for potential use within subshell if needed
      _log_debug_sub "Docker Info validated and exported."
      break
    done

    # --- Step 0.5: Select Build Stages ---
    local build_dir="$SCRIPT_DIR_IUI/../build"
    local folder_checklist_items=()
    local numbered_folders=()
    local folder_count=0
    _log_debug_sub "Looking for build stages in $build_dir"
    if [ -d "$build_dir" ]; then
        mapfile -t numbered_folders < <(find "$build_dir" -maxdepth 1 -mindepth 1 -type d -name '[0-9]*-*' | sort)
        _log_debug_sub "Found ${#numbered_folders[@]} potential stages."
        for folder_path in "${numbered_folders[@]}"; do
            folder_name=$(basename "$folder_path")
            folder_checklist_items+=("$folder_name" "$folder_name" "on") # Default to ON
            ((folder_count++))
        done
    fi

    local selected_folders_list=""
    if [[ $folder_count -gt 0 ]]; then
        _log_debug_sub "Displaying Build Stages checklist."
        dialog --backtitle "Docker Build Configuration" \
               --title "Step 0.5: Select Build Stages" \
               --ok-label "Next: Build Options" \
               --cancel-label "Exit Build" \
               --checklist "Select the build stages (folders) to include (Spacebar to toggle):" $DIALOG_HEIGHT $DIALOG_WIDTH $FOLDER_LIST_HEIGHT \
               "${folder_checklist_items[@]}" \
               2>"$temp_folders" # Capture checklist output
        local folders_exit_status=$?
        _log_debug_sub "Build Stages checklist exit status: $folders_exit_status"
        if [ $folders_exit_status -ne 0 ]; then
            _log_debug_sub "Folder selection canceled. Exiting subshell."
            exit 1 # Exit subshell with error
        fi
        selected_folders_list=$(cat "$temp_folders" | sed 's/"//g')
        _log_debug_sub "Selected folders list: '$selected_folders_list'"
    else
        _log_debug_sub "No numbered build folders found or selected."
        selected_folders_list="" # No folders found or selected
    fi

    # --- Step 1: Build Options ---
    local use_cache="n" # Default OFF
    local use_squash="n" # Default OFF
    local skip_intermediate_push_pull="y" # Default ON (local build)
    local use_builder="y" # Default ON
    _log_debug_sub "Displaying Build Options checklist."

    dialog --backtitle "Docker Build Configuration" \
           --title "Step 1: Build Options" \
           --ok-label "Next: Base Image" \
           --cancel-label "Exit Build" \
           --checklist "Use Spacebar to toggle options, Enter to confirm:" $DIALOG_HEIGHT $DIALOG_WIDTH $CHECKLIST_HEIGHT \
           "cache"         "Use Build Cache (Faster, uses previous layers)"        "$([ "$use_cache" == "y" ] && echo "on" || echo "off")" \
           "squash"        "Squash Layers (Smaller final image, experimental)"     "$([ "$use_squash" == "y" ] && echo "on" || echo "off")" \
           "local_build"   "Build Locally Only (Faster, no registry push/pull)"    "$([ "$skip_intermediate_push_pull" == "y" ] && echo "on" || echo "off")" \
           "use_builder"   "Use Optimized Jetson Builder (Recommended)"            "$([ "$use_builder" == "y" ] && echo "on" || echo "off")" \
            2>"$temp_options" # Capture checklist output

    local checklist_exit_status=$?
    _log_debug_sub "Build Options checklist exit status: $checklist_exit_status"
    if [ $checklist_exit_status -ne 0 ]; then
      _log_debug_sub "Build options selection canceled. Exiting subshell."
      exit 1 # Exit subshell with error
    fi
    local selected_options
    selected_options=$(cat "$temp_options")
    _log_debug_sub "Selected build options raw: '$selected_options'"
    [[ "$selected_options" == *'"cache"'* ]] && use_cache="y" || use_cache="n"
    [[ "$selected_options" == *'"squash"'* ]] && use_squash="y" || use_squash="n"
    [[ "$selected_options" == *'"local_build"'* ]] && skip_intermediate_push_pull="y" || skip_intermediate_push_pull="n"
    [[ "$selected_options" == *'"use_builder"'* ]] && use_builder="y" || use_builder="n"
    _log_debug_sub "Parsed build options: Cache=$use_cache, Squash=$use_squash, Local=$skip_intermediate_push_pull, Builder=$use_builder"

    # --- Step 2: Base Image Selection ---
    local current_default_base_image_display="$DEFAULT_BASE_IMAGE" # From loaded .env
    local SELECTED_IMAGE_TAG="$DEFAULT_BASE_IMAGE" # Initialize
    local BASE_IMAGE_ACTION="use_default" # Default action
    _log_debug_sub "Displaying Base Image Selection radiolist. Default: $current_default_base_image_display"

    local MENU_HEIGHT=4
    dialog --backtitle "Docker Build Configuration" \
           --title "Step 2: Base Image Selection" \
           --ok-label "Confirm Choice" \
           --cancel-label "Exit Build" \
           --radiolist "Choose the base image for the *first* build stage:" $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
           "use_default"    "Use Default (if locally available): $current_default_base_image_display"  "on" \
           "pull_default"   "Pull Default Image Now: $current_default_base_image_display"             "off" \
           "specify_custom" "Specify Custom Image (will attempt pull)"                "off" \
           2>"$temp_base_choice" # Capture radiolist output

    local menu_exit_status=$?
    _log_debug_sub "Base Image Selection radiolist exit status: $menu_exit_status"
    if [ $menu_exit_status -ne 0 ]; then
      _log_debug_sub "Base image selection canceled. Exiting subshell."
      exit 1 # Exit subshell with error
    fi
    BASE_IMAGE_ACTION=$(cat "$temp_base_choice")
    _log_debug_sub "Selected base image action: $BASE_IMAGE_ACTION"

    case "$BASE_IMAGE_ACTION" in
      "specify_custom")
        _log_debug_sub "Displaying Custom Base Image inputbox."
        dialog --backtitle "Docker Build Configuration" \
               --title "Step 2a: Custom Base Image" \
               --ok-label "Confirm Image" \
               --cancel-label "Exit Build" \
               --inputbox "Enter the full Docker image tag (e.g., user/repo:tag):" 10 $DIALOG_WIDTH "$current_default_base_image_display" \
               2>"$temp_custom_image" # Capture inputbox output
        local input_exit_status=$?
        _log_debug_sub "Custom Base Image inputbox exit status: $input_exit_status"
        if [ $input_exit_status -ne 0 ]; then
          _log_debug_sub "Custom base image input canceled. Exiting subshell."
          exit 1 # Exit subshell with error
        fi
        local entered_image
        entered_image=$(cat "$temp_custom_image")
        _log_debug_sub "Entered custom image: '$entered_image'"
        if [ -z "$entered_image" ]; then
          _log_debug_sub "No custom image entered, reverting to default."
          show_message "Info" "No custom image entered. Reverting to default:\\n$current_default_base_image_display" 8 $DIALOG_WIDTH
          SELECTED_IMAGE_TAG="$current_default_base_image_display"
          BASE_IMAGE_ACTION="use_default"
        else
          SELECTED_IMAGE_TAG="$entered_image"
          _log_debug_sub "Attempting to pull custom base image: $SELECTED_IMAGE_TAG"
          show_message "Info" "Attempting to pull custom base image:\\n$SELECTED_IMAGE_TAG..." 5 $DIALOG_WIDTH # Use infobox style if possible, msgbox is fine
          # Use inherited pull_image
          if ! pull_image "$SELECTED_IMAGE_TAG"; then
            _log_debug_sub "Failed to pull custom image $SELECTED_IMAGE_TAG"
            # Use inherited confirm_action
            if confirm_action "Failed to pull custom base image:\\n$SELECTED_IMAGE_TAG.\\nBuild might fail if not local.\\n\\nContinue anyway?" false 12 $DIALOG_WIDTH; then
              _log_debug_sub "User chose to continue despite failed pull."
              show_message "Warning" "Custom image not pulled. Using local if available." 8 $DIALOG_WIDTH
            else
              _log_debug_sub "User chose to exit after failed custom pull."
              exit 1 # Exit subshell with error
            fi
          else
            _log_debug_sub "Successfully pulled custom image $SELECTED_IMAGE_TAG"
            show_message "Success" "Successfully pulled custom base image:\\n$SELECTED_IMAGE_TAG" 8 $DIALOG_WIDTH
          fi
        fi
        ;;
      "pull_default")
        _log_debug_sub "Attempting to pull default base image: $current_default_base_image_display"
        show_message "Info" "Attempting to pull default base image:\\n$current_default_base_image_display..." 5 $DIALOG_WIDTH
        if ! pull_image "$current_default_base_image_display"; then # Use docker_helper function
           _log_debug_sub "Failed to pull default image $current_default_base_image_display"
           if confirm_action "Failed to pull default base image:\\n$current_default_base_image_display.\\nBuild might fail if not local.\\n\\nContinue anyway?" false 12 $DIALOG_WIDTH; then
              _log_debug_sub "User chose to continue despite failed pull."
              show_message "Warning" "Default image not pulled. Using local if available." 8 $DIALOG_WIDTH
           else
              _log_debug_sub "User chose to exit after failed default pull."
              exit 1 # Exit subshell with error
           fi
        else
          _log_debug_sub "Successfully pulled default image $current_default_base_image_display"
          show_message "Success" "Successfully pulled default base image:\\n$current_default_base_image_display" 8 $DIALOG_WIDTH
        fi
        SELECTED_IMAGE_TAG="$current_default_base_image_display"
        ;;
      "use_default")
        _log_debug_sub "Using default base image (local if available): $current_default_base_image_display"
        SELECTED_IMAGE_TAG="$current_default_base_image_display"
        show_message "Info" "Using default base image (local version if available):\\n$SELECTED_IMAGE_TAG" 8 $DIALOG_WIDTH
        ;;
      *)
        _log_debug_sub "Invalid base image action selected: '$BASE_IMAGE_ACTION'. Exiting."
        exit 1 # Exit subshell with error
        ;;
    esac
    _log_debug_sub "Final selected base image tag: $SELECTED_IMAGE_TAG"

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
    _log_debug_sub "Displaying confirmation dialog."

    if ! confirm_action "$confirmation_message\\n\\nProceed with build?" true 25 $DIALOG_WIDTH; then
        _log_debug_sub "Build canceled by user at confirmation screen. Exiting subshell."
        exit 1 # Exit subshell with error
    fi
    _log_debug_sub "User confirmed build."

    # --- Save Preferences to File and .env ---
    # Update .env first (using function from env_helpers.sh)
    _log_debug_sub "Updating .env with Docker info and selected base image."
    update_env_variable "DOCKER_USERNAME" "$DOCKER_USERNAME"
    update_env_variable "DOCKER_REGISTRY" "$DOCKER_REGISTRY"
    update_env_variable "DOCKER_REPO_PREFIX" "$DOCKER_REPO_PREFIX"
    update_env_variable "DEFAULT_BASE_IMAGE" "$SELECTED_IMAGE_TAG" # Save selected as new default base
    # Note: We don't save build options like cache/squash/load to .env by default

    # Export selections to the preferences file for the current build run
    _log_debug_sub "Saving preferences to $PREFS_FILE"
    {
      echo "export DOCKER_USERNAME=\"${DOCKER_USERNAME:-}\""
      echo "export DOCKER_REPO_PREFIX=\"${DOCKER_REPO_PREFIX:-}\""
      echo "export DOCKER_REGISTRY=\"${DOCKER_REGISTRY:-}\""
      echo "export use_cache=\"${use_cache:-n}\""
      echo "export use_squash=\"${use_squash:-n}\""
      echo "export skip_intermediate_push_pull=\"${skip_intermediate_push_pull:-y}\"" # Corrected default
      echo "export use_builder=\"${use_builder:-y}\""
      echo "export SELECTED_BASE_IMAGE=\"${SELECTED_IMAGE_TAG:-}\""
      echo "export PLATFORM=\"${PLATFORM:-linux/arm64}\"" # Keep platform setting
      echo "export platform=\"${PLATFORM:-linux/arm64}\"" # Keep lowercase too
      echo "export SELECTED_FOLDERS_LIST=\"${selected_folders_list:-}\""
    } > "$PREFS_FILE"
    _log_debug_sub "Build preferences saved to $PREFS_FILE"
    _log_debug_sub "Dialog subshell finished successfully."
    exit 0 # Exit subshell successfully
  )
  local subshell_exit_code=$?
  log_debug "Dialog subshell for build preferences exited with code: $subshell_exit_code"
  # Clean up temp files regardless of subshell exit code
  rm -f "$temp_options" "$temp_base_choice" "$temp_custom_image" "$temp_docker_info" "$temp_folders"
  log_debug "Cleaned up build preference temp files."

  return $subshell_exit_code
}

get_build_preferences_basic() {
  log_debug "Entering get_build_preferences_basic function."
  # Always load .env before presenting prompts
  load_env_variables

  local PREFS_FILE="/tmp/build_prefs.sh" # Ensure this matches build_ui.sh/build.sh
  trap 'rm -f "$PREFS_FILE"' EXIT TERM INT # Ensure cleanup on exit

  local temp_registry="$DOCKER_REGISTRY"
  local temp_username="$DOCKER_USERNAME"
  local temp_prefix="$DOCKER_REPO_PREFIX"

  # --- Step 0: Docker Info ---
  # Use stderr for prompts
  echo -n "Docker Registry (leave empty for Docker Hub) [$temp_registry]: " >&2
  read input_registry </dev/tty
  temp_registry=${input_registry:-$temp_registry}

  while true; do
    echo -n "Docker Username (required) [$temp_username]: " >&2
    read input_username </dev/tty
    temp_username=${input_username:-$temp_username}
    if [[ -n "$temp_username" ]]; then break; else echo "Username cannot be empty." >&2; fi
  done

  while true; do
    echo -n "Docker Repo Prefix (required) [$temp_prefix]: " >&2
    read input_prefix </dev/tty
    temp_prefix=${input_prefix:-$temp_prefix}
    if [[ -n "$temp_prefix" ]]; then break; else echo "Repo Prefix cannot be empty." >&2; fi
  done
  DOCKER_REGISTRY="$temp_registry"
  DOCKER_USERNAME="$temp_username"
  DOCKER_REPO_PREFIX="$temp_prefix"
  log_info "Using Registry: ${DOCKER_REGISTRY:-Docker Hub}, User: $DOCKER_USERNAME, Prefix: $DOCKER_REPO_PREFIX"
  echo "-------------------------" >&2

  # --- Step 0.5: Select Build Stages ---
  local build_dir="$SCRIPT_DIR_IUI/../build"
  local numbered_folders=()
  local selected_folders_list=""
  local folder_options=()
  local folder_count=0
  log_debug "Looking for build stages in $build_dir"

  if [ -d "$build_dir" ]; then
      mapfile -t numbered_folders < <(find "$build_dir" -maxdepth 1 -mindepth 1 -type d -name '[0-9]*-*' | sort)
      if [[ ${#numbered_folders[@]} -gt 0 ]]; then
          log_debug "Found ${#numbered_folders[@]} potential stages."
          echo "Available build stages (folders):" >&2
          for i in "${!numbered_folders[@]}"; do
              folder_name=$(basename "${numbered_folders[$i]}")
              echo "  $((i+1))) $folder_name" >&2
              folder_options+=("$folder_name")
              ((folder_count++))
          done
          echo -n "Enter numbers of stages to build (e.g., '1 3 4'), or leave empty for ALL: " >&2
          read selection_input </dev/tty
          if [[ -z "$selection_input" ]]; then
              selected_folders_list="${folder_options[*]}"
              log_info "Building ALL stages."
          else
              local temp_selected=()
              for num in $selection_input; do
                  if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= folder_count )); then
                      temp_selected+=("${folder_options[$((num-1))]}")
                  else
                      log_warning "Invalid selection '$num' ignored."
                  fi
              done
              selected_folders_list="${temp_selected[*]}"
          fi
      else
          log_warning "No numbered build folders found in $build_dir."
      fi
  else
      log_error "Build directory $build_dir not found."
  fi
  log_info "Selected stages: ${selected_folders_list:-None}"
  echo "-------------------------" >&2

  # --- Step 1: Build Options ---
  local use_cache="n" use_squash="n" skip_intermediate_push_pull="y" use_builder="y"

  echo -n "Use build cache? (y/n) [n]: " >&2; read use_cache_input </dev/tty; use_cache=${use_cache_input:-n}
  while [[ "$use_cache" != "y" && "$use_cache" != "n" ]]; do echo -n "Invalid. Use cache? (y/n) [n]: " >&2; read use_cache_input </dev/tty; use_cache=${use_cache_input:-n}; done

  echo -n "Squash layers (experimental)? (y/n) [n]: " >&2; read use_squash_input </dev/tty; use_squash=${use_squash_input:-n}
  while [[ "$use_squash" != "y" && "$use_squash" != "n" ]]; do echo -n "Invalid. Squash? (y/n) [n]: " >&2; read use_squash_input </dev/tty; use_squash=${use_squash_input:-n}; done

  echo -n "Build locally only (skip push/pull)? (y/n) [y]: " >&2; read skip_intermediate_input </dev/tty; skip_intermediate_push_pull=${skip_intermediate_input:-y}
   while [[ "$skip_intermediate_push_pull" != "y" && "$skip_intermediate_push_pull" != "n" ]]; do echo -n "Invalid. Local build? (y/n) [y]: " >&2; read skip_intermediate_input </dev/tty; skip_intermediate_push_pull=${skip_intermediate_input:-y}; done

  echo -n "Use Optimized Jetson Builder? (y/n) [y]: " >&2; read use_builder_input </dev/tty; use_builder=${use_builder_input:-y}
  while [[ "$use_builder" != "y" && "$use_builder" != "n" ]]; do echo -n "Invalid. Use builder? (y/n) [y]: " >&2; read use_builder_input </dev/tty; use_builder=${use_builder_input:-y}; done
  log_debug "Parsed build options: Cache=$use_cache, Squash=$use_squash, Local=$skip_intermediate_push_pull, Builder=$use_builder"
  echo "-------------------------" >&2

  # --- Step 2: Base Image Selection ---
  local current_default_base_image_display="$DEFAULT_BASE_IMAGE" # From loaded .env
  local SELECTED_IMAGE_TAG="$DEFAULT_BASE_IMAGE" # Initialize
  log_debug "Default base image: $current_default_base_image_display"

  echo "Default base image: $current_default_base_image_display" >&2
  echo -n "Action? (u=Use existing, p=Pull default, c=Specify custom) [u]: " >&2
  read base_action_input </dev/tty
  local base_action=${base_action_input:-u}
  log_debug "Selected base image action: $base_action"

  case "$base_action" in
    p|P)
      log_info "Pulling base image: $current_default_base_image_display"
      if ! pull_image "$current_default_base_image_display"; then log_warning "Failed to pull base image."; fi
      SELECTED_IMAGE_TAG="$current_default_base_image_display"
      ;;
    c|C)
      echo -n "Enter full URL/tag of the custom base image: " >&2
      read custom_image </dev/tty
      if [ -z "$custom_image" ]; then
        log_warning "No image specified, using default: $current_default_base_image_display"
        SELECTED_IMAGE_TAG="$current_default_base_image_display"
      else
        SELECTED_IMAGE_TAG="$custom_image"
        log_info "Attempting to pull custom base image: $SELECTED_IMAGE_TAG"
         if ! pull_image "$SELECTED_IMAGE_TAG"; then log_warning "Failed to pull custom base image."; fi
      fi
      ;;
    *) # Includes 'u' or invalid input
      log_info "Using existing base image (no pull): $current_default_base_image_display"
      SELECTED_IMAGE_TAG="$current_default_base_image_display"
      ;;
  esac
  log_debug "Final selected base image tag: $SELECTED_IMAGE_TAG"
  echo "-------------------------" >&2

  # --- Step 3: Confirmation ---
  echo "Summary:" >&2
  echo "  Registry: ${DOCKER_REGISTRY:-Docker Hub}, User: $DOCKER_USERNAME, Prefix: $DOCKER_REPO_PREFIX" >&2
  echo "  Selected Stages: ${selected_folders_list:-None (will build none)}" >&2
  echo "  Use Cache: $use_cache, Squash: $use_squash, Local Build Only: $skip_intermediate_push_pull, Use Builder: $use_builder" >&2
  echo "  Base Image for First Stage: $SELECTED_IMAGE_TAG" >&2
  if ! confirm_action "Proceed with build?" true; then
      log_warning "Build cancelled by user."
      trap - EXIT TERM INT # Disable trap before returning
      rm -f "$PREFS_FILE"
      return 1 # Indicate cancellation
  fi
  log_debug "User confirmed build."

  # --- Save Preferences to File and .env ---
  log_debug "Updating .env with Docker info and selected base image."
  update_env_variable "DOCKER_USERNAME" "$DOCKER_USERNAME"
  update_env_variable "DOCKER_REGISTRY" "$DOCKER_REGISTRY"
  update_env_variable "DOCKER_REPO_PREFIX" "$DOCKER_REPO_PREFIX"
  update_env_variable "DEFAULT_BASE_IMAGE" "$SELECTED_IMAGE_TAG" # Save selected as new default base

  log_debug "Saving preferences to $PREFS_FILE"
  {
    echo "export DOCKER_USERNAME=\"${DOCKER_USERNAME:-}\""
    echo "export DOCKER_REPO_PREFIX=\"${DOCKER_REPO_PREFIX:-}\""
    echo "export DOCKER_REGISTRY=\"${DOCKER_REGISTRY:-}\""
    echo "export use_cache=\"${use_cache:-n}\""
    echo "export use_squash=\"${use_squash:-n}\""
    echo "export skip_intermediate_push_pull=\"${skip_intermediate_push_pull:-y}\"" # Corrected default
    echo "export use_builder=\"${use_builder:-y}\""
    echo "export SELECTED_BASE_IMAGE=\"${SELECTED_IMAGE_TAG:-}\""
    echo "export PLATFORM=\"${PLATFORM:-linux/arm64}\"" # Keep platform setting
    echo "export platform=\"${PLATFORM:-linux/arm64}\"" # Keep lowercase too
    echo "export SELECTED_FOLDERS_LIST=\"${selected_folders_list:-}\""
  } > "$PREFS_FILE"
  log_debug "Build preferences saved to $PREFS_FILE"
  log_debug "Exiting get_build_preferences_basic function successfully."
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

  log_debug "Entering get_run_preferences function."
  log_debug "Defaults: Img=$default_image_name, X11=$default_enable_x11, GPU=$default_enable_gpu, WS=$default_mount_workspace, Root=$default_user_root"
  log_debug "Available images: ${available_images_array[*]}"

  # Initialize export variables
  export SELECTED_IMAGE=""
  export SELECTED_X11="false"
  export SELECTED_GPU="false"
  export SELECTED_WS="false"
  export SELECTED_ROOT="false"
  export SAVE_CUSTOM_IMAGE="false"
  export CUSTOM_IMAGE_NAME=""

  if ! _is_dialog_available; then
    log_warning "Dialog not available. Falling back to basic run prompts." # Use log_warning
    get_run_preferences_basic "$default_image_name" "$default_enable_x11" "$default_enable_gpu" "$default_mount_workspace" "$default_user_root" "${available_images_array[@]}"
    return $?
  fi
  log_debug "Dialog available. Proceeding with dialog UI for run preferences."

  local temp_file temp_menu_file temp_custom_file
  temp_file=$(mktemp) || { log_error "Failed to create temp file for run options"; return 1; }
  temp_menu_file=$(mktemp) || { log_error "Failed to create temp file for run menu"; rm -f "$temp_file"; return 1; }
  temp_custom_file=$(mktemp) || { log_error "Failed to create temp file for run custom"; rm -f "$temp_file" "$temp_menu_file"; return 1; }

  log_debug "Starting dialog subshell for run preferences..."
  (
    trap 'rm -f "$temp_file" "$temp_menu_file" "$temp_custom_file"' EXIT TERM INT
    _log_debug_sub() { if [[ "${JETC_DEBUG}" == "true" || "${JETC_DEBUG}" == "1" ]]; then echo "[DEBUG SUB] $(date '+%Y-%m-%d %H:%M:%S') - ${FUNCNAME[1]}: $1" >&2; fi; }


    local DIALOG_HEIGHT=20
    local DIALOG_WIDTH=80
    local LIST_HEIGHT=${#available_images_array[@]}
    [[ $LIST_HEIGHT -lt 4 ]] && LIST_HEIGHT=4 # Minimum height
    [[ $LIST_HEIGHT -gt 10 ]] && LIST_HEIGHT=10 # Maximum height

    local current_image_selection="$default_image_name"
    local final_image_list=("${available_images_array[@]}") # Copy array

    # --- Step 1: Image Selection ---
    if [ ${#final_image_list[@]} -gt 0 ]; then
      _log_debug_sub "Displaying Image Selection radiolist."
      local menu_items=()
      local default_selected_tag=""
      for ((i=0; i<${#final_image_list[@]}; i++)); do
        local status="off"
        local tag="$((i+1))"
        if [[ "${final_image_list[$i]}" == "$current_image_selection" ]]; then
          status="on" # Set default selection status
          default_selected_tag="$tag"
          _log_debug_sub "Default image match found: ${final_image_list[$i]} (Tag $tag)"
        fi
        menu_items+=("$tag" "${final_image_list[$i]}" "$status")
      done
      # Add custom option
      menu_items+=("custom" "Enter a custom image name" "off")

      # If no default was found, select the first item if list is not empty
      if [[ -z "$default_selected_tag" ]] && [[ ${#menu_items[@]} -gt 0 ]]; then
          # Find the first item's tag (which is "1") and set its status to "on"
          for ((j=0; j<${#menu_items[@]}; j+=3)); do
              if [[ "${menu_items[j]}" == "1" ]]; then
                  menu_items[j+2]="on"
                  default_selected_tag="1"
                  _log_debug_sub "No default image match, selecting first item (Tag 1)."
                  break
              fi
          done
      fi

      dialog --backtitle "Jetson Container Run" \
        --title "Select Container Image" \
        --default-item "$default_selected_tag" \
        --radiolist "Choose an image or enter a custom one (use Space to select):" $DIALOG_HEIGHT $DIALOG_WIDTH $LIST_HEIGHT \
        "${menu_items[@]}" 2>"$temp_menu_file" # Capture radiolist output

      local menu_exit_status=$?
      local selection_tag
      selection_tag=$(cat "$temp_menu_file")
      _log_debug_sub "Image Selection radiolist exit status: $menu_exit_status, Selection: '$selection_tag'"

      if [[ $menu_exit_status -ne 0 ]]; then
        _log_debug_sub "Image selection canceled. Exiting subshell."
        exit 1 # Exit subshell with error
      fi

      if [[ "$selection_tag" == "custom" ]]; then
        _log_debug_sub "Displaying Custom Image inputbox."
        dialog --backtitle "Jetson Container Run" \
          --title "Custom Container Image" \
          --inputbox "Enter the full container image name/tag:" 8 $DIALOG_WIDTH "" \
          2>"$temp_custom_file" # Capture inputbox output
        local custom_exit_status=$?
        local custom_image_name
        custom_image_name=$(cat "$temp_custom_file")
        _log_debug_sub "Custom Image inputbox exit status: $custom_exit_status, Name: '$custom_image_name'"

        if [[ $custom_exit_status -ne 0 ]]; then
          _log_debug_sub "Custom image input canceled. Exiting subshell."
          exit 1 # Exit subshell with error
        fi
        if [[ -z "$custom_image_name" ]]; then
            _log_debug_sub "Custom image name is empty. Exiting subshell."
            show_message "Error" "Custom image name cannot be empty." 8 $DIALOG_WIDTH
            exit 1 # Exit subshell with error
        fi
        current_image_selection="$custom_image_name"
        _log_debug_sub "Selected custom image: $current_image_selection"
        # Ask if user wants to save this custom image to the list for future runs
        if confirm_action "Add '$current_image_selection' to your saved images list in .env?" false 8 $DIALOG_WIDTH; then
            _log_debug_sub "User chose to save custom image."
            # Use echo to append to the temp file that will be sourced later
            echo "SAVE_CUSTOM_IMAGE=true" >> "$temp_file"
            echo "CUSTOM_IMAGE_NAME=$current_image_selection" >> "$temp_file"
        else
             _log_debug_sub "User chose not to save custom image."
        fi
      else
        # User selected an existing image via its tag (index+1)
        local selected_index=$((selection_tag - 1))
        if [[ "$selected_index" -ge 0 ]] && [[ "$selected_index" -lt ${#final_image_list[@]} ]]; then
            current_image_selection="${final_image_list[$selected_index]}"
            _log_debug_sub "Selected existing image: $current_image_selection"
        else
            _log_debug_sub "Invalid selection tag '$selection_tag'. Exiting subshell."
            show_message "Error" "Invalid image selection." 8 $DIALOG_WIDTH
            exit 1 # Exit subshell with error
        fi
      fi
    else
      # No available images, directly prompt for image name
      _log_debug_sub "No available images found. Displaying inputbox for image name."
      dialog --backtitle "Jetson Container Run" \
        --title "Container Image" \
        --inputbox "No saved images found. Enter container image name:" 8 $DIALOG_WIDTH "$current_image_selection" \
        2>"$temp_custom_file" # Capture inputbox output
      local input_exit_status=$?
      current_image_selection=$(cat "$temp_custom_file" | tr -d '\n')
      _log_debug_sub "Image inputbox exit status: $input_exit_status, Name: '$current_image_selection'"
      if [[ $input_exit_status -ne 0 ]]; then
        _log_debug_sub "Image input canceled. Exiting subshell."
        exit 1 # Exit subshell with error
      fi
       if [[ -z "$current_image_selection" ]]; then
         _log_debug_sub "Image name is empty. Exiting subshell."
         show_message "Error" "Image name cannot be empty." 8 $DIALOG_WIDTH
         exit 1 # Exit subshell with error
       fi
       _log_debug_sub "Entered image name: $current_image_selection"
       # Ask to save this first image
       if confirm_action "Add '$current_image_selection' to your saved images list in .env?" false 8 $DIALOG_WIDTH; then
            _log_debug_sub "User chose to save first custom image."
            echo "SAVE_CUSTOM_IMAGE=true" >> "$temp_file"
            echo "CUSTOM_IMAGE_NAME=$current_image_selection" >> "$temp_file"
       fi
    fi

    # --- Step 2: Runtime Options ---
    local enable_x11="$default_enable_x11"
    local enable_gpu="$default_enable_gpu"
    local mount_workspace="$default_mount_workspace"
    local user_root="$default_user_root"
    _log_debug_sub "Displaying Runtime Options checklist."

    dialog --backtitle "Jetson Container Run" \
      --title "Runtime Options" \
      --checklist "Select runtime options:" 12 $DIALOG_WIDTH 4 \
      "X11" "Enable X11 forwarding" "$enable_x11" \
      "GPU" "Enable all GPUs (--gpus all)" "$enable_gpu" \
      "WORKSPACE" "Mount /media/kkk:/workspace & jtop" "$mount_workspace" \
      "ROOT" "Run as root user (--user root)" "$user_root" \
      2>"$temp_file" # Overwrite temp_file with checklist results

    local checklist_exit_status=$?
    _log_debug_sub "Runtime Options checklist exit status: $checklist_exit_status"
     if [[ $checklist_exit_status -ne 0 ]]; then
        _log_debug_sub "Runtime options selection canceled. Exiting subshell."
        exit 1 # Exit subshell with error
      fi

    local checklist_results
    checklist_results=$(cat "$temp_file")
    _log_debug_sub "Runtime options checklist raw results: '$checklist_results'"

    # --- Save selections to temp file for export ---
    # Clear temp file before adding results (checklist overwrote it, but custom image might have appended)
    > "$temp_file"
    echo "SELECTED_IMAGE=$current_image_selection" >> "$temp_file"
    [[ "$checklist_results" == *'"X11"'* ]] && echo "SELECTED_X11=true" >> "$temp_file" || echo "SELECTED_X11=false" >> "$temp_file"
    [[ "$checklist_results" == *'"GPU"'* ]] && echo "SELECTED_GPU=true" >> "$temp_file" || echo "SELECTED_GPU=false" >> "$temp_file"
    [[ "$checklist_results" == *'"WORKSPACE"'* ]] && echo "SELECTED_WS=true" >> "$temp_file" || echo "SELECTED_WS=false" >> "$temp_file"
    [[ "$checklist_results" == *'"ROOT"'* ]] && echo "SELECTED_ROOT=true" >> "$temp_file" || echo "SELECTED_ROOT=false" >> "$temp_file"
    # Re-check if custom image saving was requested and add if necessary
    if [[ -n "${CUSTOM_IMAGE_NAME:-}" ]]; then
        echo "SAVE_CUSTOM_IMAGE=true" >> "$temp_file"
        echo "CUSTOM_IMAGE_NAME=$CUSTOM_IMAGE_NAME" >> "$temp_file"
    fi
    _log_debug_sub "Saved final selections to temp file."

    _log_debug_sub "Dialog subshell for run preferences finished successfully."
    exit 0 # Exit subshell successfully
  )
  local subshell_exit_code=$?
  log_debug "Dialog subshell for run preferences exited with code: $subshell_exit_code"

  # Process results from temp file if subshell succeeded
  if [[ $subshell_exit_code -eq 0 ]] && [[ -f "$temp_file" ]]; then
    # Source the temp file to export variables back to the main script's scope
    # shellcheck disable=SC1090
    source "$temp_file"
    log_debug "Sourced run preferences from temp file."
    log_debug "Exported: IMAGE=$SELECTED_IMAGE, X11=$SELECTED_X11, GPU=$SELECTED_GPU, WS=$SELECTED_WS, ROOT=$SELECTED_ROOT, SAVE_CUSTOM=$SAVE_CUSTOM_IMAGE, CUSTOM_NAME=$CUSTOM_IMAGE_NAME"
  fi

  # Clean up temp files
  rm -f "$temp_file" "$temp_menu_file" "$temp_custom_file"
  log_debug "Cleaned up run preference temp files."

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

  log_debug "Entering get_run_preferences_basic function."

  local current_image_selection="$default_image_name"
  local final_image_list=("${available_images_array[@]}")

  # --- Step 1: Image Selection ---
  if [ ${#final_image_list[@]} -gt 0 ]; then
    log_debug "Displaying available images list."
    echo "Available container images:" >&2
    local default_choice_num=""
    for ((i=0; i<${#final_image_list[@]}; i++)); do
      echo "[$((i+1))] ${final_image_list[$i]}" >&2
      if [[ "${final_image_list[$i]}" == "$current_image_selection" ]]; then
        default_choice_num="$((i+1))"
        log_debug "Default image match found: ${final_image_list[$i]} (Choice $default_choice_num)"
      fi
    done
    echo "[c] Enter a custom image name" >&2

    local prompt_default="c"
    if [[ -n "$default_choice_num" ]]; then
        prompt_default="$default_choice_num"
    elif [[ ${#final_image_list[@]} -gt 0 ]]; then
        prompt_default="1" # Default to first item if current not found
        log_debug "No default match, setting prompt default to 1."
    fi

    echo -n "Select an option [1-${#final_image_list[@]}/c] (default: $prompt_default): " >&2
    read img_choice </dev/tty
    img_choice=${img_choice:-$prompt_default}
    log_debug "User image choice: '$img_choice'"

    if [[ "$img_choice" == "c" ]]; then
      echo -n "Enter the container image name: " >&2
      read custom_image_name </dev/tty
      log_debug "Entered custom image name: '$custom_image_name'"
      if [[ -z "$custom_image_name" ]]; then
          log_error "Custom image name cannot be empty."
          return 1 # Error
      fi
      current_image_selection="$custom_image_name"
      if confirm_action "Add '$current_image_selection' to your saved images list?" false; then
        log_debug "User chose to save custom image."
        export SAVE_CUSTOM_IMAGE="true"
        export CUSTOM_IMAGE_NAME="$current_image_selection"
      else
        log_debug "User chose not to save custom image."
      fi
    elif [[ "$img_choice" =~ ^[0-9]+$ ]] && [ "$img_choice" -ge 1 ] && [ "$img_choice" -le ${#final_image_list[@]} ]; then
      current_image_selection="${final_image_list[$((img_choice-1))]}"
      log_debug "Selected existing image: $current_image_selection"
    else
      log_error "Invalid selection '$img_choice'. Exiting."
      return 1 # Error
    fi
  else
    # No images in list, prompt directly
    log_warning "No saved images found."
    echo -n "Enter the container image name: " >&2
    read current_image_selection </dev/tty
    log_debug "Entered image name: '$current_image_selection'"
     if [[ -z "$current_image_selection" ]]; then
        log_error "Image name cannot be empty."
        return 1 # Error
    fi
     if confirm_action "Add '$current_image_selection' to your saved images list?" false; then
        log_debug "User chose to save first custom image."
        export SAVE_CUSTOM_IMAGE="true"
        export CUSTOM_IMAGE_NAME="$current_image_selection"
     fi
  fi
  export SELECTED_IMAGE="$current_image_selection"
  log_info "Selected image: $SELECTED_IMAGE"
  echo "-------------------------" >&2

  # --- Step 2: Runtime Options ---
  local x11_prompt="y" gpu_prompt="y" ws_prompt="y" root_prompt="y"
  [[ "$default_enable_x11" == "off" ]] && x11_prompt="n"
  [[ "$default_enable_gpu" == "off" ]] && gpu_prompt="n"
  [[ "$default_mount_workspace" == "off" ]] && ws_prompt="n"
  [[ "$default_user_root" == "off" ]] && root_prompt="n"

  echo -n "Enable X11 forwarding? (y/n) [$x11_prompt]: " >&2; read x11 </dev/tty; x11=${x11:-$x11_prompt}
  echo -n "Enable all GPUs? (y/n) [$gpu_prompt]: " >&2; read gpu </dev/tty; gpu=${gpu:-$gpu_prompt}
  echo -n "Mount /media/kkk:/workspace & jtop? (y/n) [$ws_prompt]: " >&2; read ws </dev/tty; ws=${ws:-$ws_prompt}
  echo -n "Run as root user? (y/n) [$root_prompt]: " >&2; read root </dev/tty; root=${root:-$root_prompt}

  [[ "$x11" =~ ^[Yy]$ ]] && export SELECTED_X11="true" || export SELECTED_X11="false"
  [[ "$gpu" =~ ^[Yy]$ ]] && export SELECTED_GPU="true" || export SELECTED_GPU="false"
  [[ "$ws" =~ ^[Yy]$ ]] && export SELECTED_WS="true" || export SELECTED_WS="false"
  [[ "$root" =~ ^[Yy]$ ]] && export SELECTED_ROOT="true" || export SELECTED_ROOT="false"
  log_debug "Parsed runtime options: X11=$SELECTED_X11, GPU=$SELECTED_GPU, WS=$SELECTED_WS, ROOT=$SELECTED_ROOT"

  log_debug "Basic run prompts finished successfully."
  log_debug "Exported: IMAGE=$SELECTED_IMAGE, X11=$SELECTED_X11, GPU=$SELECTED_GPU, WS=$SELECTED_WS, ROOT=$SELECTED_ROOT, SAVE_CUSTOM=$SAVE_CUSTOM_IMAGE, CUSTOM_NAME=$CUSTOM_IMAGE_NAME"
  return 0 # Success
}

# =========================================================================
# Post Build Menu UI (Moved from post_build_menu.sh)
# Arguments: $1 = image tag
# Returns: Exit status of the chosen action (e.g., docker run) or 0 if skipped/cancelled
# =========================================================================
show_post_build_menu() {
  local image_tag=$1
  log_info "--------------------------------------------------"
  log_info "Final Image Built: $image_tag"
  log_info "--------------------------------------------------"
  if ! verify_image_exists "$image_tag"; then # Use docker_helper function
    log_error "Final image $image_tag not found locally, cannot proceed with post-build actions."
    show_message "Error" "Final image $image_tag not found locally, cannot proceed with post-build actions."
    return 1
  fi

  if _is_dialog_available; then
    log_debug "Displaying post-build menu (dialog)."
    local temp_file
    temp_file=$(mktemp) || { log_error "Failed to create temp file for post-build menu"; return 1; }
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
           2>"$temp_file" # Capture radiolist output
    local exit_status=$?
    local selection
    selection=$(cat "$temp_file")
    rm -f "$temp_file" # Clean up immediately
    clear # Clear dialog remnants
    log_debug "Post-build menu exit status: $exit_status, Selection: '$selection'"

    if [ $exit_status -ne 0 ]; then
      log_warning "Post-build operation cancelled by user."
      return 0 # Treat cancel as skip
    fi

    case "$selection" in
      "shell")
        log_info "Starting interactive shell for $image_tag..."
        # Use run_container from docker_helpers? Or simpler direct run? Direct run is fine here.
        docker run -it --rm --gpus all "$image_tag" bash
        return $?
        ;;
      "verify")
        log_info "Running quick verification for $image_tag..."
        verify_container_apps "$image_tag" "quick" # Use verification helper
        return $?
        ;;
      "full")
        log_info "Running full verification for $image_tag..."
        verify_container_apps "$image_tag" "all" # Use verification helper
        return $?
        ;;
      "list")
        log_info "Listing installed apps for $image_tag..."
        list_installed_apps "$image_tag" # Use verification helper
        return $?
        ;;
      "skip"|"")
        log_info "Skipping post-build container action."
        return 0
        ;;
      *)
        log_error "Invalid choice '$selection'. Skipping container action."
        show_message "Error" "Invalid choice '$selection'. Skipping container action."
        return 0
        ;;
    esac
  else
    # Text-based menu
    log_debug "Displaying post-build menu (text)."
    echo "--------------------------------------------------" >&2
    echo "Post-Build Options for Image: $image_tag" >&2
    echo "--------------------------------------------------" >&2
    echo "1) Start an interactive shell" >&2
    echo "2) Run quick verification (common tools and packages)" >&2
    echo "3) Run full verification (all system packages, may be verbose)" >&2
    echo "4) List installed apps in the container" >&2
    echo "5) Skip (do nothing)" >&2
    echo -n "Enter your choice [1-5, default: 2]: " >&2
    read user_choice </dev/tty
    user_choice=${user_choice:-2}
    log_debug "Post-build menu user choice: '$user_choice'"
    case "$user_choice" in
      1)
        log_info "Starting interactive shell for $image_tag..."
        docker run -it --rm --gpus all "$image_tag" bash
        return $?
        ;;
      2)
        log_info "Running quick verification for $image_tag..."
        verify_container_apps "$image_tag" "quick"
        return $?
        ;;
      3)
        log_info "Running full verification for $image_tag..."
        verify_container_apps "$image_tag" "all"
        return $?
        ;;
      4)
        log_info "Listing installed apps for $image_tag..."
        list_installed_apps "$image_tag"
        return $?
        ;;
      5)
        log_info "Skipping post-build container action."
        return 0
        ;;
      *)
        log_error "Invalid choice '$user_choice'. Skipping container action."
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
# Description: Interactive UI functions (Dialog/Text) for build/run preferences and post-build actions. Added logging.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20240806-103000-MODULAR
