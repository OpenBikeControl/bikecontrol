#!/bin/bash
# Script to extract the latest changelog entry for Play Store uploads
# Usage: ./scripts/get_latest_changelog.sh

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CHANGELOG_FILE="$PROJECT_ROOT/CHANGELOG.md"

if [ ! -f "$CHANGELOG_FILE" ]; then
    echo "Error: CHANGELOG.md not found at $CHANGELOG_FILE"
    exit 1
fi

# Extract the first changelog entry (between first ### and second ###)
awk '/^### / {if (count++) exit} count' "$CHANGELOG_FILE" | tail -n +2 | sed 's/^- /• /'
