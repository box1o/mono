#!/usr/bin/env bash

# ccp - Code Copy Prompt Builder
# Reads file paths from a config file and concatenates their contents for AI prompts

set -e

VERSION="1.0.0"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flags
VERBOSE=false
COPY_TO_CLIPBOARD=false
CONFIG_FILE=""

# Function to display usage
usage() {
    cat << EOF
Usage: ccp -f <config_file> [OPTIONS]

Code Copy Prompt Builder - Concatenates file contents from paths listed in a config file

OPTIONS:
    -f <file>       Config file containing file paths (required)
    -v              Verbose mode - show which files are being processed
    -c              Copy output to clipboard
    -h              Show this help message
    --version       Show version

EXAMPLES:
    ccp -f paths.conf
    ccp -f paths.conf -v
    ccp -f paths.conf -c
    ccp -f paths.conf -v -c

CONFIG FILE FORMAT:
    - One file path per line
    - Lines starting with # are ignored (comments)
    - Paths can be quoted or unquoted
    - Empty lines are ignored

EOF
    exit 0
}

# Function to print error messages
error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Function to print verbose messages
verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}$1${NC}" >&2
    fi
}

# Function to check if clipboard command is available
check_clipboard() {
    if command -v xclip &> /dev/null; then
        echo "xclip"
    elif command -v xsel &> /dev/null; then
        echo "xsel"
    elif command -v pbcopy &> /dev/null; then
        echo "pbcopy"
    elif command -v wl-copy &> /dev/null; then
        echo "wl-copy"
    else
        echo ""
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -c|--copy)
            COPY_TO_CLIPBOARD=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        --version)
            echo "ccp version $VERSION"
            exit 0
            ;;
        *)
            error "Unknown option: $1\nUse -h for help"
            ;;
    esac
done

# Check if config file is specified
if [ -z "$CONFIG_FILE" ]; then
    error "Config file not specified. Use -f <file>"
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    error "Config file not found: $CONFIG_FILE"
fi

# Show config file content in verbose mode
if [ "$VERBOSE" = true ]; then
    echo -e "${GREEN}====${NC}"
    echo -e "${GREEN}$CONFIG_FILE${NC}"
    echo -e "${GREEN}====${NC}"
    cat "$CONFIG_FILE"
    echo ""
fi

# Temporary file to store output
TEMP_OUTPUT=$(mktemp)
trap "rm -f $TEMP_OUTPUT" EXIT

# Process the config file
while IFS= read -r line || [ -n "$line" ]; do
    # Skip empty lines and comments
    if [ -z "$line" ] || [[ "$line" =~ ^[[:space:]]*# ]]; then
        continue
    fi
    
    # Remove quotes from path
    filepath=$(echo "$line" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    
    # Expand tilde to home directory
    filepath="${filepath/#\~/$HOME}"
    
    # Check if file exists
    if [ ! -f "$filepath" ]; then
        echo -e "${YELLOW}Warning: File not found: $filepath${NC}" >&2
        continue
    fi
    
    verbose "Processing: $filepath"
    
    # Append file path and content to output
    {
        echo "===="
        echo "$filepath"
        echo "===="
        cat "$filepath"
        echo ""
        echo ""
    } >> "$TEMP_OUTPUT"
    
done < "$CONFIG_FILE"

# Output the result
cat "$TEMP_OUTPUT"

# Copy to clipboard if requested
if [ "$COPY_TO_CLIPBOARD" = true ]; then
    CLIPBOARD_CMD=$(check_clipboard)
    
    if [ -z "$CLIPBOARD_CMD" ]; then
        echo -e "${YELLOW}Warning: No clipboard command found (xclip, xsel, pbcopy, or wl-copy)${NC}" >&2
        echo -e "${YELLOW}Output was not copied to clipboard${NC}" >&2
    else
        case $CLIPBOARD_CMD in
            xclip)
                cat "$TEMP_OUTPUT" | xclip -selection clipboard
                ;;
            xsel)
                cat "$TEMP_OUTPUT" | xsel --clipboard
                ;;
            pbcopy)
                cat "$TEMP_OUTPUT" | pbcopy
                ;;
            wl-copy)
                cat "$TEMP_OUTPUT" | wl-copy
                ;;
        esac
        verbose "${GREEN}Output copied to clipboard!${NC}"
    fi
fi
