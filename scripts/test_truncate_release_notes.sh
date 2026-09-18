#!/bin/bash
# Tests for scripts/truncate_release_notes.sh.
# Usage: ./scripts/test_truncate_release_notes.sh
set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TRUNCATE="$SCRIPT_DIR/truncate_release_notes.sh"

failures=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }

# Unicode character count (not bytes) of a file.
chars() { python3 -c 'import sys; print(len(open(sys.argv[1], encoding="utf-8").read()))' "$1"; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if [ ! -x "$TRUNCATE" ]; then
  echo "FAIL: $TRUNCATE missing or not executable"
  exit 1
fi

# 1. Short input passes through unchanged (incl. trailing newline).
printf '• Fixed a thing — really\n• Another line\n' > "$tmp/short.in"
"$TRUNCATE" 500 < "$tmp/short.in" > "$tmp/short.out"
if cmp -s "$tmp/short.in" "$tmp/short.out"; then pass "short input unchanged"; else fail "short input unchanged"; fi

# 2. Multi-byte input is counted by characters: 500 bullets (1500 bytes) fit 500.
python3 -c 'print("•" * 500, end="")' > "$tmp/bullets.in"
"$TRUNCATE" 500 < "$tmp/bullets.in" > "$tmp/bullets.out"
if cmp -s "$tmp/bullets.in" "$tmp/bullets.out"; then pass "500 multi-byte chars fit 500"; else fail "500 multi-byte chars fit 500 (got $(chars "$tmp/bullets.out") chars)"; fi

# 3. Over-long input is cut at a line break, ends with "…", stays within the limit
#    and never splits a word or URL.
python3 - "$tmp/long.in" <<'PY'
import sys
lines = [f"• Entry number {i} with some words — see https://bikecontrol.app/docs/{i}" for i in range(40)]
open(sys.argv[1], "w", encoding="utf-8").write("\n".join(lines) + "\n")
PY
"$TRUNCATE" 500 < "$tmp/long.in" > "$tmp/long.out"
n=$(chars "$tmp/long.out")
if [ "$n" -le 500 ]; then pass "cut result within limit ($n chars)"; else fail "cut result within limit ($n chars)"; fi
if python3 - "$tmp/long.in" "$tmp/long.out" <<'PY'
import sys
src = open(sys.argv[1], encoding="utf-8").read()
out = open(sys.argv[2], encoding="utf-8").read()
assert out.endswith("…"), "missing ellipsis"
body = out[:-1].rstrip("\n")
kept = body.split("\n")
src_lines = src.split("\n")
assert kept == src_lines[:len(kept)], "cut is not on a line boundary"
assert len(kept) > 1, "cut far too early"
PY
then pass "cut on line boundary with ellipsis"; else fail "cut on line boundary with ellipsis"; fi

# 4. A single long line falls back to the last space (no half word).
python3 -c 'print(" ".join(["word%02d" % i for i in range(100)]), end="")' > "$tmp/oneline.in"
"$TRUNCATE" 100 < "$tmp/oneline.in" > "$tmp/oneline.out"
n=$(chars "$tmp/oneline.out")
if [ "$n" -le 100 ] && python3 - "$tmp/oneline.out" <<'PY'
import sys, re
out = open(sys.argv[1], encoding="utf-8").read()
assert out.endswith("…")
assert re.fullmatch(r"(word\d\d )*word\d\d ?…", out), out
PY
then pass "single line cut at word boundary ($n chars)"; else fail "single line cut at word boundary ($n chars)"; fi

# 5. The real latest changelog entry fits the App Store limit unchanged.
"$SCRIPT_DIR/get_latest_changelog.sh" > "$tmp/changelog.in"
"$TRUNCATE" 4000 < "$tmp/changelog.in" > "$tmp/changelog.out"
if cmp -s "$tmp/changelog.in" "$tmp/changelog.out"; then pass "real changelog fits 4000 unchanged ($(chars "$tmp/changelog.in") chars)"; else fail "real changelog fits 4000 unchanged"; fi

# 6. The real changelog cut to 500 is valid UTF-8 and within the Play limit.
"$TRUNCATE" 500 < "$tmp/changelog.in" > "$tmp/play.out"
n=$(chars "$tmp/play.out")
if [ "$n" -le 500 ]; then pass "real changelog cut to Play limit ($n chars)"; else fail "real changelog cut to Play limit ($n chars)"; fi

if [ "$failures" -gt 0 ]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "All tests passed"
