#!/bin/bash

# get current dir
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "Making all .sh and .bash files executable in $SCRIPT_DIR and subdirectories..."

# find all .sh and .bash files and add execute permission
find "$SCRIPT_DIR" -type f \( -name "*.sh" -o -name "*.bash" \) -exec chmod +x {} + -print

echo "Done."
