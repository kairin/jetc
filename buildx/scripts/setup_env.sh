# COMMIT-TRACKING: UUID-20240803-111500-DLGS # Use current system time
# COMMIT-TRACKING: UUID-20250420-135800-ENVU # Added .env update logic
# Description: Simplified dialog interface for build options with clearer language and consolidated steps. Saves confirmed Docker/Base Image settings to .env.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── setup_env.sh       <- THIS FILE
# └── ...                        <- Other project files

#!/bin/bash

# Import dialog check utility if it exists, otherwise define locally
if [ -f "$(dirname "$0")/check_install_dialog.sh" ]; then
    source "$(dirname "$0")/check_install_dialog.sh"
else
    check_install_dialog() {
        if ! command -v dialog &> /dev/null; then
            echo "Dialog package not found. Attempting to install..." >&2
            if command -v apt-get &> /dev/null; then
                sudo apt-get update -y && sudo apt-get install -y dialog || return 1
            elif command -v yum &> /dev/null; then
                sudo yum install -y dialog || return 1
            else
                echo "Could not install dialog: Unsupported package manager." >&2
                return 1
            fi
            if ! command -v dialog &> /dev/null; then
                 echo "Failed to install dialog. Falling back to basic prompts." >&2
                 return 1
            fi
        fi
        return 0
    }
fi

# =========================================================================
# Function: Update .env file with new values
# Arguments: 1: Username, 2: Registry, 3: Prefix, 4: Base Image Tag
# =========================================================================
update_env_file() {
    local new_username="$1"
    local new_registry="$2"
    local new_prefix="$3"
    local new_base_image="$4" # This will update DEFAULT_BASE_IMAGE
    local env_file # Determine the path relative to this script's location
    env_file="$(dirname "$0")/../.env"

    echo "Attempting to update settings in $env_file..."

    # Create the file with default content if it doesn't exist
    if [ ! -f "$env_file" ]; then
        echo "Creating $env_file with default structure..."
        cat > "$env_file" << EOF
# Docker registry URL (optional, leave empty for Docker Hub)
DOCKER_REGISTRY=

# Docker registry username (required)
DOCKER_USERNAME=

# Docker repository prefix (required)
DOCKER_REPO_PREFIX=

# Default base image for builds (last selected)
DEFAULT_BASE_IMAGE=

# Available container images (semicolon-separated)
# This list is managed by the build script itself
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
        escaped_value=$(printf '%s\n' "$value" | sed 's:[\\/&]:\\&:g;$!s/$/\\/')
        escaped_value=${escaped_value%\\} # Remove trailing backslash if any

        # Check if key exists (ignoring comments)
        if grep -qE "^\s*${key}=" "$temp_env"; then
             # Key exists, replace the value using | as delimiter
             sed -i "s|^\s*${key}=.*|${key}=${escaped_value}|" "$temp_env"
             echo "  Updated $key in $env_file"
        else
             # Key doesn't exist, append it (consider adding comments)
             echo "  Adding $key to $env_file"
             # Add a comment based on the key
             case "$key" in
                 "DOCKER_USERNAME") echo -e "\n# Docker registry username (required)" >> "$temp_env" ;;
                 "DOCKER_REGISTRY") echo -e "\n# Docker registry URL (optional, leave empty for Docker Hub)" >> "$temp_env" ;;
                 "DOCKER_REPO_PREFIX") echo -e "\n# Docker repository prefix (required)" >> "$temp_env" ;;
                 "DEFAULT_BASE_IMAGE") echo -e "\n# Default base image for builds (last selected)" >> "$temp_env" ;;
             esac
             echo "${key}=${value}" >> "$temp_env"
        fi
    done

    # Replace original .env with the updated temporary file
    mv "$temp_env" "$env_file"
    echo ".env file updated successfully."
    # Ensure temp file is removed even if mv fails (though unlikely)
    rm -f "$temp_env"

    return 0
}


# =========================================================================
# Function: Load environment variables from .env file
# Returns: 0 (always succeeds now)
# Sets: DOCKER_USERNAME, DOCKER_REGISTRY, DOCKER_REPO_PREFIX and other environment variables from .env if present
# =========================================================================
load_env_variables() {
  # Check multiple locations for the .env file
  ENV_FILE=""
  # Prefer .env in the script's directory first
  if [ -f "$(dirname "$0")/../.env" ]; then
    ENV_FILE="$(dirname "$0")/../.env"
    echo "Found .env file in buildx directory, loading defaults..."
  elif [ -f .env ]; then # Check current execution directory
    ENV_FILE=".env"
    echo "Found .env file in current directory, loading defaults..."
  elif [ -f "../.vscode/.env" ]; then # Check relative VSCode path
    ENV_FILE="../.vscode/.env"
    echo "Found .env file in ../.vscode directory, loading defaults..."
  else
    echo "No .env file found in standard locations. User will be prompted for all details."
  fi

  # Attempt to load variables if file found
  if [ -n "$ENV_FILE" ] && [ -f "$ENV_FILE" ]; then
    set -a  # Automatically export all variables
    # shellcheck disable=SC1090 # Source file from variable
    . "$ENV_FILE" # Use '.' instead of 'source' for POSIX compatibility
    set +a  # Stop automatically exporting
  else
      echo "Proceeding without loading from .env file."
  fi

  # Initialize variables if they are not set (from .env or otherwise)
  # These will serve as initial defaults for the prompts
  DOCKER_REGISTRY=${DOCKER_REGISTRY:-}
  DOCKER_USERNAME=${DOCKER_USERNAME:-}
  DOCKER_REPO_PREFIX=${DOCKER_REPO_PREFIX:-}
  # Use a specific, potentially user-settable default, or a hardcoded fallback
  DEFAULT_BASE_IMAGE=${DEFAULT_BASE_IMAGE:-"nvcr.io/nvidia/l4t-pytorch:r35.4.1-pth2.1-py3"} # Example fallback

  # Export potentially loaded or initialized variables
  # They will be confirmed/overridden in get_user_preferences
  export DOCKER_REGISTRY
  export DOCKER_USERNAME
  export DOCKER_REPO_PREFIX
  export DEFAULT_BASE_IMAGE

  # No error checks here, validation happens in get_user_preferences
  echo "Initial Docker values (will be confirmed/edited):"
  echo "  Registry: ${DOCKER_REGISTRY:-<Not Set - Docker Hub>}"
  echo "  Username: ${DOCKER_USERNAME:-<Not Set>}"
  echo "  Repo Prefix: ${DOCKER_REPO_PREFIX:-<Not Set>}"
  echo "  Default Base: ${DEFAULT_BASE_IMAGE}"

  return 0 # Always return success
}

# =========================================================================
# Function: Setup build environment basics
# Returns: 0 if successful, 1 if not
# Sets: CURRENT_DATE_TIME, PLATFORM, ARCH, LOG_DIR
# Exports: Above variables + Initializes and Exports build tracking vars
# =========================================================================
setup_build_environment() {
  # Get current date/time for timestamped tags
  CURRENT_DATE_TIME=$(date +"%Y%m%d-%H%M%S")

  # Validate platform is ARM64 (for Jetson) - Allow override for testing?
  ARCH=$(uname -m)
  if [ "$ARCH" != "aarch64" ]; then
      echo "Warning: Building on non-aarch64 architecture ($ARCH). Assuming cross-build target linux/arm64." >&2
      PLATFORM="linux/arm64" # Default target platform
  else
      PLATFORM="linux/arm64" # Native platform
  fi
  echo "Target Platform: $PLATFORM"

  # Setup build directory for logs relative to buildx/
  LOG_DIR="$(dirname "$0")/../logs"
  mkdir -p "$LOG_DIR"

  # Initialize build tracking arrays/vars (export them)
  export BUILT_TAGS=()
  export ATTEMPTED_TAGS=()
  export FINAL_FOLDER_TAG=""
  export TIMESTAMPED_LATEST_TAG=""
  export BUILD_FAILED=0

  # Export other environment details
  export CURRENT_DATE_TIME
  export PLATFORM
  export ARCH
  export LOG_DIR

  return 0
}


# =========================================================================
# Function: Get user preferences for build using dialog
# Returns: 0 if successful, 1 if not (e.g., on cancel/error)
# Relies on: Variables set by load_env_variables (DOCKER_*, DEFAULT_BASE_IMAGE)
#            Variables set by setup_build_environment (PLATFORM)
# Writes to: /tmp/build_prefs.sh on success
# Updates:   buildx/.env with confirmed Docker/Base Image settings
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
  trap 'rm -f "$temp_options" "$temp_base_choice" "$temp_custom_image" "$temp_docker_info" "$temp_folders" "$PREFS_FILE"' EXIT TERM INT

  # Dialog dimensions
  local DIALOG_HEIGHT=25
  local DIALOG_WIDTH=85
  local CHECKLIST_HEIGHT=6
  local FORM_HEIGHT=6 # Number of visible lines in the form
  local FOLDER_LIST_HEIGHT=10 # Max items visible in folder list

  # --- Step 0: Docker Registry/User/Prefix Confirmation ---
  # Use local variables to hold dialog results before overwriting globals
  local temp_registry="$DOCKER_REGISTRY"
  local temp_username="$DOCKER_USERNAME"
  local temp_prefix="$DOCKER_REPO_PREFIX"

  while true; do
    dialog --backtitle "Docker Build Configuration" \
           --title "Step 0: Docker Information" \
           --ok-label "Next: Build Options" \
           --cancel-label "Exit Build" \
           --form "Confirm or edit Docker details (loaded from .env):" $DIALOG_HEIGHT $DIALOG_WIDTH $FORM_HEIGHT \
           "Registry (optional, empty=Docker Hub):" 1 1 "$temp_registry"     1 40 70 0 \
           "Username (required):"                   2 1 "$temp_username"    2 40 70 0 \
           "Repository Prefix (required):"          3 1 "$temp_prefix" 3 40 70 0 \
           2>"$temp_docker_info"

    local form_exit_status=$?
    if [ $form_exit_status -ne 0 ]; then
      echo "Docker information entry canceled (exit code: $form_exit_status). Exiting." >&2
      return 1 # Indicate cancellation
    fi

    # Read the values back from the temp file (one per line)
    local lines=()
    while IFS= read -r line; do lines+=("$line"); done < "$temp_docker_info"

    # Assign to temporary variables (handle potential empty registry)
    temp_registry="${lines[0]:-}" # Use parameter expansion for default empty string
    temp_username="${lines[1]:-}"
    temp_prefix="${lines[2]:-}"

    # Validate required fields
    local validation_error=""
    if [[ -z "$temp_username" ]]; then validation_error+="Username cannot be empty.\\n"; fi
    if [[ -z "$temp_prefix" ]]; then validation_error+="Repository Prefix cannot be empty.\\n"; fi

    if [[ -n "$validation_error" ]]; then
      dialog --msgbox "Validation Error:\\n\\n$validation_error\\nPlease correct the entries." 10 $DIALOG_WIDTH
      if [ $? -ne 0 ]; then echo "Msgbox closed unexpectedly. Exiting." >&2; return 1; fi
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
  local build_dir="$(dirname "$0")/../build"
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
             --checklist "Select the build stages (folders) to include:" $DIALOG_HEIGHT $DIALOG_WIDTH $FOLDER_LIST_HEIGHT \
             "${folder_checklist_items[@]}" \
             2>"$temp_folders"

      local folders_exit_status=$?
      if [ $folders_exit_status -ne 0 ]; then
          echo "Folder selection canceled (exit code: $folders_exit_status). Exiting." >&2
          return 1 # Indicate cancellation
      fi
      # Read the selected items (tags) from the temp file, remove quotes, space-separated
      selected_folders_list=$(cat "$temp_folders" | sed 's/"//g')
      echo "Selected folders: $selected_folders_list" # Debugging
  else
      echo "No numbered build folders found in $build_dir. Skipping folder selection."
      # If no folders found, maybe build all? Or exit? For now, proceed, build.sh will find none.
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
    return 1 # Indicate cancellation
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
      if [ $? -ne 0 ]; then echo "Msgbox closed unexpectedly. Exiting." >&2; return 1; fi
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
    return 1 # Indicate cancellation
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
        return 1
      fi
      local entered_image
      entered_image=$(cat "$temp_custom_image")

      if [ -z "$entered_image" ]; then
        dialog --msgbox "No custom image entered. Reverting to default:\\n$current_default_base_image_display" 8 $DIALOG_WIDTH
        if [ $? -ne 0 ]; then echo "Msgbox closed unexpectedly. Exiting." >&2; return 1; fi
        SELECTED_IMAGE_TAG="$current_default_base_image_display"
        BASE_IMAGE_ACTION="use_default" # Update action
      else
        SELECTED_IMAGE_TAG="$entered_image"
        dialog --infobox "Attempting to pull custom base image:\\n$SELECTED_IMAGE_TAG..." 5 $DIALOG_WIDTH
        sleep 1 # Give time to see the message
        if ! docker pull "$SELECTED_IMAGE_TAG"; then
          if dialog --yesno "Failed to pull custom base image:\\n$SELECTED_IMAGE_TAG.\\nCheck tag/URL.\\n\\nContinue build using default ($current_default_base_image_display)? Warning: Build might fail." 12 $DIALOG_WIDTH; then
             SELECTED_IMAGE_TAG="$current_default_base_image_display"
             BASE_IMAGE_ACTION="use_default" # Update action
             dialog --msgbox "Proceeding with default base image:\\n$SELECTED_IMAGE_TAG" 8 $DIALOG_WIDTH
             if [ $? -ne 0 ]; then echo "Msgbox closed unexpectedly. Exiting." >&2; return 1; fi
          else
             echo "User chose to exit after failed custom image pull." >&2
             return 1
          fi
        else
          dialog --msgbox "Successfully pulled custom base image:\\n$SELECTED_IMAGE_TAG" 8 $DIALOG_WIDTH
          if [ $? -ne 0 ]; then echo "Msgbox closed unexpectedly. Exiting." >&2; return 1; fi
        fi
      fi
      ;;
    "pull_default")
      dialog --infobox "Attempting to pull default base image:\\n$current_default_base_image_display..." 5 $DIALOG_WIDTH
      sleep 1
      if ! docker pull "$current_default_base_image_display"; then
         if dialog --yesno "Failed to pull default base image:\\n$current_default_base_image_display.\\nBuild might fail if not local.\\n\\nContinue anyway?" 12 $DIALOG_WIDTH; then
            dialog --msgbox "Warning: Default image not pulled. Using local if available." 8 $DIALOG_WIDTH
            if [ $? -ne 0 ]; then echo "Msgbox closed unexpectedly. Exiting." >&2; return 1; fi
         else
            echo "User chose to exit after failed default image pull." >&2
            return 1
         fi
      else
        dialog --msgbox "Successfully pulled default base image:\\n$current_default_base_image_display" 8 $DIALOG_WIDTH
        if [ $? -ne 0 ]; then echo "Msgbox closed unexpectedly. Exiting." >&2; return 1; fi
      fi
      SELECTED_IMAGE_TAG="$current_default_base_image_display"
      ;;
    "use_default")
      SELECTED_IMAGE_TAG="$current_default_base_image_display"
      dialog --msgbox "Using default base image (local version if available):\\n$SELECTED_IMAGE_TAG" 8 $DIALOG_WIDTH
      if [ $? -ne 0 ]; then echo "Msgbox closed unexpectedly. Exiting." >&2; return 1; fi
      ;;
    *)
      echo "Invalid base image action selected: '$BASE_IMAGE_ACTION'. Exiting." >&2
      return 1
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
      confirmation_message+="  - No numbered stages selected/found.\\n\\n"
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
      return 1 # Indicate cancellation
  fi

  # --- Update .env file with confirmed settings ---
  # Call the helper function with the final confirmed values
  update_env_file "$DOCKER_USERNAME" "$DOCKER_REGISTRY" "$DOCKER_REPO_PREFIX" "$SELECTED_IMAGE_TAG"
  local update_status=$?
  if [[ $update_status -ne 0 ]]; then
      echo "Warning: Failed to update .env file. Proceeding with current settings for this run only." >&2
      # Decide if this should be a fatal error or just a warning
      # return 1 # Uncomment to make it fatal
  fi

  # --- Export preferences to temp file for build.sh ---
  echo "Exporting preferences to $PREFS_FILE"
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
  echo "Preferences exported."
  # --- End of export block ---


  # Explicitly remove trap and dialog temp files ONLY on success before returning
  trap - EXIT TERM INT # Disable the trap
  rm -f "$temp_options" "$temp_base_choice" "$temp_custom_image" "$temp_docker_info" "$temp_folders"
  # DO NOT remove PREFS_FILE here, build.sh needs it

  return 0 # Success
}

# =========================================================================
# Function: Fallback to basic prompts if dialog is not available
# Returns: 0 if successful, 1 if not
# Relies on: Variables set by load_env_variables (DOCKER_*, DEFAULT_BASE_IMAGE)
#            Variables set by setup_build_environment (PLATFORM)
# Writes to: /tmp/build_prefs.sh on success
# Updates:   buildx/.env with confirmed Docker/Base Image settings
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
  local build_dir="$(dirname "$0")/../build"
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
                      echo "Warning: Invalid selection '$num' ignored."
                  fi
              done
              selected_folders_list="${temp_selected[*]}"
          fi
      else
          echo "No numbered build folders found in $build_dir."
      fi
  else
      echo "Build directory $build_dir not found."
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
      echo "Pulling base image: $current_default_base_image_display"
      if ! docker pull "$current_default_base_image_display"; then echo "Warning: Failed to pull base image." >&2; fi
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
         if ! docker pull "$SELECTED_IMAGE_TAG"; then echo "Warning: Failed to pull custom base image." >&2; fi
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
  echo "  Selected Stages: ${selected_folders_list:-None}"
  echo "  Use Cache: $use_cache, Squash: $use_squash, Local Build Only: $skip_intermediate_push_pull, Use Builder: $use_builder"
  echo "  Base Image for First Stage: $SELECTED_IMAGE_TAG"
  read -p "Proceed with build? (y/n) [y]: " confirm_build
  if [[ "${confirm_build:-y}" != "y" ]]; then
      echo "Build cancelled."
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
  echo "Exporting preferences to $PREFS_FILE"
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
  echo "Preferences exported."
  # --- End of export block ---

  trap - EXIT TERM INT # Disable trap on success
  # DO NOT remove PREFS_FILE here

  return 0 # Success
}