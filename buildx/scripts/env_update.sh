#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/env_update.sh

# =========================================================================
# .env File Update Script
# Responsibility: Safely update variables and lists in the .env file.
# Relies on logging functions sourced by the main script.
# Relies on ENV_FILE from env_setup.sh sourced by the main script or caller.
# =========================================================================

# Set strict mode
set -euo pipefail

# --- Dependencies ---\
SCRIPT_DIR_ENV_UPDATE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# DO NOT source logging.sh or env_setup.sh here.
# Assume they are sourced by the main build.sh script.
# Check if required functions/variables exist as a safety measure.
if ! declare -f log_info > /dev/null || [[ -z "${ENV_FILE:-}" ]]; then
     # Use basic echo for critical startup errors as logging might not be ready
     echo "[CRITICAL ERROR] env_update.sh: Required function (log_info) or variable (ENV_FILE) not found. Ensure main script sources logging.sh and env_setup.sh." >&2
     exit 1
fi
# Define log_debug locally if it doesn't exist, for safety
declare -f log_debug > /dev/null || log_debug() { :; }


# --- Functions --- #

# Update or add a variable in the .env file
update_env_var() {
    local key="$1"
    local value="$2"
    if [ -z "$key" ]; then log_error "update_env_var: Key cannot be empty."; return 1; fi
    if [ ! -f "$ENV_FILE" ]; then
        log_warning ".env file not found at '$ENV_FILE'. Creating it."
        touch "$ENV_FILE" || { log_error "Failed to create .env file."; return 1; }
    fi
    log_debug "Updating .env: Set '$key' to '$value'"
    # Escape key and value for sed
    local escaped_key; escaped_key=$(printf '%s\n' "$key" | sed -e 's/[\/&]/\\&/g')
    local escaped_value; escaped_value=$(printf '%s\n' "$value" | sed -e 's/[\/&]/\\&/g')

    # Check if key exists (commented or uncommented)
    if grep -q -E "^[#[:space:]]*${escaped_key}=" "$ENV_FILE"; then
        # Update existing key using '#' as delimiter in sed to avoid issues with slashes in value
        sed -i -E "s#^[#[:space:]]*(${escaped_key}=).*#\1${escaped_value}#" "$ENV_FILE" || { log_error "Failed to update key '$key' in $ENV_FILE."; return 1; }
        log_debug " -> Updated existing key '$key'"
    else
        # Append new key if it doesn't exist
        echo "${key}=${value}" >> "$ENV_FILE" || { log_error "Failed to append key '$key' to $ENV_FILE."; return 1; }
        log_debug " -> Added new key '$key'"
    fi
    return 0
}

# Append a value to a list-like variable in the .env file, avoiding duplicates.
append_to_env_list() {
    local key="$1"; local value_to_add="$2"; local separator=${3:-;}
    if [ -z "$key" ]; then log_error "append_to_env_list: Key cannot be empty."; return 1; fi
    if [ -z "$value_to_add" ]; then log_warning "append_to_env_list: Value to add is empty."; return 0; fi
    if [ ! -f "$ENV_FILE" ]; then log_warning ".env file not found at '$ENV_FILE'. Cannot append."; return 1; fi

    log_debug "Appending to .env list: Add '$value_to_add' to '$key' (Separator: '$separator')"

    # Retrieve current value robustly
    local current_value=""
    if grep -q -E "^${key}=" "$ENV_FILE"; then
      current_value=$(grep -E "^${key}=" "$ENV_FILE" | head -n 1 | cut -d'=' -f2-)
    fi
    log_debug " -> Current value of '$key': '$current_value'"

    # Check for duplicates using the separator at both ends
    if echo "${separator}${current_value}${separator}" | grep -q "${separator}${value_to_add}${separator}"; then
        log_debug " -> Value '$value_to_add' already exists in list '$key'."
        # Ensure the variable is exported even if not changed in the file
        export "$key=$current_value"
        return 0
    fi

    # Construct new value
    local new_value
    if [[ -z "$current_value" ]]; then
        new_value="$value_to_add"
    else
        new_value="${current_value}${separator}${value_to_add}"
    fi
    log_debug " -> New value for '$key': '$new_value'"

    # Update the .env file
    if update_env_var "$key" "$new_value"; then
        log_debug " -> Successfully updated list '$key' in $ENV_FILE."
        # Export the updated variable to the current environment
        export "$key=$new_value"
        log_debug " -> Exported updated $key='$new_value'"
        return 0
    else
        log_error " -> Failed to update list '$key' after appending."
        return 1
    fi
}

# Function to update the AVAILABLE_IMAGES list in the .env file
update_available_images_in_env() {
    local new_image_tag="$1"
    if [ -z "$new_image_tag" ]; then log_error "update_available_images_in_env: new_image_tag cannot be empty."; return 1; fi
    log_debug "Updating AVAILABLE_IMAGES with: $new_image_tag"
    # Use append_to_env_list to handle adding the tag and avoiding duplicates
    # Use semicolon ';' as the separator for AVAILABLE_IMAGES
    if append_to_env_list "AVAILABLE_IMAGES" "$new_image_tag" ";"; then
        log_info "Updated AVAILABLE_IMAGES in .env with $new_image_tag"
        return 0
    else
        log_error "Failed to update AVAILABLE_IMAGES in .env for $new_image_tag"
        return 1
    fi
}


# --- Main Execution (for testing) ---\
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # If testing directly, source dependencies first
    if [ -f "$SCRIPT_DIR_ENV_UPDATE/logging.sh" ]; then source "$SCRIPT_DIR_ENV_UPDATE/logging.sh"; init_logging; else echo "ERROR: Cannot find logging.sh for test."; exit 1; fi
    # Need ENV_FILE for testing
    export ENV_FILE="/tmp/test_env_update_$$.env"
    # Mock AVAILABLE_IMAGES for testing append
    export AVAILABLE_IMAGES="image1;image2"
    echo "AVAILABLE_IMAGES=$AVAILABLE_IMAGES" > "$ENV_FILE"
    echo "OTHER_VAR=initial" >> "$ENV_FILE"

    log_info "Running env_update.sh directly for testing..."
    log_info "Using temporary test .env file: $ENV_FILE"

    log_info "*** Test 1: Update existing var ***"
    update_env_var "OTHER_VAR" "updated_value"
    grep "OTHER_VAR=updated_value" "$ENV_FILE" || log_error "Test 1 Failed"

    log_info "*** Test 2: Add new var ***"
    update_env_var "NEW_VAR" "new_value"
    grep "NEW_VAR=new_value" "$ENV_FILE" || log_error "Test 2 Failed"

    log_info "*** Test 3: Append new value to list ***"
    update_available_images_in_env "image3"
    grep "AVAILABLE_IMAGES=image1;image2;image3" "$ENV_FILE" || log_error "Test 3 Failed"
    [[ "$AVAILABLE_IMAGES" == "image1;image2;image3" ]] || log_error "Test 3 Failed (Export check)"


    log_info "*** Test 4: Append duplicate value to list ***"
    update_available_images_in_env "image2"
    grep "AVAILABLE_IMAGES=image1;image2;image3" "$ENV_FILE" || log_error "Test 4 Failed"
    [[ "$AVAILABLE_IMAGES" == "image1;image2;image3" ]] || log_error "Test 4 Failed (Export check)"


    log_info "*** Test 5: Append to empty list (simulate missing var) ***"
    rm "$ENV_FILE"; touch "$ENV_FILE" # Clear file
    export AVAILABLE_IMAGES="" # Clear exported var
    update_available_images_in_env "first_image"
    grep "AVAILABLE_IMAGES=first_image" "$ENV_FILE" || log_error "Test 5 Failed"
    [[ "$AVAILABLE_IMAGES" == "first_image" ]] || log_error "Test 5 Failed (Export check)"


    rm "$ENV_FILE" # Cleanup test file
    log_info "Env update script test finished."
    exit 0
fi

# --- Footer ---
# Description: Functions to update .env file. Ensures update_available_images_in_env is defined. Exports updated list vars.
# COMMIT-TRACKING: UUID-20250424-231500-ENVUPDATEFIX2
