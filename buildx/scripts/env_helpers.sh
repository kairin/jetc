#!/bin/bash

# Canonical .env helpers for Jetson Container build system

SCRIPT_DIR_ENV="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ENV_CANONICAL is defined in utils.sh

# Source utils.sh to get ENV_CANONICAL and other utilities
# shellcheck disable=SC1091
source "$SCRIPT_DIR_ENV/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }
# Source logging functions if available (might be sourced later by main script)
# shellcheck disable=SC1091
# source "$SCRIPT_DIR_ENV/env_setup.sh" 2>/dev/null || true # Ensure this line remains commented


# =========================================================================
# Function: Load environment variables from .env file safely
# Exports: All valid variables found in the .env file.
# Returns: 0 (always succeeds, variables might be empty if file not found)
# =========================================================================
load_env_variables() {
    log_debug "Unsetting common env vars before loading."
    # Unset potentially problematic variables before loading to avoid persistence
    # List common variables expected to be loaded
    unset DOCKER_USERNAME DOCKER_REGISTRY DOCKER_REPO_PREFIX DEFAULT_BASE_IMAGE AVAILABLE_IMAGES
    unset DEFAULT_IMAGE_NAME DEFAULT_ENABLE_X11 DEFAULT_ENABLE_GPU DEFAULT_MOUNT_WORKSPACE DEFAULT_USER_ROOT

    if [ -f "$ENV_CANONICAL" ]; then
        log_debug "Loading environment variables from $ENV_CANONICAL"
        # Read the file line by line, exporting valid assignments
        while IFS='=' read -r key value; do
            # Trim leading/trailing whitespace from key and value
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            # Skip comments and empty keys
            [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue

            # Check if the key is a valid Bash variable name
            if [[ "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                # Direct export is safer than eval
                export "$key=$value"
                log_debug "Loaded: $key"
            else
                 log_debug "Skipped invalid key: $key"
            fi
        done < <(grep -vE '^\s*#' "$ENV_CANONICAL" | grep '=') # Filter comments/blanks, ensure '=' exists
    else
        log_warning "Environment file $ENV_CANONICAL not found." # Use log_warning
    fi

    # Ensure required/expected variables are exported, setting defaults if they weren't loaded
    log_debug "Setting defaults for potentially missing env vars."
    export DOCKER_USERNAME="${DOCKER_USERNAME:-}"
    export DOCKER_REGISTRY="${DOCKER_REGISTRY:-}"
    export DOCKER_REPO_PREFIX="${DOCKER_REPO_PREFIX:-}"
    export DEFAULT_BASE_IMAGE="${DEFAULT_BASE_IMAGE:-nvcr.io/nvidia/l4t-pytorch:r35.4.1-py3}" # Example default
    export AVAILABLE_IMAGES="${AVAILABLE_IMAGES:-}"
    export DEFAULT_IMAGE_NAME="${DEFAULT_IMAGE_NAME:-}"
    export DEFAULT_ENABLE_X11="${DEFAULT_ENABLE_X11:-on}"
    export DEFAULT_ENABLE_GPU="${DEFAULT_ENABLE_GPU:-on}"
    export DEFAULT_MOUNT_WORKSPACE="${DEFAULT_MOUNT_WORKSPACE:-on}"
    export DEFAULT_USER_ROOT="${DEFAULT_USER_ROOT:-on}"
    log_debug "Finished loading environment variables."
    return 0 # Explicitly return 0
}

# =========================================================================
# Function: Get the value of a specific variable from .env file
# Arguments: $1 = Variable name
# Returns: Value of the variable or empty string if not found/file missing
# =========================================================================
get_env_variable() {
    local var_name="$1"
    local value=""
    log_debug "Getting env variable: $var_name"
    if [[ -z "$var_name" ]]; then
        log_debug "Called with empty var_name."
        echo ""
        return
    fi
    if [ -f "$ENV_CANONICAL" ]; then
        # Grep for the exact variable name at the beginning of a line, followed by '='
        # Use head -n 1 in case of duplicates (shouldn't happen in clean .env)
        value=$(grep -E "^\s*${var_name}\s*=" "$ENV_CANONICAL" | head -n 1 | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        log_debug "Found value: '$value'"
    else
        log_debug ".env file not found."
    fi
    echo "$value"
}

# =========================================================================
# Function: Update or add a specific variable in the .env file
# Arguments: $1 = Variable name, $2 = New value
# Returns: 0 on success, 1 on failure (e.g., file not writable)
# =========================================================================
update_env_variable() {
    local var_name="$1"
    local new_value="$2"

    if [[ -z "$var_name" ]]; then
        log_error "update_env_variable called with empty variable name." # Use log_error
        return 1
    fi
    if [[ ! "$var_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        log_error "update_env_variable called with invalid variable name: $var_name" # Use log_error
        return 1
    fi

    log_debug "Updating $var_name to '$new_value' in $ENV_CANONICAL"

    # Ensure the .env file exists, create if not
    if [ ! -f "$ENV_CANONICAL" ]; then
        log_debug "Creating $ENV_CANONICAL as it does not exist."
        touch "$ENV_CANONICAL" || { log_error "Failed to create $ENV_CANONICAL"; return 1; } # Use log_error
        # Add header for new file
        echo "# Environment variables for Jetson Container build/run system" > "$ENV_CANONICAL"
        echo "" >> "$ENV_CANONICAL"
    fi

    # Backup .env before making changes
    log_debug "Backing up $ENV_CANONICAL"
    cp "$ENV_CANONICAL" "$ENV_CANONICAL.bak.$(date +%Y%m%d-%H%M%S)"

    local temp_file
    temp_file=$(mktemp) || { log_error "Failed to create temp file for update."; return 1; } # Use log_error
    trap 'rm -f "$temp_file"' RETURN

    local found=0
    # Process the file line by line
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Check if the line starts with the variable name followed by '='
        if [[ "$line" =~ ^\s*${var_name}\s*= ]]; then
            log_debug "Replacing line for $var_name"
            echo "${var_name}=${new_value}" >> "$temp_file" # Write updated line
            found=1
        else
            echo "$line" >> "$temp_file" # Copy other lines as-is
        fi
    done < "$ENV_CANONICAL"

    # If the variable was not found, append it to the end
    if [[ $found -eq 0 ]]; then
        log_debug "Variable $var_name not found, appending to $ENV_CANONICAL"
        echo "" >> "$temp_file" # Ensure newline before appending
        echo "# Added by script on $(date)" >> "$temp_file"
        echo "${var_name}=${new_value}" >> "$temp_file"
    fi

    # Replace the original file with the updated temporary file
    log_debug "Moving temp file to $ENV_CANONICAL"
    mv "$temp_file" "$ENV_CANONICAL"
    if [[ $? -ne 0 ]]; then
        log_error "Failed to move temp file to $ENV_CANONICAL" # Use log_error
        # Attempt to restore backup?
        return 1
    fi

    log_debug "Successfully updated $var_name in $ENV_CANONICAL"
    return 0
}

# =========================================================================
# Function: Get AVAILABLE_IMAGES from .env as a bash array
# Returns: Prints space-separated image names (suitable for array assignment)
# =========================================================================
get_available_images_array() {
    log_debug "Getting AVAILABLE_IMAGES as array."
    local images_str
    images_str=$(get_env_variable "AVAILABLE_IMAGES")
    if [[ -n "$images_str" ]]; then
        # Split by semicolon, handle potential empty elements if ;; occurs
        local IFS=';'
        local -a images_array=($images_str)
        # Filter out empty elements that might result from leading/trailing/double semicolons
        local -a filtered_array=()
        for img in "${images_array[@]}"; do
            if [[ -n "$img" ]]; then
                filtered_array+=("$img")
            fi
        done
        log_debug "Found images: ${filtered_array[*]}"
        echo "${filtered_array[@]}" # Print space-separated for array assignment
    else
        log_debug "AVAILABLE_IMAGES is empty or not set."
        echo "" # Return empty string if variable not set or empty
    fi
}

# =========================================================================
# Function: Update AVAILABLE_IMAGES in .env from a bash array
# Arguments: $@ = Array of image names
# Returns: 0 on success, 1 on failure
# =========================================================================
update_available_images() {
    local -a images_array=("$@")
    local -A seen_images # Use associative array for quick duplicate check
    local -a unique_images=()
    log_debug "Updating AVAILABLE_IMAGES with ${#images_array[@]} potential images."

    # Add images from input array, ensuring uniqueness and non-emptiness
    for img in "${images_array[@]}"; do
        if [[ -n "$img" ]] && [[ -z "${seen_images[$img]}" ]]; then
            log_debug "Adding unique image: $img"
            unique_images+=("$img")
            seen_images["$img"]=1
        elif [[ -n "$img" ]]; then
             log_debug "Skipping duplicate image: $img"
        else
             log_debug "Skipping empty image name."
        fi
    done

    # Join the unique, non-empty images with semicolons
    local images_str
    images_str=$(IFS=';'; echo "${unique_images[*]}")

    log_debug "Updating AVAILABLE_IMAGES in .env with: $images_str"
    update_env_variable "AVAILABLE_IMAGES" "$images_str"
    return $?
}

# =========================================================================
# Function: Update default run options in .env
# Arguments: $1=image, $2=x11(on/off), $3=gpu(on/off), $4=ws(on/off), $5=root(on/off)
# Returns: 0 on success, 1 on failure
# =========================================================================
update_default_run_options() {
    local image="${1:-}" x11="${2:-on}" gpu="${3:-on}" ws="${4:-on}" root="${5:-on}"
    local success=0
    log_debug "Updating default run options: Img=$image, X11=$x11, GPU=$gpu, WS=$ws, Root=$root"

    update_env_variable "DEFAULT_IMAGE_NAME" "$image" || success=1
    update_env_variable "DEFAULT_ENABLE_X11" "$x11" || success=1
    update_env_variable "DEFAULT_ENABLE_GPU" "$gpu" || success=1
    update_env_variable "DEFAULT_MOUNT_WORKSPACE" "$ws" || success=1
    update_env_variable "DEFAULT_USER_ROOT" "$root" || success=1

    if [[ $success -eq 0 ]]; then
        log_debug "Successfully updated default run options in .env"
        return 0
    else
        log_error "Error updating one or more default run options in .env" # Use log_error
        return 1
    fi
}

# --- Footer ---
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── env_helpers.sh     <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Helper functions related to environment variable management.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250425-080000-42595D
