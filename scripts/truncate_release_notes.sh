#!/bin/bash
# Truncate release notes (stdin -> stdout) to at most <max_chars> Unicode
# characters — not bytes, so multi-byte characters like "•" or "—" count once
# and are never split.
#
# Input that fits is passed through unchanged. Otherwise the text is cut at the
# last line break that fits (falling back to the last space) and "…" is
# appended, so the store never shows half a word or URL.
#
# Usage: ./scripts/get_latest_changelog.sh | ./scripts/truncate_release_notes.sh 500
set -euo pipefail

if [ $# -ne 1 ] || ! [[ "$1" =~ ^[0-9]+$ ]] || [ "$1" -lt 2 ]; then
  echo "Usage: $0 <max_chars> (>= 2) < input" >&2
  exit 2
fi

exec python3 -c '
import sys

limit = int(sys.argv[1])
text = sys.stdin.buffer.read().decode("utf-8")

if len(text) <= limit:
    sys.stdout.buffer.write(text.encode("utf-8"))
    sys.exit(0)

# Last line break leaving room for "\n…".
idx = text.rfind("\n", 0, limit - 1)
cut = text[:idx].rstrip() if idx > 0 else ""
if cut:
    out = cut + "\n…"
else:
    # Last space leaving room for "…".
    idx = text.rfind(" ", 0, limit)
    cut = text[:idx].rstrip() if idx > 0 else ""
    out = (cut if cut else text[:limit - 1]) + "…"

sys.stdout.buffer.write(out.encode("utf-8"))
' "$1"
