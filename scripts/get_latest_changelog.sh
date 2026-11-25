#!/bin/bash
# Prints the newest changelog entry as plain store "What's New" text.
# Usage: ./scripts/get_latest_changelog.sh [language] [--apple | --windows]
#
# --apple: for the App Store, which rejects notes that mention other platforms.
# Entries naming Windows, Android, Linux or Google Play are left out (and a
# heading whose entries are all gone with them).
# --windows: for the Microsoft Store. Entries about other platforms only
# (iPhone, iPad, Mac, Android, Linux) are left out; entries naming Windows or
# no platform stay.
#
# With a language (de, es, fr, it, pl, ...), the entry comes from
# changelog/<language>.md, with its "Features:"/"Fixes:" headings translated.
# Falls back to English (CHANGELOG.md), with a warning on stderr, when that
# file has no translation of the newest English release.

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [ ! -f "$PROJECT_ROOT/CHANGELOG.md" ]; then
    echo "Error: CHANGELOG.md not found at $PROJECT_ROOT/CHANGELOG.md"
    exit 1
fi

LANG_ARG=en
APPLE=0
for arg in "$@"; do
    case "$arg" in
        --apple) APPLE=1 ;;
        --windows) APPLE=windows ;;
        *) LANG_ARG="$arg" ;;
    esac
done

exec python3 - "$PROJECT_ROOT" "$LANG_ARG" "$APPLE" <<'PY'
import os, re, sys

root, lang = sys.argv[1], sys.argv[2].split("-")[0].split("_")[0].lower()
apple = sys.argv[3] == "1"
windows = sys.argv[3] == "windows"
OTHER_PLATFORMS = re.compile(r"\b(windows|android|linux|google play)\b", re.IGNORECASE)
NOT_WINDOWS = re.compile(r"\b(iphone|ipad|ios|mac|macos|android|linux|google play|app store)\b", re.IGNORECASE)
WINDOWS = re.compile(r"\bwindows\b", re.IGNORECASE)

HEADINGS = {
    "de": {"features": "Neu", "improvements": "Verbessert", "fixes": "Behoben"},
    "es": {"features": "Novedades", "improvements": "Mejoras", "fixes": "Correcciones"},
    "fr": {"features": "Nouveautés", "improvements": "Améliorations", "fixes": "Corrections"},
    "it": {"features": "Novità", "improvements": "Miglioramenti", "fixes": "Correzioni"},
    "pl": {"features": "Nowości", "improvements": "Ulepszenia", "fixes": "Poprawki"},
    "zh": {"features": "新功能", "improvements": "改进", "fixes": "修复"},
}

def latest(path):
    """(version, lines) of the first '### ' entry."""
    version, body = None, []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if line.startswith("### "):
                if version is not None:
                    break
                version = line[4:].split()[0]
                continue
            if version is not None:
                body.append(line)
    return version, body

en_version, body = latest(os.path.join(root, "CHANGELOG.md"))
words = None
if lang != "en":
    path = os.path.join(root, "changelog", f"{lang}.md")
    version, translated = latest(path) if os.path.exists(path) else (None, [])
    if version == en_version:
        body, words = translated, HEADINGS.get(lang)
    else:
        print(f"warning: no {lang} translation of {en_version} in changelog/{lang}.md, using English",
              file=sys.stderr)

def drop_other_platforms(lines, is_other=lambda line: bool(OTHER_PLATFORMS.search(line))):
    """Leave out list entries (with their run-on lines) that [is_other] flags,
    then headings left without entries."""
    kept, skipping = [], False
    for line in lines:
        if line.startswith("- "):
            skipping = is_other(line)
        elif not line.strip() or line.startswith("**") or line.rstrip().endswith(":"):
            skipping = False
        if skipping:
            continue
        kept.append(line)
    result = []
    for i, line in enumerate(kept):
        is_heading = line.startswith("**") or (line.rstrip().endswith(":") and not line.startswith("- "))
        if is_heading:
            nxt = next((l for l in kept[i + 1:] if l.strip()), "")
            if not nxt.startswith("- "):
                continue
        result.append(line)
    return result

if apple:
    body = drop_other_platforms(body)
if windows:
    body = drop_other_platforms(body, lambda line: bool(NOT_WINDOWS.search(line)) and not WINDOWS.search(line))

out = []
for line in body:
    line = re.sub(r"^- ", "• ", line)
    line = line.replace("**", "")
    m = re.match(r"^(Features|New Features|Improvements|Fixes|Bug fixes)\s*:\s*$", line)
    if m and words:
        key = "fixes" if "fix" in m.group(1).lower() else (
            "improvements" if "improv" in m.group(1).lower() else "features")
        line = words[key] + ":"
    out.append(line)
sys.stdout.write("\n".join(out).strip("\n") + "\n")
PY
