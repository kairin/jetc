 #!/bin/bash
 # filepath: /media/kkk/Apps/jetc/buildx/scripts/logging.sh

+# Guard variable to prevent multiple initializations
+declare -g LOGGING_INITIALIZED=0 # Use -g for global scope if needed across sourced scripts

 # ... other logging setup (colors, log levels, etc.) ...

 # =========================================================================
 # Function: Initialize Logging System
 # Creates log directory and files, sets up basic logging.
 # Arguments: None
 # Exports: MAIN_LOG_FILE, ERROR_LOG_FILE
 # Returns: 0 on success, 1 on failure
 # =========================================================================
 init_logging() {
+    # Check if already initialized
+    if [[ "${LOGGING_INITIALIZED:-0}" -eq 1 ]]; then
+        # Optionally log that we are skipping re-initialization (use debug level)
+        # log_debug "Logging already initialized. Skipping re-init." # Requires log_debug to be defined
+        return 0 # Successfully skipped
+    fi
+
     # Ensure LOG_DIR exists (should be set by env_setup.sh before this is called)
     if [[ -z "${LOG_DIR:-}" ]]; then
         echo "ERROR: LOG_DIR is not set. Cannot initialize logging." >&2
         # Exit because logging is fundamental
         exit 1
     fi
     # Create log directory if it doesn't exist
     mkdir -p "$LOG_DIR" || { echo "ERROR: Failed to create log directory: $LOG_DIR" >&2; exit 1; }

     # Define log file paths using LOG_DIR
     local timestamp
     timestamp=$(date +"%Y-%m-%d_%H-%M-%S_%Z") # Consider using UTC: date -u +"%Y-%m-%d_%H-%M-%S_%Z"
     MAIN_LOG_FILE="${LOG_DIR}/build-${timestamp}.log"
     ERROR_LOG_FILE="${LOG_DIR}/errors-${timestamp}.log"
     # Export them so other scripts might see them if needed (though using log functions is preferred)
     export MAIN_LOG_FILE ERROR_LOG_FILE

     # Initialize log files (create/truncate)
     # Use > to truncate existing files or create new ones
     echo "--- Log Start: $(date) ---" > "$MAIN_LOG_FILE" || { echo "ERROR: Failed to write to main log file: $MAIN_LOG_FILE" >&2; exit 1; }
     echo "--- Error Log Start: $(date) ---" > "$ERROR_LOG_FILE" || { echo "ERROR: Failed to write to error log file: $ERROR_LOG_FILE" >&2; exit 1; }

     # Set permissions (optional, adjust as needed)
     chmod 644 "$MAIN_LOG_FILE" "$ERROR_LOG_FILE" >/dev/null 2>&1 || true # Best effort

+    # Mark logging as initialized *before* the first log message
+    LOGGING_INITIALIZED=1
+
     # Log initialization message *after* setting up files and marking as initialized
     # Use the log_info function itself now that files are ready
     log_info "Logging initialized. Main log: $MAIN_LOG_FILE, Error log: $ERROR_LOG_FILE"

     return 0 # Indicate success
 }

 # ... other logging functions (log_info, log_error, etc.) ...

