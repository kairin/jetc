#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/env_update.sh

# =========================================================================
# .env File Update Script
# Responsibility: Safely update variables and lists in the .env file.
# =========================================================================

# --- Dependencies ---
SCRIPT_DIR_ENV_UPDATE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$(realpath "$SCRIPT_DIR_ENV_UPDATE/../.env")" # Canonical path to .env

# Source required scripts (use fallbacks if sourcing fails)
if [ -f "$SCRIPT_DIR_ENV_UPDATE/env_setup.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_ENV_UPDATE/env_setup.sh"
else
    echo "Warning: env_setup.sh not found. Logging/colors may be basic." >&2
    log_info() { echo "INFO: $1"; }
    log_warning() { echo "WARNING: $1" >&2; }
    log_error() { echo "ERROR: $1" >&2; }
    log_success() { echo "SUCCESS: $1"; }
    log_debug() { :; }
fi

# --- Functions --- #

# Update or add a variable in the .env file
# Input: $1 = key (variable name)
# Input: $2 = value
# Return: 0 on success, 1 on failure (e.g., file not found)
update_env_var() {
    local key="$1"
    local value="$2"

    if [ -z "$key" ]; then
        log_error "update_env_var: Key cannot be empty."
        return 1
    fi

    if [ ! -f "$ENV_FILE" ]; then
        log_warning ".env file not found at '$ENV_FILE'. Creating it."
        touch "$ENV_FILE" || { log_error "Failed to create .env file."; return 1; }
    fi

    log_debug "Updating .env: Set '$key' to '$value'"

    # Escape special characters in key and value for sed
    local escaped_key
escaped_key=$(printf '%s\n' "$key" | sed -e 's/[\/&]/\\&/g')
    local escaped_value
escaped_value=$(printf '%s\n' "$value" | sed -e 's/[\/&]/\\&/g')

    # Check if the key exists (commented or uncommented)
    if grep -q -E "^[#[:space:]]*${escaped_key}=" "$ENV_FILE"; then
        # Key exists, update it. Uncomment if necessary.
        # Use # as delimiter for sed to avoid issues with paths in values
        sed -i -E "s#^[#[:space:]]*(${escaped_key}=).*#\1${escaped_value}#" "$ENV_FILE"
        if [ $? -ne 0 ]; then
            log_error "Failed to update key '$key' in $ENV_FILE using sed."
            return 1
        fi
        log_debug " -> Updated existing key '$key' in $ENV_FILE"
    else
        # Key does not exist, add it to the end
        echo "${key}=${value}" >> "$ENV_FILE"
        if [ $? -ne 0 ]; then
            log_error "Failed to append key '$key' to $ENV_FILE."
            return 1
        fi
        log_debug " -> Added new key '$key' to $ENV_FILE"
    fi

    return 0
}

# Append a value to a list-like variable in the .env file, avoiding duplicates.
# Input: $1 = key (variable name)
# Input: $2 = value_to_add
# Input: $3 = separator (optional, defaults to semicolon ';')
# Return: 0 on success, 1 on failure
append_to_env_list() {
    local key="$1"
    local value_to_add="$2"
    local separator=${3:-;}

    if [ -z "$key" ]; then
        log_error "append_to_env_list: Key cannot be empty."
        return 1
    fi
    if [ -z "$value_to_add" ]; then
        log_warning "append_to_env_list: Value to add is empty. Nothing to do."
        return 0
    fi

    if [ ! -f "$ENV_FILE" ]; then
        log_warning ".env file not found at '$ENV_FILE'. Cannot append."
        # Optionally create the file and add the key/value? For now, fail.
        return 1
    fi

    log_debug "Appending to .env list: Add '$value_to_add' to '$key' (separator: '$separator')"

    # Read the current value (handling cases where key might be missing or commented)
    local current_value
    # Ensure we only get the uncommented value if it exists
    current_value=$(grep -E "^${key}=" "$ENV_FILE" | head -n 1 | cut -d'=' -f2-)

    # Check if the value already exists in the list
    # Use separator at beginning and end for robust matching
    if echo "${separator}${current_value}${separator}" | grep -q "${separator}${value_to_add}${separator}"; then
        log_debug " -> Value '$value_to_add' already exists in list '$key'. No changes made."
        return 0
    fi

    # Value does not exist, append it
    local new_value
    if [ -z "$current_value" ]; then
        new_value="$value_to_add"
    else
        new_value="${current_value}${separator}${value_to_add}"
    fi

    # Use update_env_var to save the new list value (this also handles uncommenting)
    if update_env_var "$key" "$new_value"; then
        log_debug " -> Successfully appended '$value_to_add' to list '$key'."
        return 0
    else
        log_error " -> Failed to update list '$key' after appending."
        return 1
    fi
}

# --- Main Execution (for testing) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_info "Running env_update.sh directly for testing..."

    # --- Test Setup --- #
    test_env_file="/tmp/test_env_update_$$.env"
    echo "# Test .env file" > "$test_env_file"
    echo "EXISTING_VAR=old_value" >> "$test_env_file"
    echo "#COMMENTED_VAR=commented_value" >> "$test_env_file"
    echo "LIST_VAR=item1;item2" >> "$test_env_file"
    echo "EMPTY_LIST=" >> "$test_env_file"
    echo "#COMMENTED_LIST=old1;old2" >> "$test_env_file"
    export ENV_FILE="$test_env_file" # Override ENV_FILE for testing
    log_info "Using temporary test .env file: $test_env_file"
    cat "$test_env_file"
    echo "--------------------"

    # --- Test Cases --- #
    log_info "Test 1: Update existing variable"
    update_env_var "EXISTING_VAR" "new_value"
    cat "$test_env_file"
    echo "--------------------"

    log_info "Test 2: Update commented variable (should uncomment)"
    update_env_var "COMMENTED_VAR" "uncommented_value"
    cat "$test_env_file"
    echo "--------------------"

    log_info "Test 3: Add new variable"
    update_env_var "NEW_VAR" "hello world"
    cat "$test_env_file"
    echo "--------------------"

    log_info "Test 4: Update variable with empty value"
    update_env_var "EXISTING_VAR" ""
    cat "$test_env_file"
    echo "--------------------"

    log_info "Test 5: Append to existing list (new item)"
    append_to_env_list "LIST_VAR" "item3"
    cat "$test_env_file"
    echo "--------------------"

    log_info "Test 6: Append to existing list (duplicate item)"
    append_to_env_list "LIST_VAR" "item2"
    cat "$test_env_file"
    echo "--------------------"

    log_info "Test 7: Append to empty list"
    append_to_env_list "EMPTY_LIST" "first_item"
    cat "$test_env_file"
    echo "--------------------"

    log_info "Test 8: Append to non-existent list (should create)"
    append_to_env_list "NEW_LIST" "initial_item"
    cat "$test_env_file"
    echo "--------------------"

    log_info "Test 9: Append with different separator"
    update_env_var "COMMA_LIST" "a,b"
    append_to_env_list "COMMA_LIST" "c" ","
    cat "$test_env_file"
    echo "--------------------"

    log_info "Test 10: Append to commented list (should uncomment and append)"
    append_to_env_list "COMMENTED_LIST" "new_item"
    cat "$test_env_file"
    echo "--------------------"

    # --- Cleanup --- #
    log_info "Cleaning up test file: $test_env_file"
    rm "$test_env_file"
    log_info "Env update script test finished."
    exit 0
fi

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── env_update.sh      <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Provides functions to safely update variables and lists in the .env file.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250424-093500-ENVUPD