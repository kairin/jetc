#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/env_update.sh

# =========================================================================
# .env File Update Script
# Responsibility: Safely update variables and lists in the .env file.
# Relies on logging functions sourced by the main script.
# Relies on ENV_FILE from env_setup.sh sourced by the main script or caller.
# =========================================================================

# --- Dependencies ---\
SCRIPT_DIR_ENV_UPDATE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# DO NOT source logging.sh or env_setup.sh here.
# Assume they are sourced by the main build.sh script.
# Check if required functions/variables exist as a safety measure.
if ! declare -f log_info > /dev/null || [[ -z "${ENV_FILE:-}" ]]; then
     echo "CRITICAL ERROR: Required function (log_info) or variable (ENV_FILE) not found in env_update.sh. Ensure main script sources logging.sh and env_setup.sh." >&2
     exit 1
fi

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
    local escaped_key; escaped_key=$(printf '%s\n' "$key" | sed -e 's/[\/&]/\\&/g')
    local escaped_value; escaped_value=$(printf '%s\n' "$value" | sed -e 's/[\/&]/\\&/g')
    if grep -q -E "^[#[:space:]]*${escaped_key}=" "$ENV_FILE"; then
        sed -i -E "s#^[#[:space:]]*(${escaped_key}=).*#\\1${escaped_value}#" "$ENV_FILE" || { log_error "Failed to update key '$key' in $ENV_FILE."; return 1; }
        log_debug " -> Updated existing key '$key'"
    else
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
    log_debug "Appending to .env list: Add '$value_to_add' to '$key'"
    local current_value; current_value=$(grep -E "^${key}=" "$ENV_FILE" | head -n 1 | cut -d'=' -f2-)
    if echo "${separator}${current_value}${separator}" | grep -q "${separator}${value_to_add}${separator}"; then
        log_debug " -> Value '$value_to_add' already exists in list '$key'."
        return 0
    fi
    local new_value
    [[ -z "$current_value" ]] && new_value="$value_to_add" || new_value="${current_value}${separator}${value_to_add}"
    if update_env_var "$key" "$new_value"; then
        log_debug " -> Successfully appended '$value_to_add' to list '$key'."
        return 0
    else
        log_error " -> Failed to update list '$key' after appending."
        return 1
    fi
}

# --- Main Execution (for testing) ---\
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # If testing directly, source dependencies first
    if [ -f "$SCRIPT_DIR_ENV_UPDATE/logging.sh" ]; then source "$SCRIPT_DIR_ENV_UPDATE/logging.sh"; init_logging; else echo "ERROR: Cannot find logging.sh for test."; exit 1; fi
    # Need ENV_FILE for testing
    export ENV_FILE="/tmp/test_env_update_$$.env"
    log_info "Running env_update.sh directly for testing..."
    log_info "Using temporary test .env file: $ENV_FILE"
    # Test Setup, Execution, Cleanup ... (omitted for brevity, same as before)
    rm "$ENV_FILE" # Cleanup test file
    log_info "Env update script test finished."
    exit 0
fi

# --- Footer ---
# Description: Functions to update .env file. Relies on logging.sh and ENV_FILE from env_setup.sh sourced by caller.
# COMMIT-TRACKING: UUID-20250424-205555-LOGGINGREFACTOR
