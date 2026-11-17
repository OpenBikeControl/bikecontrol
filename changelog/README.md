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
