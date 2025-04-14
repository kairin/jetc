#!/bin/bash
set -e

# File to check
FILE="image_builder.sh"

echo "Checking for syntax errors in $FILE..."

# Make a backup
cp "$FILE" "$FILE.bak"
echo "Created backup at $FILE.bak"

# Check for syntax errors and capture the output
SYNTAX_CHECK=$(bash -n "$FILE" 2>&1)
SYNTAX_CHECK_STATUS=$?
if [ $SYNTAX_CHECK_STATUS -eq 0 ]; then
  echo "No syntax errors found. This is unexpected."
  exit 1
else
  echo "Syntax errors found:"
  echo "$SYNTAX_CHECK"
fi

# Analyze the file for common syntax issues
echo "Analyzing file for missing closures..."

# Count opening and closing structures
OPEN_IF=$(grep -c "if \[" "$FILE")
CLOSE_IF=$(grep -c "fi" "$FILE")
OPEN_FOR=$(grep -c "for " "$FILE" | grep -v "grep" | grep -c "do")
CLOSE_FOR=$(grep -c "done" "$FILE")
OPEN_FUNC=$(grep -c "() {" "$FILE")
CLOSE_FUNC=$(grep -c "}" "$FILE")

echo "if/fi: $OPEN_IF/$CLOSE_IF"
echo "for/done: $OPEN_FOR/$CLOSE_FOR"
echo "func/}: $OPEN_FUNC/$CLOSE_FUNC"

# Specifically check line 285 (reported in error)
LINE_285=$(sed -n '285p' "$FILE")
echo "Line 285: $LINE_285"

# Check lines around the problem
echo "Lines around 285:"
sed -n '280,290p' "$FILE"

# Fix the most common issue - 
# For demonstration, add missing closures at the end of file
echo "Attempting to fix by adding potentially missing closures..."

{
  cat "$FILE"
  echo ""
  echo "# Auto-added missing closures"
  
  # Add missing function closures
  if [ "$OPEN_FUNC" -gt "$CLOSE_FUNC" ]; then
    for ((i=0; i<($OPEN_FUNC-$CLOSE_FUNC); i++)); do
      echo "}  # Auto-added function closure"
    done
  fi
  
  # Add missing 'fi' statements
  if [ "$OPEN_IF" -gt "$CLOSE_IF" ]; then
    for ((i=0; i<($OPEN_IF-$CLOSE_IF); i++)); do
      echo "fi  # Auto-added if closure"
    done
  fi
  
  # Add missing 'done' statements
  if [ "$OPEN_FOR" -gt "$CLOSE_FOR" ]; then
    for ((i=0; i<($OPEN_FOR-$CLOSE_FOR); i++)); do
      echo "done  # Auto-added loop closure"
    done
  fi
} > "$FILE.fixed"

echo "Created fixed file at $FILE.fixed"
echo "To apply the fix: cp $FILE.fixed $FILE"
echo "Then test with: bash -n $FILE"
