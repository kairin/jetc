#!/bin/bash
# =========================================================================
# Docker Image Verification Utilities - KS
#
# A collection of utility functions for verifying Docker images, checking
# for installed packages, validating requirements, and ensuring images are
# properly built. These utilities handle image verification tasks such as:
# - Package verification
# - Component checking
# - Dependency validation
# - Image consistency checks
# - Software compliance validation
#
# This script is meant to be sourced by other scripts, not executed directly.
# =========================================================================

# =========================================================================
# Function: Verify required packages in an image
# Arguments: $1 = image tag, $2... = packages to check
# Returns: 0 if all packages are installed, 1 otherwise
# =========================================================================
verify_packages() {
  local image_tag="$1"
  shift
  local packages=("$@")
  
  echo "Verifying packages in $image_tag: ${packages[*]}" >&2
  
  local missing_packages=()
  
  # Run the container to check for packages
  for pkg in "${packages[@]}"; do
    echo "Checking for package: $pkg" >&2
    
    if ! docker run --rm "$image_tag" bash -c "command -v $pkg > /dev/null 2>&1 || dpkg -l | grep -q \" $pkg \"" >/dev/null 2>&1; then
      missing_packages+=("$pkg")
      echo "❌ Package $pkg not found!" >&2
    else
      echo "✅ Package $pkg verified" >&2
    fi
  done
  
  if [ ${#missing_packages[@]} -eq 0 ]; then
    echo "All required packages verified successfully" >&2
    return 0
  else
    echo "Missing packages: ${missing_packages[*]}" >&2
    return 1
  fi
}

# =========================================================================
# Function: Check for file existence in an image
# Arguments: $1 = image tag, $2... = files to check
# Returns: 0 if all files exist, 1 otherwise
# =========================================================================
verify_files() {
  local image_tag="$1"
  shift
  local files=("$@")
  
  echo "Verifying files in $image_tag: ${files[*]}" >&2
  
  local missing_files=()
  
  # Run the container to check for files
  for file in "${files[@]}"; do
    echo "Checking for file: $file" >&2
    
    if ! docker run --rm "$image_tag" bash -c "test -e $file" >/dev/null 2>&1; then
      missing_files+=("$file")
      echo "❌ File $file not found!" >&2
    else
      echo "✅ File $file verified" >&2
    fi
  done
  
  if [ ${#missing_files[@]} -eq 0 ]; then
    echo "All required files verified successfully" >&2
    return 0
  else
    echo "Missing files: ${missing_files[*]}" >&2
    return 1
  fi
}

# =========================================================================
# Function: Run a custom verification script inside a container
# Arguments: $1 = image tag, $2 = verification script path, $3... = args
# Returns: Exit code of the verification script
# =========================================================================
run_verification_script() {
  local image_tag="$1"
  local script_path="$2"
  shift 2
  local script_args=("$@")
  
  if [ ! -f "$script_path" ]; then
    echo "Error: Verification script not found: $script_path" >&2
    return 1
  fi
  
  echo "Running verification script in $image_tag: $(basename "$script_path")" >&2
  
  # Get the script filename without the path
  local script_name=$(basename "$script_path")
  
  # Create temp container, copy script, run, and remove container
  local container_id=$(docker create --entrypoint bash "$image_tag")
  docker cp "$script_path" "$container_id:/tmp/$script_name"
  docker start -a "$container_id"
  docker exec "$container_id" bash -c "chmod +x /tmp/$script_name && /tmp/$script_name ${script_args[*]}"
  local verification_status=$?
  docker rm -f "$container_id" > /dev/null
  
  if [ $verification_status -eq 0 ]; then
    echo "✅ Verification script passed successfully" >&2
  else
    echo "❌ Verification script failed with status $verification_status" >&2
  fi
  
  return $verification_status
}

# =========================================================================
# Function: Verify the image can execute basic operations
# Arguments: $1 = image tag
# Returns: 0 if all basic operations succeed, 1 otherwise
# =========================================================================
verify_basic_functionality() {
  local image_tag="$1"
  
  echo "Verifying basic functionality in $image_tag" >&2
  
  # Array of basic commands to test
  local cmds=(
    "echo 'Hello, world!'"
    "ls -la /"
    "whoami"
    "date"
    "cat /etc/os-release"
    "free -h"
    "df -h"
  )
  
  local failed_cmds=()
  
  # Run each command in the container
  for cmd in "${cmds[@]}"; do
    echo "Testing command: $cmd" >&2
    
    if ! docker run --rm "$image_tag" bash -c "$cmd" >/dev/null 2>&1; then
      failed_cmds+=("$cmd")
      echo "❌ Command failed: $cmd" >&2
    else
      echo "✅ Command succeeded: $cmd" >&2
    fi
  done
  
  if [ ${#failed_cmds[@]} -eq 0 ]; then
    echo "All basic functionality tests passed" >&2
    return 0
  else
    echo "Failed commands: ${failed_cmds[*]}" >&2
    return 1
  fi
}

# =========================================================================
# Function: Verify network connectivity from inside the container
# Arguments: $1 = image tag, $2... = hosts to check connectivity to
# Returns: 0 if all connections succeed, 1 otherwise
# =========================================================================
verify_network_connectivity() {
  local image_tag="$1"
  shift
  local hosts=("$@")
  
  # Default hosts if none provided
  if [ ${#hosts[@]} -eq 0 ]; then
    hosts=("google.com" "github.com" "dockerhub.com")
  fi
  
  echo "Verifying network connectivity in $image_tag to: ${hosts[*]}" >&2
  
  local failed_hosts=()
  
  # Check connectivity to each host
  for host in "${hosts[@]}"; do
    echo "Testing connectivity to: $host" >&2
    
    if ! docker run --rm "$image_tag" bash -c "ping -c 1 -W 5 $host" >/dev/null 2>&1; then
      failed_hosts+=("$host")
      echo "❌ Failed to connect to $host" >&2
    else
      echo "✅ Successfully connected to $host" >&2
    fi
  done
  
  if [ ${#failed_hosts[@]} -eq 0 ]; then
    echo "All network connectivity tests passed" >&2
    return 0
  else
    echo "Failed connections to: ${failed_hosts[*]}" >&2
    return 1
  fi
}

# =========================================================================
# Function: Verify image meets system requirements
# Arguments: $1 = image tag, $2 = min disk space (MB), $3 = min memory (MB)
# Returns: 0 if requirements are met, 1 otherwise
# =========================================================================
verify_system_requirements() {
  local image_tag="$1"
  local min_disk="${2:-100}"  # Default 100MB
  local min_memory="${3:-256}"  # Default 256MB
  
  echo "Verifying system requirements for $image_tag" >&2
  echo "Minimum requirements: ${min_disk}MB disk, ${min_memory}MB memory" >&2
  
  # Check disk space
  local available_disk=$(docker run --rm "$image_tag" bash -c "df -BM / | tail -1 | awk '{print \$4}'" | tr -d 'M')
  echo "Available disk space: ${available_disk}MB" >&2
  
  # Check memory (this is container runtime memory, not host memory)
  local available_memory=$(docker run --rm --memory="${min_memory}m" "$image_tag" bash -c "free -m | awk '/Mem:/ {print \$2}'" || echo 0)
  echo "Available memory: ${available_memory}MB" >&2
  
  # Verify requirements
  local requirements_met=true
  
  if [ "$available_disk" -lt "$min_disk" ]; then
    echo "❌ Insufficient disk space: ${available_disk}MB < ${min_disk}MB required" >&2
    requirements_met=false
  else
    echo "✅ Disk space requirement met" >&2
  fi
  
  if [ "$available_memory" -lt "$min_memory" ]; then
    echo "❌ Insufficient memory: ${available_memory}MB < ${min_memory}MB required" >&2
    requirements_met=false
  else
    echo "✅ Memory requirement met" >&2
  fi
  
  if [ "$requirements_met" = true ]; then
    echo "All system requirements verified successfully" >&2
    return 0
  else
    echo "System requirements not met" >&2
    return 1
  fi
}

# =========================================================================
# Function: Run a comprehensive verification test suite
# Arguments: $1 = image tag, $2 = test level (basic, standard, full)
# Returns: 0 if all tests pass, 1 if any test fails
# =========================================================================
run_verification_suite() {
  local image_tag="$1"
  local test_level="${2:-standard}"
  
  echo "Running verification test suite for $image_tag (level: $test_level)" >&2
  
  # Track test results
  local tests_failed=0
  
  # Basic level tests (quick checks)
  if [[ "$test_level" =~ ^(basic|standard|full)$ ]]; then
    echo "Running basic tests..." >&2
    
    if ! verify_basic_functionality "$image_tag"; then
      tests_failed=$((tests_failed + 1))
    fi
    
    # Define core packages that any image should have
    local core_packages=("bash" "sh" "ls" "grep")
    if ! verify_packages "$image_tag" "${core_packages[@]}"; then
      tests_failed=$((tests_failed + 1))
    fi
  fi
  
  # Standard level tests (more thorough checks)
  if [[ "$test_level" =~ ^(standard|full)$ ]]; then
    echo "Running standard tests..." >&2
    
    # Check basic network connectivity
    if ! verify_network_connectivity "$image_tag" "google.com"; then
      tests_failed=$((tests_failed + 1))
    fi
    
    # Check system requirements
    if ! verify_system_requirements "$image_tag" 50 128; then
      tests_failed=$((tests_failed + 1))
    fi
    
    # Check for important system files
    local system_files=("/etc/os-release" "/bin/bash" "/etc/passwd")
    if ! verify_files "$image_tag" "${system_files[@]}"; then
      tests_failed=$((tests_failed + 1))
    fi
  fi
  
  # Full level tests (comprehensive checks)
  if [[ "$test_level" = "full" ]]; then
    echo "Running full tests..." >&2
    
    # Extended network checks
    if ! verify_network_connectivity "$image_tag" "google.com" "github.com" "dockerhub.com"; then
      tests_failed=$((tests_failed + 1))
    fi
    
    # Run a sample application if a verification script exists
    if [ -f "verify_sample_app.sh" ]; then
      if ! run_verification_script "$image_tag" "verify_sample_app.sh"; then
        tests_failed=$((tests_failed + 1))
      fi
    fi
  fi
  
  # Report results
  if [ $tests_failed -eq 0 ]; then
    echo "✅ All verification tests passed successfully! ($test_level level)" >&2
    return 0
  else
    echo "❌ Verification failed: $tests_failed test(s) did not pass ($test_level level)" >&2
    return 1
  fi
}

# =========================================================================
# Function: Generate a verification report
# Arguments: $1 = image tag, $2 = output file (optional)
# Returns: 0 on success, 1 on failure
# =========================================================================
generate_verification_report() {
  local image_tag="$1"
  local output_file="${2:-verification_report_$(date +%Y%m%d_%H%M%S).txt}"
  
  echo "Generating verification report for $image_tag" >&2
  echo "Output file: $output_file" >&2
  
  {
    echo "================================================"
    echo "DOCKER IMAGE VERIFICATION REPORT"
    echo "================================================"
    echo "Image: $image_tag"
    echo "Date: $(date)"
    echo "================================================"
    echo
    
    echo "## IMAGE INFORMATION"
    echo "----------------------------------------"
    docker inspect "$image_tag" | grep -E 'Id|RepoTags|Created|Size|Architecture'
    echo
    
    echo "## INSTALLED PACKAGES"
    echo "----------------------------------------"
    docker run --rm "$image_tag" bash -c "if command -v dpkg &>/dev/null; then dpkg -l | grep '^ii'; elif command -v rpm &>/dev/null; then rpm -qa; elif command -v apk &>/dev/null; then apk info; else echo 'No package manager found'; fi"
    echo
    
    echo "## ENVIRONMENT VARIABLES"
    echo "----------------------------------------"
    docker run --rm "$image_tag" env | sort
    echo
    
    echo "## SYSTEM INFORMATION"
    echo "----------------------------------------"
    docker run --rm "$image_tag" bash -c "cat /etc/os-release; echo; uname -a; echo; df -h; echo; free -h"
    echo
    
    echo "## VERIFICATION TESTS"
    echo "----------------------------------------"
    if run_verification_suite "$image_tag" "standard"; then
      echo "✅ ALL VERIFICATION TESTS PASSED"
    else
      echo "❌ SOME VERIFICATION TESTS FAILED"
    fi
    echo
    
    echo "================================================"
    echo "END OF REPORT"
    echo "================================================"
  } > "$output_file"
  
  if [ -f "$output_file" ]; then
    echo "✅ Verification report generated successfully: $output_file" >&2
    return 0
  else
    echo "❌ Failed to generate verification report" >&2
    return 1
  fi
}
