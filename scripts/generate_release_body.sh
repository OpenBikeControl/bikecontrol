#!/bin/bash
# Script to generate GitHub release body with changelog and store links
# Usage: ./scripts/generate_release_body.sh

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CHANGELOG_FILE="$PROJECT_ROOT/CHANGELOG.md"
RELEASE_NOTES_FILE="$SCRIPT_DIR/RELEASE_NOTES.md"

if [ ! -f "$CHANGELOG_FILE" ]; then
    echo "Error: CHANGELOG.md not found at $CHANGELOG_FILE"
    exit 1
fi

if [ ! -f "$RELEASE_NOTES_FILE" ]; then
    echo "Error: RELEASE_NOTES.md not found at $RELEASE_NOTES_FILE"
    exit 1
fi

# Extract the first changelog entry (between first ### and second ###)
LATEST_CHANGELOG=$(awk '/^### / {if (count++) exit} count' "$CHANGELOG_FILE" | sed 's/^- /• /')

# Combine changelog with release notes
echo "$LATEST_CHANGELOG"
echo ""
echo "---"
echo ""
cat "$RELEASE_NOTES_FILE"
