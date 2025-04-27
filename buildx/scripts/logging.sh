#!/bin/bash

# Initialize logging
init_logging() {
  local log_dir="$1"
  local build_id="$2"
  
  # Create logs directory if it doesn't exist
  mkdir -p "${log_dir}"
  
  # Set up log file paths
  export MAIN_LOG="${log_dir}/build-${build_id}.log"
  export ERROR_LOG="${log_dir}/errors-${build_id}.log"
  export SUMMARY_LOG="${log_dir}/summary-${build_id}.md"
  
  # Create empty log files
  > "${MAIN_LOG}"
  > "${ERROR_LOG}"
  
  # Create summary header
  cat > "${SUMMARY_LOG}" << EOF
# Build Summary Log - ${build_id}

## Build Information
- Date: $(date)
- Build ID: ${build_id}

## Build Stages

EOF

  echo "Logging initialized:"
  echo "- Main log: ${MAIN_LOG}"
  echo "- Error log: ${ERROR_LOG}" 
  echo "- Summary: ${SUMMARY_LOG}"
}

# Centralized logging function
log_error() {
  local message="$1"
  echo "$message" | tee -a "${ERROR_LOG}" "${MAIN_LOG}"
}

# Log command output to files while also showing on console
log_command() {
  local command="$@"
  local stage_name="${CURRENT_STAGE:-unknown}"
  
  # Record start in summary
  echo -e "### Stage: ${stage_name}\n\`\`\`" >> "${SUMMARY_LOG}"
  
  # Execute command while teeing to log files
  echo "==== EXECUTING: $command ====" | tee -a "${MAIN_LOG}"
  echo "==== STAGE: ${stage_name} START: $(date) ====" | tee -a "${MAIN_LOG}"
  
  set -o pipefail
  # Run the command, showing output on console while also capturing to logs
  # Send stderr to stdout to capture both, tee to main log
  # The key improvement here is using process substitution to avoid affecting the main output
  eval "$command" 2>&1 | tee >(cat >> "${MAIN_LOG}") >(grep -i -E 'error|warning|fail|critical' >> "${ERROR_LOG}") >/dev/null
  local result=$?
  set +o pipefail
  
  echo "==== STAGE: ${stage_name} END: $(date) [Exit: $result] ====" | tee -a "${MAIN_LOG}"
  echo -e "\`\`\`\nExit code: $result\n" >> "${SUMMARY_LOG}"
  
  return $result
}

# Set current build stage name
set_stage() {
  export CURRENT_STAGE="$1"
  echo "Setting build stage to: ${CURRENT_STAGE}" | tee -a "${MAIN_LOG}"
}

# Generate error summary
generate_error_summary() {
  local summary_file="${1:-$SUMMARY_LOG}"
  local error_file="${2:-$ERROR_LOG}"
  
  echo -e "\n## Error Summary\n" >> "$summary_file"
  
  if [[ -f "$error_file" && -s "$error_file" ]]; then
    echo "Errors and warnings detected:" >> "$summary_file"
    echo -e "\`\`\`" >> "$summary_file"
    cat "$error_file" >> "$summary_file"
    echo -e "\`\`\`" >> "$summary_file"
  else
    echo "No errors or warnings detected." >> "$summary_file"
  fi
}

# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Parent directory
# │   └── scripts/               <- Current directory
# │       └── logging.sh         <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Logging functions for capturing build output to both terminal and log files.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250422-083100-LOGS
