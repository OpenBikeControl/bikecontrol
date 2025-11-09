#!/bin/bash
# Script to generate GitHub release body with changelog and store links
# Usage: ./scripts/generate_release_body.sh

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
RELEASE_NOTES_FILE="$SCRIPT_DIR/RELEASE_NOTES.md"

if [ ! -f "$RELEASE_NOTES_FILE" ]; then
    echo "Error: RELEASE_NOTES.md not found at $RELEASE_NOTES_FILE"
    exit 1
fi

# Extract the first changelog entry using get_latest_changelog.sh
# For GitHub releases, we want to include the version header
VERSION_HEADER=$(awk '/^### / {print; exit}' "$SCRIPT_DIR/../CHANGELOG.md")
LATEST_CHANGELOG=$("$SCRIPT_DIR/get_latest_changelog.sh")

# Combine changelog with release notes
echo "$VERSION_HEADER"
echo "$LATEST_CHANGELOG"
echo ""
echo "---"
echo ""
cat "$RELEASE_NOTES_FILE"
