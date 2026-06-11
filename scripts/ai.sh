#!/bin/bash

# AI Project Structure Generator
# Usage: ./ai.sh [directory] [--ignore dir1,dir2] [--ignore-only dir1,dir2] [--prompt "custom prompt"]
# 
# Options:
#   --ignore      Add directories to the default ignore list
#   --ignore-only Replace default ignore list entirely
#   --prompt      Custom prompt for AI analysis

# Default values
TARGET_DIR="."
DEFAULT_IGNORE_DIRS="node_modules,build,dist,.next,.cache,__pycache__,.nvim,.npm,.yarn,vendor,target,coverage,.vscode,*.min.js,*.min.css,package-lock.json,yarn.lock,pnpm-lock.yaml"
IGNORE_DIRS="$DEFAULT_IGNORE_DIRS"
CUSTOM_PROMPT=""
DEFAULT_PROMPT="Please analyze this project structure and provide insights about its architecture, organization, and potential improvements."

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --ignore)
            IGNORE_DIRS="$DEFAULT_IGNORE_DIRS,$2"
            shift 2
            ;;
        --ignore-only)
            IGNORE_DIRS="$2"
            shift 2
            ;;
        --prompt)
            CUSTOM_PROMPT="$2"
            shift 2
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            TARGET_DIR="$1"
            shift
            ;;
    esac
done

# Use custom prompt if provided, otherwise use default
PROMPT="${CUSTOM_PROMPT:-$DEFAULT_PROMPT}"

# Check if tree is installed
if ! command -v tree &> /dev/null; then
    echo "Error: 'tree' command not found. Please install it first."
    echo "  Arch: sudo pacman -S tree"
    exit 1
fi

# Check if wl-copy is installed
if ! command -v wl-copy &> /dev/null; then
    echo "Error: 'wl-copy' command not found. Please install wl-clipboard."
    echo "  Ubuntu/Debian: sudo apt install wl-clipboard"
    echo "  Fedora: sudo dnf install wl-clipboard"
    echo "  Arch: sudo pacman -S wl-clipboard"
    exit 1
fi

# Check if target directory exists
if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: Directory '$TARGET_DIR' not found."
    exit 1
fi

# Create temporary file for output
TEMP_FILE=$(mktemp)

# Build tree command with ignore patterns
TREE_CMD="tree --gitignore -a -I '.git'"

# Add custom ignore directories
if [[ -n "$IGNORE_DIRS" ]]; then
    IFS=',' read -ra DIRS <<< "$IGNORE_DIRS"
    for dir in "${DIRS[@]}"; do
        TREE_CMD="$TREE_CMD -I '$dir'"
    done
fi

# Generate output
{
    echo "==================================="
    echo "AI PROJECT ANALYSIS PROMPT"
    echo "==================================="
    echo "$PROMPT"
    echo ""
    echo "==================================="
    echo "PROJECT STRUCTURE"
    echo "==================================="
    eval "$TREE_CMD '$TARGET_DIR'"
    echo ""
    echo "==================================="
    echo "FILE CONTENTS"
    echo "==================================="
    
    # Function to check if file is binary
    is_binary() {
        if file "$1" | grep -q "text"; then
            return 1
        else
            return 0
        fi
    }
    
    # Build find command with ignore patterns
    FIND_IGNORE=""
    if [[ -n "$IGNORE_DIRS" ]]; then
        IFS=',' read -ra DIRS <<< "$IGNORE_DIRS"
        for dir in "${DIRS[@]}"; do
            FIND_IGNORE="$FIND_IGNORE -path '*/$dir/*' -prune -o"
        done
    fi
    
    # Always ignore .git directory
    FIND_IGNORE="$FIND_IGNORE -path '*/.git/*' -prune -o"
    
    # Read .gitignore patterns if exists
    GITIGNORE_PATTERNS=()
    if [[ -f "$TARGET_DIR/.gitignore" ]]; then
        while IFS= read -r line; do
            # Skip empty lines and comments
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            GITIGNORE_PATTERNS+=("$line")
        done < "$TARGET_DIR/.gitignore"
    fi
    
    # Function to check if path matches gitignore pattern
    matches_gitignore() {
        local path="$1"
        for pattern in "${GITIGNORE_PATTERNS[@]}"; do
            # Simple pattern matching (basic implementation)
            if [[ "$path" == *"$pattern"* ]]; then
                return 0
            fi
        done
        return 1
    }
    
    # Find and read all files
    while IFS= read -r -d '' file; do
        # Skip if matches gitignore
        if matches_gitignore "$file"; then
            continue
        fi
        
        # Check if file is binary
        if is_binary "$file"; then
            echo "--- FILE: $file (binary file, skipped) ---"
        else
            echo "--- FILE: $file ---"
            cat "$file"
            echo ""
        fi
    done < <(eval "find '$TARGET_DIR' $FIND_IGNORE -type f -print0")
    
} > "$TEMP_FILE"

# Copy to clipboard
cat "$TEMP_FILE" | wl-copy

# Clean up
rm "$TEMP_FILE"

echo "✓ Project structure and contents copied to clipboard!"
echo "  Directory analyzed: $TARGET_DIR"
echo "  Ignored patterns: $IGNORE_DIRS"
