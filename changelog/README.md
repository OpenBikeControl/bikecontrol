# Translated changelogs

`CHANGELOG.md` (English) stays the source. Each `<language>.md` here holds the
same releases translated, in the same format:

- the same `### <version> (<date>)` heading, so a release is matched by version;
- the English `**Features**:` / `**Improvements**:` / `**Fixes**:` markers
  (machine markers: the app shows its own translated headings, and the store
  notes translate them, see `scripts/get_latest_changelog.sh`).

A release missing here falls back to English, in the app and in the store
notes (the release build warns when the newest release has no translation).
Languages: de, es, fr, it, pl (stores + app), zh (app only).

## Google Play

Play allows 500 characters, which the full notes rarely fit. `play/<language>.txt`
holds a short version per release: the first line is the version it belongs to
(the newest in `CHANGELOG.md`), then the text. Without a current one, Play gets
the full notes cut at 500 characters. Leave out nothing Android riders need,
and anything about other platforms.
