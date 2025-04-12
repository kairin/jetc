#!/bin/bash
# filepath: buildx/generate_app_checks.sh

set -e

BUILD_DIR="buildx/build"
OUTPUT_FILE="buildx/generated_app_checks.sh"

echo "# Auto-generated checks from Dockerfile analysis" > "$OUTPUT_FILE"
echo "# Generated on $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "check_installed_applications() {" >> "$OUTPUT_FILE"
echo "  echo -e \"\n\${BLUE}🔍 Verifying Applications Installed in Build Process:\${NC}\"" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Process each build folder in order
find "$BUILD_DIR" -type d -name "[0-9]*-*" | sort | while read -r folder; do
  folder_name=$(basename "$folder")
  folder_number=${folder_name%%-*}
  folder_desc=${folder_name#*-}
  
  # Skip if no Dockerfile exists
  if [ ! -f "$folder/Dockerfile" ]; then
    continue
  fi

  echo "  # Applications from $folder_name" >> "$OUTPUT_FILE"
  echo "  echo -e \"\n\${CYAN}[$folder_number] - $folder_desc:\${NC}\"" >> "$OUTPUT_FILE"
  
  # Extract apt-get install packages
  if grep -q "apt-get install" "$folder/Dockerfile"; then
    packages=$(grep -A20 "apt-get install" "$folder/Dockerfile" | grep -v "&&" | grep -v "apt-get" | tr -d '\\' | tr -s ' ' | sed 's/^[ \t]*//;s/[ \t]*$//' | grep -v '^$' | tr ' ' '\n' | grep -v '^-' | sort | uniq)
    
    for pkg in $packages; do
      # Skip version pins and flags
      if [[ "$pkg" == *\=* ]] || [[ "$pkg" == --* ]]; then
        # Extract base package name from pinned version
        if [[ "$pkg" == *\=* ]]; then
          pkg=${pkg%%=*}
        else
          continue
        fi
      fi
      
      # Skip certain packages that don't have commands
      if [[ "$pkg" == "locales"* ]] || [[ "$pkg" == "tzdata" ]] || [[ "$pkg" == "ca-certificates" ]] || [[ "$pkg" == *"-dev" ]]; then
        continue
      fi
      
      # Common mapping of package names to executable commands
      case "$pkg" in
        "git-lfs") echo "  check_cmd git-lfs \"Git Large File Storage\"" >> "$OUTPUT_FILE" ;;
        "python3-pip") echo "  check_cmd pip3 \"Python 3 Package Manager\"" >> "$OUTPUT_FILE" ;;
        "ssh-client") echo "  check_cmd ssh \"SSH Client\"" >> "$OUTPUT_FILE" ;;
        "build-essential") 
          echo "  check_cmd gcc \"C Compiler (from build-essential)\"" >> "$OUTPUT_FILE"
          echo "  check_cmd g++ \"C++ Compiler (from build-essential)\"" >> "$OUTPUT_FILE"
          echo "  check_cmd make \"Make utility (from build-essential)\"" >> "$OUTPUT_FILE"
          ;;
        *) 
          # Default - try the package name as the command
          cmd="${pkg%%-*}" # Remove any suffix like -dev
          echo "  check_cmd $cmd \"$pkg package\"" >> "$OUTPUT_FILE"
          ;;
      esac
    done
  fi
  
  # Extract pip/pip3 install packages
  if grep -q "pip.*install" "$folder/Dockerfile"; then
    pip_packages=$(grep -A20 "pip.*install" "$folder/Dockerfile" | grep -v "&&" | grep -v "pip" | tr -d '\\' | tr -s ' ' | sed 's/^[ \t]*//;s/[ \t]*$//' | grep -v '^$' | tr ' ' '\n' | grep -v '^-' | sort | uniq)
    
    for pkg in $pip_packages; do
      # Skip version pins and flags
      if [[ "$pkg" == *\=* ]] || [[ "$pkg" == --* ]] || [[ "$pkg" == -* ]]; then
        if [[ "$pkg" == *\=* ]]; then
          pkg=${pkg%%=*}
        else
          continue
        fi
      fi
      
      echo "  check_python_pkg $pkg" >> "$OUTPUT_FILE"
    done
  fi
  
  # Look for custom scripts or files copied
  if grep -q "COPY" "$folder/Dockerfile"; then
    copied_files=$(grep "COPY" "$folder/Dockerfile" | awk '{for(i=2;i<NF;i++) print $i}' | grep -v "^/" | grep -v "^./" | grep -v "\*" | sort | uniq)
    
    for file in $copied_files; do
      # Only check executable-looking files
      if [[ "$file" != *"."* ]]; then
        echo "  check_cmd $file \"Custom utility from $folder_desc\"" >> "$OUTPUT_FILE"
      fi
    done
  fi
  
  echo "" >> "$OUTPUT_FILE"
done

# Close the function
echo "}" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "# End of auto-generated checks" >> "$OUTPUT_FILE"

echo "Generated application checks in $OUTPUT_FILE"