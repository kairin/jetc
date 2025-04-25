#!/bin/bash
# filepath: /media/kkk/Apps/jetc/buildx/scripts/env_helpers.sh

# Canonical .env helpers for Jetson Container build system

SCRIPT_DIR_ENV="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ENV_FILE is defined and exported by env_setup.sh

# Source utils.sh for logging fallbacks if needed, but ENV_FILE comes from env_setup
# shellcheck disable=SC1091
source "$SCRIPT_DIR_ENV/utils.sh" || { echo "Error: utils.sh not found."; exit 1; }

# --- Check if required functions/variables exist (assuming they are sourced by caller) ---
if ! declare -f log_info > /dev/null || [[ -z "${ENV_FILE:-}" ]]; then
    echo "CRITICAL ERROR (env_helpers.sh): log_info function or ENV_FILE variable not found. Ensure env_setup.sh/logging.sh are sourced by the caller." >&2
    # Define minimal fallbacks
    log_info() { echo "INFO (fallback): $1"; }
    log_warning() { echo "WARNING (fallback): $1" >&2; }
    log_error() { echo "ERROR (fallback): $1" >&2; }
    log_success() { echo "SUCCESS (fallback): $1"; }
    log_debug() { :; }
fi

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

    # Use ENV_FILE defined and exported by env_setup.sh
    if [ -f "$ENV_FILE" ]; then
        log_debug "Loading environment variables from $ENV_FILE"
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
        # Use ENV_FILE
        done < <(grep -vE '^\s*#' "$ENV_FILE" | grep '=') # Filter comments/blanks, ensure '=' exists
    else
        log_warning "Environment file $ENV_FILE not found." # Use log_warning
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
    # Use ENV_FILE
    if [ -f "$ENV_FILE" ]; then
        # Grep for the exact variable name at the beginning of a line, followed by '='
        # Use head -n 1 in case of duplicates (shouldn't happen in clean .env)
        value=$(grep -E "^\s*${var_name}\s*=" "$ENV_FILE" | head -n 1 | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        log_debug "Found value: '$value'"
    else
        log_debug ".env file ($ENV_FILE) not found."
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
        log_error "update_env_variable called with empty variable name."
        return 1
    fi
    if [[ ! "$var_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        log_error "update_env_variable called with invalid variable name: $var_name"
        return 1
    fi

    # Use ENV_FILE
    log_debug "Updating $var_name to '$new_value' in $ENV_FILE"

    # Ensure the .env file exists, create if not
    if [ ! -f "$ENV_FILE" ]; then
        log_debug "Creating $ENV_FILE as it does not exist."
        touch "$ENV_FILE" || { log_error "Failed to create $ENV_FILE"; return 1; }
        # Add header for new file
        echo "# Environment variables for Jetson Container build/run system" > "$ENV_FILE"
        echo "" >> "$ENV_FILE"
    fi

    # Backup .env before making changes
    log_debug "Backing up $ENV_FILE"
    cp "$ENV_FILE" "$ENV_FILE.bak.$(date +%Y%m%d-%H%M%S)"

    # --- FIX: Use '#' as sed delimiter ---
    # Escape key and value for sed, preparing for '#' delimiter
    local escaped_key; escaped_key=$(printf '%s\n' "$var_name" | sed -e 's/[\#&]/\&/g') # Escape # and &
    local escaped_value; escaped_value=$(printf '%s\n' "$new_value" | sed -e 's/[\#&]/\&/g') # Escape # and &

    # Check if key exists (commented or uncommented)
    if grep -q -E "^[#[:space:]]*${escaped_key}=" "$ENV_FILE"; then
        # Update existing key using '#' as delimiter
        sed -i -E "s#^[#[:space:]]*(${escaped_key}=).*#\1${escaped_value}#" "$ENV_FILE"
        local sed_status=$?
        if [[ $sed_status -ne 0 ]]; then
            log_error "Failed to update key '$var_name' in $ENV_FILE using sed (exit code $sed_status)."
            return 1
        fi
        log_debug " -> Updated existing key '$var_name'"
    else
        # Append new key if it doesn't exist
        # Ensure newline before appending if file not empty
        [[ -s "$ENV_FILE" ]] && echo "" >> "$ENV_FILE"
        echo "${var_name}=${new_value}" >> "$ENV_FILE"
        local append_status=$?
         if [[ $append_status -ne 0 ]]; then
            log_error "Failed to append key '$var_name' to $ENV_FILE (exit code $append_status)."
            return 1
        fi
        log_debug " -> Added new key '$var_name'"
    fi
    # --- END FIX ---

    log_debug "Successfully updated $var_name in $ENV_FILE"
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
        log_error "Error updating one or more default run options in .env"
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
# COMMIT-TRACKING: UUID-20250426-110000-ENVHELPERFIX # New UUID for this fix
