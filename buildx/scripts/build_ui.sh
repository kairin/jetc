#!/bin/bash
#
# Description: UI functions for the build process (dialogs, prompts, .env handling).
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250421-020700-REFA

# Source necessary utilities
SCRIPT_DIR_BUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BUI/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BUI/docker_helpers.sh" || { echo "Error: docker_helpers.sh not found."; exit 1; }
# shellcheck disable=SC1091
source "$SCRIPT_DIR_BUI/verification.sh" || { echo "Error: verification.sh not found."; exit 1; }

# Always resolve .env to canonical location (same as build.sh and jetcrun.sh)
ENV_CANONICAL="$(cd "$SCRIPT_DIR_BUI/.." && pwd)/.env"

# =========================================================================
# Function: Update .env file with new values
# Arguments: 1: Username, 2: Registry, 3: Prefix, 4: Base Image Tag
# Location: Assumes .env is in the parent directory (buildx/)
# =========================================================================
update_env_file() {
    local new_username="$1"
    local new_registry="$2"
    local new_prefix="$3"
    local new_base_image="$4" # This will update DEFAULT_BASE_IMAGE
    local env_file # Determine the path relative to this script's location
    env_file="$ENV_CANONICAL"

    echo "Attempting to update settings in $env_file..." >&2

    # Create the file with default content if it doesn't exist
    if [ ! -f "$env_file" ]; then
        echo "Creating $env_file with default structure..." >&2
        # Use cat heredoc for clarity
        cat > "$env_file" << EOF
# Docker registry URL (optional, leave empty for Docker Hub)
DOCKER_REGISTRY=

# Docker registry username (required)
DOCKER_USERNAME=

# Docker repository prefix (required)
DOCKER_REPO_PREFIX=

# Default base image for builds (last selected)
DEFAULT_BASE_IMAGE=nvcr.io/nvidia/l4t-pytorch:r35.4.1-pth2.1-py3

# Available container images (semicolon-separated, managed by build/run scripts)
AVAILABLE_IMAGES=

# Last used container settings for jetcrun.sh
DEFAULT_IMAGE_NAME=
DEFAULT_ENABLE_X11=on
DEFAULT_ENABLE_GPU=on
DEFAULT_MOUNT_WORKSPACE=on
DEFAULT_USER_ROOT=on
EOF
    fi

    # Use a temporary file for safe updates
    local temp_env
    temp_env=$(mktemp) || { echo "Failed to create temp file for .env update"; return 1; }
    # Copy original content, preserving comments and structure
    cp "$env_file" "$temp_env"

    # Update values using sed - replace existing or append if missing
    local settings_to_update=(
        "DOCKER_USERNAME=$new_username"
        "DOCKER_REGISTRY=$new_registry"
        "DOCKER_REPO_PREFIX=$new_prefix"
        "DEFAULT_BASE_IMAGE=$new_base_image"
    )

    for setting in "${settings_to_update[@]}"; do
        local key="${setting%%=*}"
        local value="${setting#*=}"
        # Escape potential special characters in value for sed (simple approach)
        local escaped_value
        escaped_value=$(printf '%s\n' "$value" | sed -e 's/[\/&]/\\&/g' -e 's/$/\\/' -e '$s/\\$//')

        # Check if key exists (ignoring comments and leading whitespace)
        if grep -qE "^\s*${key}=" "$temp_env"; then
             # Key exists, replace the value using | as delimiter for safety
             sed -i "s|^\s*${key}=.*|${key}=${escaped_value}|" "$temp_env"
             echo "  Updated $key in $env_file" >&2
        else
             # Key doesn't exist, append it (consider adding comments)
             echo "  Adding $key to $env_file" >&2
             # Add a comment based on the key
             case "$key" in
                 "DOCKER_USERNAME") echo -e "\n# Docker registry username (required)" >> "$temp_env" ;;
                 "DOCKER_REGISTRY") echo -e "\n# Docker registry URL (optional, leave empty for Docker Hub)" >> "$temp_env" ;;
                 "DOCKER_REPO_PREFIX") echo -e "\n# Docker repository prefix (required)" >> "$temp_env" ;;
                 "DEFAULT_BASE_IMAGE") echo -e "\n# Default base image for builds (last selected)" >> "$temp_env" ;;
             esac
             echo "${key}=${value}" >> "$temp_env" # Use original value here, not escaped
        fi
    done

    # Replace original .env with the updated temporary file
    mv "$temp_env" "$env_file"
    echo ".env file updated successfully." >&2
    # Ensure temp file is removed even if mv fails (though unlikely)
    rm -f "$temp_env"

    return 0
}

# =========================================================================
# Function: Load environment variables from .env file
# Location: Assumes .env is in the parent directory (buildx/)
# Exports: DOCKER_USERNAME, DOCKER_REGISTRY, DOCKER_REPO_PREFIX, DEFAULT_BASE_IMAGE, AVAILABLE_IMAGES etc.
# Returns: 0 (always succeeds, variables might be empty if file not found)
# =========================================================================
load_env_variables() {
  local env_file="$ENV_CANONICAL"

  if [ -f "$env_file" ]; then
    echo "Loading environment variables from $env_file..." >&2
    # Use set -a to export all variables defined in the .env file
    set -a
    # shellcheck disable=SC1090 # Source file from variable
    . "$env_file"
    set +a
    echo "Finished loading .env file." >&2
  else
    echo "INFO: $env_file not found. Will rely on defaults or prompts." >&2
  fi

  # Initialize variables with defaults if they are not set (from .env or otherwise)
  # These will serve as initial defaults for the prompts
  DOCKER_REGISTRY=${DOCKER_REGISTRY:-}
  DOCKER_USERNAME=${DOCKER_USERNAME:-}
  DOCKER_REPO_PREFIX=${DOCKER_REPO_PREFIX:-}
  # Use a specific, potentially user-settable default, or a hardcoded fallback
  DEFAULT_BASE_IMAGE=${DEFAULT_BASE_IMAGE:-"nvcr.io/nvidia/l4t-pytorch:r35.4.1-pth2.1-py3"} # Example fallback
  AVAILABLE_IMAGES=${AVAILABLE_IMAGES:-} # Load available images string
  DEFAULT_IMAGE_NAME=${DEFAULT_IMAGE_NAME:-} # Last used image for run
  DEFAULT_ENABLE_X11=${DEFAULT_ENABLE_X11:-on}
  DEFAULT_ENABLE_GPU=${DEFAULT_ENABLE_GPU:-on}
  DEFAULT_MOUNT_WORKSPACE=${DEFAULT_MOUNT_WORKSPACE:-on}
  DEFAULT_USER_ROOT=${DEFAULT_USER_ROOT:-on}


  # Export potentially loaded or initialized variables so they are available globally
  export DOCKER_REGISTRY DOCKER_USERNAME DOCKER_REPO_PREFIX DEFAULT_BASE_IMAGE AVAILABLE_IMAGES
  export DEFAULT_IMAGE_NAME DEFAULT_ENABLE_X11 DEFAULT_ENABLE_GPU DEFAULT_MOUNT_WORKSPACE DEFAULT_USER_ROOT

  # Log initial values (optional)
  # echo "Initial Docker values (will be confirmed/edited):" >&2
  # echo "  Registry: ${DOCKER_REGISTRY:-<Not Set - Docker Hub>}" >&2
  # echo "  Username: ${DOCKER_USERNAME:-<Not Set>}" >&2
  # echo "  Repo Prefix: ${DOCKER_REPO_PREFIX:-<Not Set>}" >&2
  # echo "  Default Base: ${DEFAULT_BASE_IMAGE}" >&2

  return 0 # Always return success
}

# =========================================================================
# Function: Get user preferences for build using dialog
# Returns: 0 if successful, 1 if not (e.g., on cancel/error)
# Relies on: Variables exported by load_env_variables (DOCKER_*, DEFAULT_BASE_IMAGE)
#            PLATFORM variable (should be set by build_setup.sh)
# Writes to: /tmp/build_prefs.sh on success
# Updates:   buildx/.env with confirmed Docker/Base Image settings
# Exports:   Variables defined in /tmp/build_prefs.sh after sourcing
# =========================================================================
get_user_preferences() {
  # Check if dialog is available, fallback if not
  if ! check_install_dialog; then
    echo "Dialog not available or failed to install. Falling back to basic prompts." >&2
    # Call the basic prompt function and ensure it writes to the temp file too
    get_user_preferences_basic
    return $? # Return the exit code of the basic function
  fi

  # Temporary file for preferences export (must match build.sh)
  local PREFS_FILE="/tmp/build_prefs.sh"

  # Create temporary files safely for dialog output
  local temp_options temp_base_choice temp_custom_image temp_docker_info temp_folders
  temp_options=$(mktemp) || { echo "Failed to create temp file"; return 1; }
  temp_base_choice=$(mktemp) || { echo "Failed to create temp file"; rm -f "$temp_options"; return 1; }
  temp_custom_image=$(mktemp) || { echo "Failed to create temp file"; rm -f "$temp_options" "$temp_base_choice"; return 1; }
  temp_docker_info=$(mktemp) || { echo "Failed to create temp file"; rm -f "$temp_options" "$temp_base_choice" "$temp_custom_image"; return 1; }
  temp_folders=$(mktemp) || { echo "Failed to create temp file"; rm -f "$temp_options" "$temp_base_choice" "$temp_custom_image" "$temp_docker_info"; return 1; }

  # Ensure temp files are cleaned up on exit or error within this function
  # Use a subshell trap to avoid interfering with traps in calling scripts
  (
    trap 'rm -f "$temp_options" "$temp_base_choice" "$temp_custom_image" "$temp_docker_info" "$temp_folders" "$PREFS_FILE"' EXIT TERM INT

    # Dialog dimensions
    local DIALOG_HEIGHT=12
    local DIALOG_WIDTH=85
    local CHECKLIST_HEIGHT=6
    local FORM_HEIGHT=3
    local FOLDER_LIST_HEIGHT=10

    # --- Step 0: Docker Registry/User/Prefix Confirmation ---
    # Use local variables to hold dialog results before overwriting globals/exports
    local temp_registry="$DOCKER_REGISTRY"
    local temp_username="$DOCKER_USERNAME"
    local temp_prefix="$DOCKER_REPO_PREFIX"

    while true; do
      # Replace the dialog command with a more straightforward version
      # that focuses on simplicity and reliability
      dialog --clear --no-cancel \
             --backtitle "Docker Build Configuration" \
             --title "Step 0: Docker Information" \
             --ok-label "Next" \
             --form "Confirm or edit Docker details (loaded from .env):" $DIALOG_HEIGHT $DIALOG_WIDTH $FORM_HEIGHT \
             "Registry (optional, empty=Docker Hub):" 1 1 "$temp_registry"     1 40 40 0 \
             "Username (required):"                   2 1 "$temp_username"    2 40 40 0 \
             "Repository Prefix (required):"          3 1 "$temp_prefix"      3 40 40 0 \
             2>"$temp_docker_info"

      local form_exit_status=$?
      echo "DEBUG: Form exit status: $form_exit_status" >&2
      
      if [ $form_exit_status -ne 0 ]; then
        echo "Docker information entry canceled (exit code: $form_exit_status). Exiting." >&2
        exit 1 # Indicate cancellation
      fi
      
      echo "DEBUG: Reading form values:" >&2
      cat "$temp_docker_info" >&2
      
      # Read values more reliably - don't use mapfile which might fail silently
      local line_count=0
      local line_registry="" line_username="" line_prefix=""
      while IFS= read -r line; do
        case "$line_count" in
          0) line_registry="$line" ;;
          1) line_username="$line" ;;
          2) line_prefix="$line" ;;
        esac
        ((line_count++))
      done < "$temp_docker_info"
      
      # Assign with fallback to previous values if reading failed
      temp_registry="${line_registry:-$temp_registry}"
      temp_username="${line_username:-$temp_username}"
      temp_prefix="${line_prefix:-$temp_prefix}"
      
      echo "DEBUG: Parsed values - Registry:[$temp_registry] User:[$temp_username] Prefix:[$temp_prefix]" >&2

      # Validate required fields
      local validation_error=""
      if [[ -z "$temp_username" ]]; then validation_error+="Username cannot be empty.\\n"; fi
      if [[ -z "$temp_prefix" ]]; then validation_error+="Repository Prefix cannot be empty.\\n"; fi

      if [[ -n "$validation_error" ]]; then
        dialog --msgbox "Validation Error:\\n\\n$validation_error\\nPlease correct the entries." 10 $DIALOG_WIDTH
        if [ $? -ne 0 ]; then echo "Msgbox closed unexpectedly. Exiting." >&2; exit 1; fi
        # Loop continues
      else
        # Validation passed, update main variables and break the loop
        DOCKER_REGISTRY="$temp_registry"
        DOCKER_USERNAME="$temp_username"
        DOCKER_REPO_PREFIX="$temp_prefix"
        break
      fi
    done

    # --- Step 0.5: Select Build Folders ---
    local build_dir="$SCRIPT_DIR_BUI/../build" # Relative to this script
    local folder_checklist_items=()
    local numbered_folders=()
    local folder_count=0

    # Find numbered directories and prepare checklist items
    if [ -d "$build_dir" ]; then
        mapfile -t numbered_folders < <(find "$build_dir" -maxdepth 1 -mindepth 1 -type d -name '[0-9]*-*' | sort)
        for folder_path in "${numbered_folders[@]}"; do
            folder_name=$(basename "$folder_path")
            # tag item status (default to on)
            folder_checklist_items+=("$folder_name" "$folder_name" "on")
            ((folder_count++))
        done
    fi

    local selected_folders_list="" # Will hold space-separated list of selected folder names

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
            exit 1 # Indicate cancellation
        fi
        # Read the selected items (tags) from the temp file, remove quotes, space-separated
        selected_folders_list=$(cat "$temp_folders" | sed 's/"//g')
        echo "Selected folders: $selected_folders_list" >&2 # Debugging
    else
        echo "No numbered build folders found in $build_dir. Skipping folder selection." >&2
        selected_folders_list="" # Ensure it's empty
    fi


    # --- Step 1: Main Build Options Checklist ---
    # Define default states for checklist (consider loading from .env if needed)
    local use_cache="n" # Default to no cache
    local use_squash="n"
    local skip_intermediate_push_pull="y" # Default to local build
    local use_builder="y" # Default to using builder

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
      exit 1 # Indicate cancellation
    fi
    local selected_options
    selected_options=$(cat "$temp_options")

    # Parse checklist selections into 'y'/'n' variables
    [[ "$selected_options" == *'"cache"'* ]] && use_cache="y" || use_cache="n"
    [[ "$selected_options" == *'"squash"'* ]] && use_squash="y" || use_squash="n"
    [[ "$selected_options" == *'"local_build"'* ]] && skip_intermediate_push_pull="y" || skip_intermediate_push_pull="n"
    [[ "$selected_options" == *'"use_builder"'* ]] && use_builder="y" || use_builder="n"

    if [[ "$use_builder" == "n" ]]; then
        dialog --msgbox "Warning: Not using the dedicated 'jetson-builder' might lead to issues with NVIDIA runtime during build." 8 70
        if [ $? -ne 0 ]; then echo "Msgbox closed unexpectedly. Exiting." >&2; exit 1; fi
    fi

    # --- Step 2: Base Image Selection ---
    # Use the DEFAULT_BASE_IMAGE loaded from .env or the fallback
    local current_default_base_image_display="$DEFAULT_BASE_IMAGE"
    local SELECTED_IMAGE_TAG="$DEFAULT_BASE_IMAGE" # Initialize with default
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
      exit 1 # Indicate cancellation
    fi
    BASE_IMAGE_ACTION=$(cat "$temp_base_choice")

    # Process base image choice
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
          exit 1
        fi
        local entered_image
        entered_image=$(cat "$temp_custom_image")

        if [ -z "$entered_image" ]; then
          dialog --msgbox "No custom image entered. Reverting to default:\\n$current_default_base_image_display" 8 $DIALOG_WIDTH
          if [ $? -ne 0 ]; then echo "Msgbox closed unexpectedly. Exiting." >&2; exit 1; fi
          SELECTED_IMAGE_TAG="$current_default_base_image_display"
          BASE_IMAGE_ACTION="use_default" # Update action
        else
          SELECTED_IMAGE_TAG="$entered_image"
          dialog --infobox "Attempting to pull custom base image:\\n$SELECTED_IMAGE_TAG..." 5 $DIALOG_WIDTH
          sleep 1 # Give time to see the message
          if ! pull_image "$SELECTED_IMAGE_TAG"; then # Use helper function
            if dialog --yesno "Failed to pull custom base image:\\n$SELECTED_IMAGE_TAG.\\nCheck tag/URL.\\n\\nContinue build using default ($current_default_base_image_display)? Warning: Build might fail." 12 $DIALOG_WIDTH; then
               SELECTED_IMAGE_TAG="$current_default_base_image_display"
               BASE_IMAGE_ACTION="use_default" # Update action
               dialog --msgbox "Proceeding with default base image:\\n$SELECTED_IMAGE_TAG" 8 $DIALOG_WIDTH
               if [ $? -ne 0 ]; then echo "Msgbox closed unexpectedly. Exiting." >&2; exit 1; fi
            else
               echo "User chose to exit after failed custom image pull." >&2
               exit 1
            fi
          else
            dialog --msgbox "Successfully pulled custom base image:\\n$SELECTED_IMAGE_TAG" 8 $DIALOG_WIDTH
            if [ $? -ne 0 ]; then echo "Msgbox closed unexpectedly. Exiting." >&2; exit 1; fi
          fi
        fi
        ;;
      "pull_default")
        dialog --infobox "Attempting to pull default base image:\\n$current_default_base_image_display..." 5 $DIALOG_WIDTH
        sleep 1
        if ! pull_image "$current_default_base_image_display"; then # Use helper function
           if dialog --yesno "Failed to pull default base image:\\n$current_default_base_image_display.\\nBuild might fail if not local.\\n\\nContinue anyway?" 12 $DIALOG_WIDTH; then
              dialog --msgbox "Warning: Default image not pulled. Using local if available." 8 $DIALOG_WIDTH
              if [ $? -ne 0 ]; then echo "Msgbox closed unexpectedly. Exiting." >&2; exit 1; fi
           else
              echo "User chose to exit after failed default image pull." >&2
              exit 1
           fi
        else
          dialog --msgbox "Successfully pulled default base image:\\n$current_default_base_image_display" 8 $DIALOG_WIDTH
          if [ $? -ne 0 ]; then echo "Msgbox closed unexpectedly. Exiting." >&2; exit 1; fi
        fi
        SELECTED_IMAGE_TAG="$current_default_base_image_display"
        ;;
      "use_default")
        SELECTED_IMAGE_TAG="$current_default_base_image_display"
        dialog --msgbox "Using default base image (local version if available):\\n$SELECTED_IMAGE_TAG" 8 $DIALOG_WIDTH
        if [ $? -ne 0 ]; then echo "Msgbox closed unexpectedly. Exiting." >&2; exit 1; fi
        ;;
      *)
        echo "Invalid base image action selected: '$BASE_IMAGE_ACTION'. Exiting." >&2
        exit 1
        ;;
    esac

    # --- Step 3: Final Confirmation ---
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
        confirmation_message+="  - No numbered stages selected (or none found).\\n\\n" # Clarified message
    fi
    confirmation_message+="Build Options:\\n"
    confirmation_message+="  - Use Cache:          $( [[ "$use_cache" == "y" ]] && echo "Yes" || echo "No (--no-cache)" )\\n"
    confirmation_message+="  - Squash Layers:      $( [[ "$use_squash" == "y" ]] && echo "Yes (--squash)" || echo "No" )\\n"
    confirmation_message+="  - Build Locally Only: $( [[ "$skip_intermediate_push_pull" == "y" ]] && echo "Yes (--load)" || echo "No (--push)" )\\n"
    confirmation_message+="  - Use Builder:        $( [[ "$use_builder" == "y" ]] && echo "Yes (jetson-builder)" || echo "No (Default Docker)" )\\n\\n" # Use selected builder name
    confirmation_message+="Base Image for First Stage:\\n"
    confirmation_message+="  - Action Chosen:      $BASE_IMAGE_ACTION\\n"
    confirmation_message+="  - Image Tag To Use:   $SELECTED_IMAGE_TAG" # Use the final selected tag

    if ! dialog --yes-label "Start Build" --no-label "Cancel Build" --yesno "$confirmation_message\\n\\nProceed with build?" 25 $DIALOG_WIDTH; then # Increased height slightly
        echo "Build canceled by user at confirmation screen. Exiting." >&2
        exit 1 # Indicate cancellation
    fi

    # --- Update .env file with confirmed settings ---
    # Call the helper function with the final confirmed values
    update_env_file "$DOCKER_USERNAME" "$DOCKER_REGISTRY" "$DOCKER_REPO_PREFIX" "$SELECTED_IMAGE_TAG"
    local update_status=$?
    if [[ $update_status -ne 0 ]]; then
        echo "Warning: Failed to update .env file. Proceeding with current settings for this run only." >&2
        # Decide if this should be a fatal error or just a warning
        # exit 1 # Uncomment to make it fatal
    fi

    # --- Export preferences to temp file for build.sh ---
    echo "Exporting preferences to $PREFS_FILE" >&2
    {
      echo "export DOCKER_USERNAME=\"${DOCKER_USERNAME:-}\""
      echo "export DOCKER_REPO_PREFIX=\"${DOCKER_REPO_PREFIX:-}\""
      echo "export DOCKER_REGISTRY=\"${DOCKER_REGISTRY:-}\""
      echo "export use_cache=\"${use_cache:-n}\""
      echo "export use_squash=\"${use_squash:-n}\""
      echo "export skip_intermediate_push_pull=\"${skip_intermediate_push_pull:-n}\""
      echo "export use_builder=\"${use_builder:-y}\"" # Export the builder choice
      echo "export SELECTED_BASE_IMAGE=\"${SELECTED_IMAGE_TAG:-}\"" # Export the final chosen image tag
      echo "export PLATFORM=\"${PLATFORM:-linux/arm64}\"" # Export platform determined earlier
      echo "export SELECTED_FOLDERS_LIST=\"${selected_folders_list:-}\"" # Export selected folders
    } > "$PREFS_FILE"
    echo "Preferences exported." >&2
    # --- End of export block ---

    # Explicitly remove trap and dialog temp files ONLY on success before returning
    # Trap is local to subshell, no need to remove here. Files are removed by trap.
    exit 0 # Success from subshell
  ) # End of subshell

  local subshell_exit_code=$?
  # Return the exit code of the subshell
  return $subshell_exit_code
}

# =========================================================================
# Function: Fallback to basic prompts if dialog is not available
# Returns: 0 if successful, 1 if not
# Relies on: Variables exported by load_env_variables (DOCKER_*, DEFAULT_BASE_IMAGE)
#            PLATFORM variable (should be set by build_setup.sh)
# Writes to: /tmp/build_prefs.sh on success
# Updates:   buildx/.env with confirmed Docker/Base Image settings
# Exports:   Variables defined in /tmp/build_prefs.sh after sourcing
# =========================================================================
get_user_preferences_basic() {
  # Temporary file for preferences export (must match build.sh)
  local PREFS_FILE="/tmp/build_prefs.sh"
  # Ensure PREFS_FILE is cleaned up if this function exits early
  trap 'rm -f "$PREFS_FILE"' EXIT TERM INT

  # --- Docker Info ---
  echo "--- Docker Information ---"
  local temp_registry="$DOCKER_REGISTRY"
  local temp_username="$DOCKER_USERNAME"
  local temp_prefix="$DOCKER_REPO_PREFIX"

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
  # Update main variables
  DOCKER_REGISTRY="$temp_registry"
  DOCKER_USERNAME="$temp_username"
  DOCKER_REPO_PREFIX="$temp_prefix"
  echo "Using Registry: ${DOCKER_REGISTRY:-Docker Hub}, User: $DOCKER_USERNAME, Prefix: $DOCKER_REPO_PREFIX"
  echo "-------------------------"

  # --- Select Build Folders (Basic Prompt) ---
  echo "--- Select Build Stages ---"
  local build_dir="$SCRIPT_DIR_BUI/../build" # Relative to this script
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
          read -p "Enter numbers of stages to build (e.g., '1 3 4'), or leave empty for ALL: " selection_input
          if [[ -z "$selection_input" ]]; then
              # Select all if input is empty
              selected_folders_list="${folder_options[*]}"
              echo "Building ALL stages."
          else
              # Parse the input numbers
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


  # --- Build Options ---
  echo "--- Build Options ---"
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
  echo "--- Base Image ---"
  local current_default_base_image_display="$DEFAULT_BASE_IMAGE"
  local SELECTED_IMAGE_TAG="$DEFAULT_BASE_IMAGE" # Initialize

  echo "Default base image: $current_default_base_image_display"
  read -p "Action? (u=Use existing, p=Pull default, c=Specify custom) [u]: " base_action_input
  local base_action=${base_action_input:-u}

  case "$base_action" in
    p|P)
      echo "Pulling base image: $current_default_base_image_display" >&2
      if ! pull_image "$current_default_base_image_display"; then echo "Warning: Failed to pull base image." >&2; fi # Use helper
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
         if ! pull_image "$SELECTED_IMAGE_TAG"; then echo "Warning: Failed to pull custom base image." >&2; fi # Use helper
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
  echo "  Selected Stages: ${selected_folders_list:-None (will build none)}" # Clarified message
  echo "  Use Cache: $use_cache, Squash: $use_squash, Local Build Only: $skip_intermediate_push_pull, Use Builder: $use_builder"
  echo "  Base Image for First Stage: $SELECTED_IMAGE_TAG"
  read -p "Proceed with build? (y/n) [y]: " confirm_build
  if [[ "${confirm_build:-y}" != "y" ]]; then
      echo "Build cancelled." >&2
      trap - EXIT TERM INT # Disable trap before returning failure
      rm -f "$PREFS_FILE"
      return 1
  fi

  # --- Update .env file with confirmed settings ---
  update_env_file "$DOCKER_USERNAME" "$DOCKER_REGISTRY" "$DOCKER_REPO_PREFIX" "$SELECTED_IMAGE_TAG"
  local update_status=$?
   if [[ $update_status -ne 0 ]]; then
      echo "Warning: Failed to update .env file. Proceeding with current settings for this run only." >&2
  fi

  # --- Export preferences to temp file for build.sh ---
  echo "Exporting preferences to $PREFS_FILE" >&2
  {
    echo "export DOCKER_USERNAME=\"${DOCKER_USERNAME:-}\""
    echo "export DOCKER_REPO_PREFIX=\"${DOCKER_REPO_PREFIX:-}\""
    echo "export DOCKER_REGISTRY=\"${DOCKER_REGISTRY:-}\""
    echo "export use_cache=\"${use_cache:-n}\""
    echo "export use_squash=\"${use_squash:-n}\""
    echo "export skip_intermediate_push_pull=\"${skip_intermediate_push_pull:-n}\""
    echo "export use_builder=\"${use_builder:-y}\""
    echo "export SELECTED_BASE_IMAGE=\"${SELECTED_IMAGE_TAG:-}\""
    echo "export PLATFORM=\"${PLATFORM:-linux/arm64}\""
    echo "export SELECTED_FOLDERS_LIST=\"${selected_folders_list:-}\"" # Export selected folders
  } > "$PREFS_FILE"
  echo "Preferences exported." >&2
  # --- End of export block ---

  trap - EXIT TERM INT # Disable trap on success
  # DO NOT remove PREFS_FILE here

  return 0 # Success
}


# =========================================================================
# Function: Show post-build menu (Dialog version)
# Arguments: $1 = image tag to operate on
# Returns: The exit status of the chosen operation
# =========================================================================
show_dialog_menu() {
  local image_tag=$1
  local temp_file=$(mktemp)

  # Dialog dimensions
  local HEIGHT=20
  local WIDTH=70
  local LIST_HEIGHT=6  # Show all options in the list

  # Dialog text
  local TITLE="Post-Build Operations"
  local TEXT="Select an action for image: $image_tag"

  # Options: tag item status
  local OPTIONS=(
    "shell"      "Start an interactive shell"                   "off"
    "verify"     "Run quick verification (common tools)"        "on"   # Default selection
    "full"       "Run full verification (all packages)"         "off"
    "list"       "List installed apps in the container"         "off"
    "skip"       "Skip (do nothing)"                            "off"
  )

  # Display the radiolist dialog
  dialog --clear \
         --backtitle "Docker Image Operations" \
         --title "$TITLE" \
         --radiolist "$TEXT" $HEIGHT $WIDTH $LIST_HEIGHT \
         "${OPTIONS[@]}" \
         2>$temp_file

  # Get the exit status and selection
  local exit_status=$?
  local selection=$(cat $temp_file)
  rm -f $temp_file

  # Clear screen after dialog
  clear

  # If ESC or Cancel was pressed, exit
  if [ $exit_status -ne 0 ]; then
    echo "Operation cancelled." >&2
    return 0
  fi

  # Process the selection
  case $selection in
    "shell")
      echo "Starting interactive shell for $image_tag..." >&2
      # Use direct docker run, assuming jetson-containers is not needed here
      docker run -it --rm --gpus all "$image_tag" bash
      return $?
      ;;
    "verify")
      verify_container_apps "$image_tag" "quick" # Function from verification.sh
      return $?
      ;;
    "full")
      verify_container_apps "$image_tag" "all" # Function from verification.sh
      return $?
      ;;
    "list")
      list_installed_apps "$image_tag" # Function from verification.sh
      return $?
      ;;
    "skip"|"")
      echo "Skipping post-build container action." >&2
      return 0
      ;;
    *)
      echo "Invalid choice '$selection'. Skipping container action." >&2
      return 0
      ;;
  esac
}

# =========================================================================
# Function: Show post-build menu (Text version - fallback)
# Arguments: $1 = image tag to operate on
# Returns: The exit status of the chosen operation
# =========================================================================
show_text_menu() {
  local image_tag=$1

  # Offer options for what to do with the image
  echo "--------------------------------------------------"
  echo "Post-Build Options for Image: $image_tag"
  echo "--------------------------------------------------"
  echo "1) Start an interactive shell"
  echo "2) Run quick verification (common tools and packages)"
  echo "3) Run full verification (all system packages, may be verbose)"
  echo "4) List installed apps in the container"
  echo "5) Skip (do nothing)"

  read -p "Enter your choice [1-5, default: 2]: " user_choice
  user_choice=${user_choice:-2} # Default to quick verification

  case $user_choice in
    1)
      echo "Starting interactive shell for $image_tag..." >&2
      docker run -it --rm --gpus all "$image_tag" bash
      return $?
      ;;
    2)
      verify_container_apps "$image_tag" "quick" # Function from verification.sh
      return $?
      ;;
    3)
      verify_container_apps "$image_tag" "all" # Function from verification.sh
      return $?
      ;;
    4)
      list_installed_apps "$image_tag" # Function from verification.sh
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
}

# =========================================================================
# Function: Show post-build menu (main entry point)
# Arguments: $1 = final image tag to operate on
# Returns: 0 if successful, non-zero otherwise
# =========================================================================
show_post_build_menu() {
  local image_tag=$1

  echo "--------------------------------------------------" >&2
  echo "Final Image Built: $image_tag" >&2
  echo "--------------------------------------------------" >&2

  # Verify the image exists before offering options
  if ! verify_image_exists "$image_tag"; then # Function from docker_helpers.sh
    echo "Error: Final image $image_tag not found locally, cannot proceed with post-build actions." >&2
    return 1
  fi

  # Check if dialog is installed and use it; otherwise fall back to basic prompt
  if check_install_dialog; then # Function from utils.sh
    # Dialog-based menu
    show_dialog_menu "$image_tag"
    return $?
  else
    # Fall back to original text-based menu
    show_text_menu "$image_tag"
    return $?
  fi
}

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── build_ui.sh        <- THIS FILE
# └── ...                        <- Other project files
#
# Description: UI functions for interactive build process, dialog and prompt handling, .env management, and post-build menu.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250422-083100-BUIU
