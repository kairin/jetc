#!/bin/bash
# =========================================================================
# Docker Build UI Utilities
#
# A collection of utility functions for user interface elements when 
# building Docker images, including:
# - Terminal output formatting (colors, styles)
# - Progress indicators and spinners
# - Dialog boxes and prompts
# - User interaction functions
#
# This script is meant to be sourced by other scripts, not executed directly.
# =========================================================================

# ANSI color codes
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_PURPLE='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_WHITE='\033[0;37m'
readonly COLOR_RESET='\033[0m'
readonly COLOR_BOLD='\033[1m'

# =========================================================================
# Function: Print a colorized message
# Arguments: $1 = color, $2 = message
# =========================================================================
print_color() {
  local color="$1"
  local message="$2"
  
  echo -e "${color}${message}${COLOR_RESET}"
}

# =========================================================================
# Function: Print an error message in red
# Arguments: $1 = message
# =========================================================================
print_error() {
  print_color "${COLOR_RED}" "ERROR: $1" >&2
}

# =========================================================================
# Function: Print a warning message in yellow
# Arguments: $1 = message
# =========================================================================
print_warning() {
  print_color "${COLOR_YELLOW}" "WARNING: $1" >&2
}

# =========================================================================
# Function: Print a success message in green
# Arguments: $1 = message
# =========================================================================
print_success() {
  print_color "${COLOR_GREEN}" "SUCCESS: $1"
}

# =========================================================================
# Function: Print an info message in blue
# Arguments: $1 = message
# =========================================================================
print_info() {
  print_color "${COLOR_BLUE}" "INFO: $1"
}

# =========================================================================
# Function: Print a section header
# Arguments: $1 = header text
# =========================================================================
print_section_header() {
  local header="$1"
  local width=50
  local padding=$(( (width - ${#header} - 2) / 2 ))
  local padding_extra=$(( (width - ${#header} - 2) % 2 ))
  
  echo
  echo -e "${COLOR_CYAN}$(printf '=%.0s' $(seq 1 $width))${COLOR_RESET}"
  echo -e "${COLOR_CYAN}$(printf '=%.0s' $(seq 1 $padding)) ${COLOR_BOLD}${header}${COLOR_RESET}${COLOR_CYAN} $(printf '=%.0s' $(seq 1 $(($padding + $padding_extra))))${COLOR_RESET}"
  echo -e "${COLOR_CYAN}$(printf '=%.0s' $(seq 1 $width))${COLOR_RESET}"
  echo
}

# =========================================================================
# Function: Display a spinner animation for a background process
# Arguments: $1 = PID of the process to monitor
# =========================================================================
show_spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  
  # Save cursor position and hide cursor
  tput sc
  tput civis
  
  echo -n "Processing "
  
  while kill -0 $pid 2>/dev/null; do
    local temp=${spinstr#?}
    printf " [%c] " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b"
  done
  
  printf "    \b\b\b\b"
  
  # Restore cursor position and show cursor
  tput rc
  tput cnorm
  
  # Move to a new line
  echo
}

# =========================================================================
# Function: Display a progress bar
# Arguments: $1 = current value, $2 = max value, $3 = operation description
# =========================================================================
show_progress_bar() {
  local current=$1
  local max=$2
  local description=$3
  local percentage=$((current * 100 / max))
  local completed=$((percentage / 2))
  local remaining=$((50 - completed))
  
  # Create the progress bar
  local bar="["
  for ((i=0; i<completed; i++)); do
    bar+="="
  done
  
  if [ $completed -lt 50 ]; then
    bar+=">"
    for ((i=0; i<remaining-1; i++)); do
      bar+=" "
    done
  else
    bar+="="
  fi
  
  bar+="] ${percentage}%"
  
  # Print the progress bar and operation description
  printf "\r%-80s" "${description}: ${bar}"
}

# =========================================================================
# Function: Ask user for confirmation with default option
# Arguments: $1 = question, $2 = default (y/n)
# Returns: 0 for yes, 1 for no
# =========================================================================
confirm_action() {
  local question="$1"
  local default=${2:-n}
  local prompt
  
  if [[ $default == "y" ]]; then
    prompt="[Y/n]"
  else
    prompt="[y/N]"
  fi
  
  read -p "${question} ${prompt} " response
  
  response=${response:-$default}
  if [[ $response =~ ^[Yy] ]]; then
    return 0
  else
    return 1
  fi
}

# =========================================================================
# Function: Display a dialog menu and get user selection
# Arguments: $1 = title, $2 = message, $3... = menu options (key "description")
# Returns: Selected key in the DIALOG_RESULT variable
# =========================================================================
show_dialog_menu() {
  local title="$1"
  local message="$2"
  shift 2
  
  # Check if dialog is installed
  if ! command -v dialog >/dev/null 2>&1; then
    print_warning "dialog utility not found, falling back to text mode"
    echo "$message"
    local num=1
    local options=()
    local keys=()
    
    # Process the arguments as key-description pairs
    while [ $# -gt 0 ]; do
      local key="$1"
      local desc="$2"
      echo "$num) $desc"
      options[$num]="$desc"
      keys[$num]="$key"
      num=$((num+1))
      shift 2
    done
    
    read -p "Enter your choice (1-$((num-1))): " selection
    
    if [[ $selection =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -lt "$num" ]; then
      DIALOG_RESULT=${keys[$selection]}
    else
      DIALOG_RESULT=""
    fi
  else
    # Create the dialog options array
    local options=()
    local keys=()
    local num=0
    
    # Process the arguments as key-description pairs
    while [ $# -gt 0 ]; do
      options+=("$1" "$2")
      keys+=("$1")
      num=$((num+1))
      shift 2
    done
    
    # Use a temp file to store the result
    local temp_file=$(mktemp)
    
    # Display the dialog and get the result
    dialog --clear --title "$title" --menu "$message" 15 60 10 "${options[@]}" 2>"$temp_file"
    local dialog_status=$?
    
    if [ $dialog_status -eq 0 ]; then
      DIALOG_RESULT=$(cat "$temp_file")
    else
      DIALOG_RESULT=""
    fi
    
    # Clean up
    rm -f "$temp_file"
    clear  # Clear the screen after dialog
  fi
}

# =========================================================================
# Function: Display a gauge for a background process
# Arguments: $1 = title, $2 = command to run 
# =========================================================================
show_gauge_for_command() {
  local title="$1"
  local cmd="$2"
  
  # Check if dialog is installed
  if ! command -v dialog >/dev/null 2>&1; then
    print_warning "dialog utility not found, executing command without gauge"
    eval "$cmd"
    return
  fi
  
  # Create a temporary file for the command output
  local output_file=$(mktemp)
  
  # Create the gauge update function
  (
    # Execute the command in the background and capture its PID
    eval "$cmd" > "$output_file" 2>&1 &
    local cmd_pid=$!
    
    # Initialize the gauge
    echo "0"
    sleep 0.2
    
    # Update the gauge in increments
    for ((i=0; i<=100; i+=2)); do
      echo "$i"
      
      # If the command is complete, finish the gauge
      if ! kill -0 $cmd_pid 2>/dev/null; then
        echo "100"
        break
      fi
      
      sleep 0.1
    done
  ) | dialog --title "$title" --gauge "Running..." 10 70 0
  
  # Display the command output if needed
  local cmd_output=$(cat "$output_file")
  if [ -n "$cmd_output" ]; then
    dialog --title "Command Output" --msgbox "$cmd_output" 15 70
  fi
  
  # Clean up
  rm -f "$output_file"
  clear  # Clear the screen after dialog
}

# =========================================================================
# Function: Display a build status dashboard
# Arguments: $1 = status message, $2 = current step, $3 = total steps
#            $4 = successful images, $5 = failed images
# =========================================================================
show_build_dashboard() {
  local status="$1"
  local current_step="$2"
  local total_steps="$3"
  local successful_images="$4"
  local failed_images="$5"
  
  # Clear previous output
  tput clear
  
  # Build header
  print_section_header "Docker Build Status Dashboard"
  
  # Status information
  echo -e "${COLOR_CYAN}Status:${COLOR_RESET} $status"
  echo -e "${COLOR_CYAN}Progress:${COLOR_RESET} Step $current_step of $total_steps"
  
  # Progress bar
  local percentage=$((current_step * 100 / total_steps))
  local completed=$((percentage / 2))
  local remaining=$((50 - completed))
  
  echo -ne "${COLOR_CYAN}[${COLOR_RESET}"
  for ((i=0; i<completed; i++)); do
    echo -ne "${COLOR_GREEN}=${COLOR_RESET}"
  done
  
  if [ $completed -lt 50 ]; then
    echo -ne "${COLOR_GREEN}>${COLOR_RESET}"
    for ((i=0; i<remaining-1; i++)); do
      echo -ne " "
    done
  else
    echo -ne "${COLOR_GREEN}=${COLOR_RESET}"
  fi
  
  echo -e "${COLOR_CYAN}]${COLOR_RESET} ${percentage}%"
  
  echo
  echo -e "${COLOR_GREEN}Successfully Built:${COLOR_RESET} $successful_images"
  echo -e "${COLOR_RED}Failed:${COLOR_RESET} $failed_images"
  echo
}

# =========================================================================
# Function: Ask for a choice from a list of options
# Arguments: $1 = prompt message, $2... = options
# Returns: Selected option index (0-based) in CHOICE_RESULT variable
# =========================================================================
ask_for_choice() {
  local prompt="$1"
  shift
  local options=("$@")
  local num_options=${#options[@]}
  
  echo "$prompt"
  for ((i=0; i<num_options; i++)); do
    echo "$(($i+1))) ${options[$i]}"
  done
  
  local valid_selection=false
  while ! $valid_selection; do
    read -p "Enter your choice (1-$num_options): " selection
    
    if [[ $selection =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "$num_options" ]; then
      CHOICE_RESULT=$((selection-1))
      valid_selection=true
    else
      print_error "Invalid selection. Please enter a number between 1 and $num_options."
    fi
  done
}

# =========================================================================
# Function: Create a simple menu with numbered options
# Arguments: $1 = title, $2... = menu options
# Returns: Selected option number in MENU_SELECTION variable
# =========================================================================
show_simple_menu() {
  local title="$1"
  shift
  local options=("$@")
  
  print_color "${COLOR_CYAN}" "$title"
  echo
  
  for i in "${!options[@]}"; do
    echo "$(($i+1))) ${options[$i]}"
  done
  echo
  
  read -p "Enter your choice: " MENU_SELECTION
  
  # Convert to zero-based index
  MENU_SELECTION=$((MENU_SELECTION-1))
}

# =========================================================================
# Function: Display elapsed and estimated time for a build process
# Arguments: $1 = start time (Unix timestamp), $2 = current step, 
#            $3 = total steps
# =========================================================================
show_build_time() {
  local start_time="$1"
  local current_step="$2"
  local total_steps="$3"
  
  local now=$(date +%s)
  local elapsed=$((now - start_time))
  
  # Calculate elapsed time
  local elapsed_hours=$((elapsed / 3600))
  local elapsed_minutes=$(((elapsed % 3600) / 60))
  local elapsed_seconds=$((elapsed % 60))
  
  # Calculate estimated time remaining
  if [ "$current_step" -gt 0 ]; then
    local time_per_step=$((elapsed / current_step))
    local remaining_steps=$((total_steps - current_step))
    local estimated_remaining=$((time_per_step * remaining_steps))
    
    local remaining_hours=$((estimated_remaining / 3600))
    local remaining_minutes=$(((estimated_remaining % 3600) / 60))
    local remaining_seconds=$((estimated_remaining % 60))
    
    echo -e "${COLOR_CYAN}Elapsed time:${COLOR_RESET} ${elapsed_hours}h ${elapsed_minutes}m ${elapsed_seconds}s"
    echo -e "${COLOR_CYAN}Estimated remaining:${COLOR_RESET} ${remaining_hours}h ${remaining_minutes}m ${remaining_seconds}s"
  else
    echo -e "${COLOR_CYAN}Elapsed time:${COLOR_RESET} ${elapsed_hours}h ${elapsed_minutes}m ${elapsed_seconds}s"
    echo -e "${COLOR_CYAN}Estimated remaining:${COLOR_RESET} Calculating..."
  fi
}
