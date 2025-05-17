#!/bin/bash

# Display help message
if [[ "$1" == "--help" || -z "$1" ]]; then
  echo "Usage: scloc.sh [directory]"
  echo "This script analyzes Solidity files with cloc in the specified directory and outputs a summary sorted by the amount of lines of code (increasing order)."
  echo "Options:"
  echo "  --help    Show this help message and exit."
  exit 0
fi

echo -e " Checked | Code\t| Files"
cloc --by-file --csv "$1" | grep "Solidity" | cut -d ',' -f 5,2 | sort -n -t ',' -k 2 | sed 's/^\(.*\),\(.*\)$/    -    | \2\t| \[\]\(\1\)/'