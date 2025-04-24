#!/bin/bash
# filepath: /workspaces/jetc/buildx/scripts/verification.sh

# =========================================================================
# Container Verification Script
# Responsibility: Functions to check installed apps/packages INSIDE a container,
#                 and functions to LAUNCH these checks FROM the host.
# =========================================================================

# --- Dependencies ---
SCRIPT_DIR_VERIFY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies ONLY IF they are needed by host functions AND might not be sourced by main script yet.
# Check if functions exist before sourcing, assuming main script handles primary sourcing.
if ! declare -f log_info > /dev/null; then
    echo "Warning: log_info not found in verification.sh, sourcing logging.sh for host functions." >&2
     if [ -f "$SCRIPT_DIR_VERIFY/logging.sh" ]; then source "$SCRIPT_DIR_VERIFY/logging.sh"; init_logging; else echo "ERROR: Cannot find logging.sh."; fi
fi
if ! declare -f verify_image_exists > /dev/null; then
    echo "Warning: verify_image_exists not found in verification.sh, sourcing docker_helpers.sh for host functions." >&2
     if [ -f "$SCRIPT_DIR_VERIFY/docker_helpers.sh" ]; then source "$SCRIPT_DIR_VERIFY/docker_helpers.sh"; else echo "ERROR: Cannot find docker_helpers.sh."; fi
fi
# No need to source env_setup.sh here as docker_helpers.sh sources it if needed.

# --- Internal Check Functions (Run INSIDE Container - Use echo -e) ---
V_GREEN='\033[0;32m'; V_RED='\033[0;31m'; V_YELLOW='\033[1;33m'; V_BLUE='\033[0;34m'; V_CYAN='\033[0;36m'; V_NC='\033[0m'
_check_cmd() { ...omitted for brevity... } # Same as before
_check_python_pkg() { ...omitted for brevity... } # Same as before
_check_system_tools() { ...omitted for brevity... } # Same as before
_check_ml_frameworks() { ...omitted for brevity... } # Same as before
_check_libraries() { ...omitted for brevity... } # Same as before
_check_cuda_info() {
  echo -e "\n${V_BLUE}🖥️ CUDA/GPU Information:${V_NC}"
  if _check_python_pkg torch >/dev/null; then
    local python_cmd="python3"; command -v $python_cmd &> /dev/null || python_cmd="python"
    if command -v $python_cmd &> /dev/null; then
      echo -e "PyTorch CUDA available: ..."
      if $python_cmd -c "import torch; exit(0 if torch.cuda.is_available() else 1)"; then
        echo "CUDA Device count: ..."
        echo "CUDA Version (PyTorch): ..."
      fi # Missing closing 'fi' for the inner python check
    fi # Missing closing 'fi' for the outer python check
  fi # Missing closing 'fi' for the torch check
}_list_system_packages() { ...omitted for brevity... } # Same as before
_list_python_packages() { ...omitted for brevity... } # Same as before
_list_installed_apps() { ...omitted for brevity... } # Same as before
run_verification_checks() { ...omitted for brevity... } # Same as before

# --- Launcher Functions (Run on Host - Use log_* functions) ---

# Run verification checks or list apps inside a target container image
verify_container_apps() {
  local image_tag=$1
  local mode=${2:-quick}

  # Check if required host functions exist
  if ! declare -f log_error > /dev/null || ! declare -f verify_image_exists > /dev/null; then
      echo "ERROR: Host functions (log_error, verify_image_exists) missing in verify_container_apps." >&2
      return 1
  fi

  if [[ -z "$image_tag" ]]; then log_error "No image tag provided to verify_container_apps."; return 1; fi

  # Use verify_image_exists from docker_helpers.sh (sourced above if needed)
  if ! verify_image_exists "$image_tag"; then
    log_warning "Image '$image_tag' not found locally. Cannot run verification."
    return 1
  fi

  log_info "--- Running Verification (Mode: $mode) in container: $image_tag ---"

  local container_script_path="/tmp/verify_apps.sh"

  # Execute the script inside the container
  docker run --rm --gpus all \
    -v "${BASH_SOURCE[0]}":"$container_script_path":ro \
    --entrypoint /bin/bash \
    "$image_tag" \
    "$container_script_path" "run_checks" "$mode"
  local exit_status=$?

  if [ $exit_status -ne 0 ]; then
    log_error "--- Verification (Mode: $mode) failed in container: $image_tag (Exit code: $exit_status) ---"
  else
    log_success "--- Verification (Mode: $mode) completed successfully in container: $image_tag ---"
  fi
  return $exit_status
}

# List installed apps inside a target container image
list_installed_apps() {
    local image_tag=$1
    # Check if required host function exists
    if ! declare -f log_info > /dev/null; then echo "ERROR: Host function log_info missing in list_installed_apps." >&2; return 1; fi

    log_info "Listing installed applications in: $image_tag"
    verify_container_apps "$image_tag" "list_apps" # Uses the launcher above
    return $?
}

# --- Main Execution (Entry point when script is executed directly) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # If called with "run_checks", execute the internal function (for container execution)
    if [[ "$1" == "run_checks" ]]; then
        run_verification_checks "$2" # Pass the mode
        exit $?
    else
        # If executed directly without "run_checks", show usage for host functions
        echo "This script provides functions to run checks inside containers." >&2
        echo "Usage (source the script first):" >&2
        echo "  verify_container_apps <image_tag> [mode]" >&2
        echo "  list_installed_apps <image_tag>" >&2
        echo "Modes: all, quick, tools, ml, libs, cuda, python, system, list_apps" >&2
        exit 1
    fi
fi

# --- Footer ---
# Description: Container verification checks (internal) and host launchers. Relies on logging.sh, docker_helpers.sh sourced by caller for host functions.
# COMMIT-TRACKING: UUID-20250424-205555-LOGGINGREFACTOR
