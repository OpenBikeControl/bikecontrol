#!/bin/bash
# Prints the Google Play "What's New" for one language (Play allows 500 chars).
# Usage: ./scripts/get_play_notes.sh <language>
#
# Uses the short text in changelog/play/<language>.txt when its first line is
# the newest version in CHANGELOG.md; otherwise falls back to the full notes
# (get_latest_changelog.sh), which the caller then truncates — with a warning,
# since that usually cuts the fixes off.

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LANG_CODE="${1:-en}"
LANG_CODE="${LANG_CODE%%-*}"
SHORT="$PROJECT_ROOT/changelog/play/$LANG_CODE.txt"
LATEST=$(grep -m1 '^### ' "$PROJECT_ROOT/CHANGELOG.md" | awk '{print $2}')

if [ -f "$SHORT" ] && [ "$(head -n1 "$SHORT" | tr -d '\r')" = "$LATEST" ]; then
    tail -n +2 "$SHORT"
else
    echo "warning: no short Play text for $LATEST in changelog/play/$LANG_CODE.txt, using the full notes" >&2
    "$SCRIPT_DIR/get_latest_changelog.sh" "$LANG_CODE"
fi
