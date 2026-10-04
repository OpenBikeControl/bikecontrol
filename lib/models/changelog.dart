/// CHANGELOG.md as data: releases, each with its version, date, the notes
/// written above its lists, and its entries grouped by kind of change.
///
/// The file has been written by hand for years and its shape has drifted —
/// `**Features**:` and `**Fixes:**`, plain "Virtual Shifting:" lines over a
/// list, lists with no heading at all, a paragraph run on under an item,
/// dates as dd-mm-yyyy and as yyyy-mm-dd. The parser takes all of it and
/// keeps the entries' own words (and their inline markdown) as written.
library;

import 'package:version/version.dart';

/// What kind of change a group of entries is.
enum ChangeKind {
  /// "Features", "New Features", "Pro Features".
  added,

  /// "Improvements", "Improved".
  improved,

  /// "Fixes", "Bug fixes".
  fixed,

  /// A list with no heading that says which.
  other,
}

class ChangelogEntry {
  ChangelogEntry(this.text);

  /// The entry's text, inline markdown (links, emphasis) kept.
  String text;

  /// Indented sub-items.
  final List<String> children = [];
}

class ChangelogSection {
  ChangelogSection({required this.kind, this.title});

  final ChangeKind kind;

  /// The heading as written, for a named group ("Virtual Shifting"); null
  /// for one of the standard kinds, whose name the UI supplies.
  final String? title;

  final List<ChangelogEntry> entries = [];
}

class ChangelogRelease {
  ChangelogRelease({required this.version, this.date});

  final String version;
  final DateTime? date;

  /// Paragraphs written around the lists: announcements, "read more" links.
  final List<String> notes = [];

  final List<ChangelogSection> sections = [];

  /// [version] as a comparable version, or null when it isn't one.
  Version? get parsedVersion => _parseVersion(version);
}

final _releaseHeading = RegExp(r'^###\s+(\S+)\s*(?:\((\d{1,4})-(\d{1,2})-(\d{1,4})\))?');
final _listItem = RegExp(r'^(\s*)[-*]\s+(.*)$');
final _boldHeading = RegExp(r'^\*{2}([^*].{0,38}?)\*{2}\s*:?\s*$');
final _strayBold = RegExp(r'\*{3,}');

/// A plain "Title:" line only heads the list under it while it is a title;
/// a sentence that happens to end in a colon stays a note.
const _maxTitleLength = 60;

/// Parses [markdown] into releases, in file order (newest first).
List<ChangelogRelease> parseChangelog(String markdown) {
  final lines = markdown.replaceAll('\r\n', '\n').split('\n');
  final releases = <ChangelogRelease>[];
  ChangelogRelease? release;
  ChangeKind? kind;
  ChangelogSection? section;
  ChangelogEntry? entry;
  var lastWasChild = false;
  var previousWasItem = false;
  final paragraph = <String>[];

  void flushParagraph() {
    if (release != null && paragraph.isNotEmpty) {
      final text = _clean(paragraph.join(' '));
      if (text.isNotEmpty) release.notes.add(text);
    }
    paragraph.clear();
  }

  bool nextIsListItem(int from) {
    for (var j = from; j < lines.length; j++) {
      if (lines[j].trim().isEmpty) continue;
      return _listItem.hasMatch(lines[j]);
    }
    return false;
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trimRight();
    final trimmed = line.trim();

    final heading = _releaseHeading.firstMatch(trimmed);
    if (heading != null) {
      flushParagraph();
      release = ChangelogRelease(version: heading.group(1)!, date: _date(heading));
      releases.add(release);
      kind = null;
      section = null;
      entry = null;
      previousWasItem = false;
      continue;
    }
    if (release == null) continue;

    if (trimmed.isEmpty) {
      flushParagraph();
      previousWasItem = false;
      continue;
    }

    final item = _listItem.firstMatch(line);
    if (item != null) {
      flushParagraph();
      final text = _clean(item.group(2)!);
      final indent = item.group(1)!.length;
      if (indent >= 2 && entry != null) {
        entry.children.add(text);
        lastWasChild = true;
      } else {
        if (section == null) {
          section = ChangelogSection(kind: kind ?? ChangeKind.other);
          release.sections.add(section);
        }
        entry = ChangelogEntry(text);
        section.entries.add(entry);
        lastWasChild = false;
      }
      previousWasItem = true;
      continue;
    }

    // A line run on directly under an item is part of it.
    if (previousWasItem && entry != null) {
      final more = _clean(trimmed);
      if (lastWasChild && entry.children.isNotEmpty) {
        entry.children[entry.children.length - 1] = '${entry.children.last} $more';
      } else {
        entry.text = '${entry.text} $more';
      }
      continue;
    }

    final bold = _boldHeading.firstMatch(trimmed);
    if (bold != null) {
      flushParagraph();
      kind = _classify(bold.group(1)!) ?? ChangeKind.other;
      section = null;
      entry = null;
      continue;
    }

    if (trimmed.endsWith(':') && trimmed.length <= _maxTitleLength && nextIsListItem(i + 1)) {
      flushParagraph();
      final title = _clean(trimmed.substring(0, trimmed.length - 1));
      section = ChangelogSection(kind: _classify(title) ?? kind ?? ChangeKind.other, title: title);
      release.sections.add(section);
      entry = null;
      continue;
    }

    paragraph.add(trimmed);
  }
  flushParagraph();

  for (final r in releases) {
    r.sections.removeWhere((s) => s.entries.isEmpty);
  }
  return releases;
}

/// The releases newer than [lastSeen], newest first — what changed since the
/// rider last opened the app. Just the newest one when [lastSeen] isn't a
/// version.
List<ChangelogRelease> releasesSince(List<ChangelogRelease> releases, String lastSeen) {
  final seen = _parseVersion(lastSeen);
  if (seen == null) return releases.take(1).toList();
  return [
    for (final r in releases)
      if (r.parsedVersion case final v? when v > seen) r,
  ];
}

final _versionLike = RegExp(r'^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.+-]*)?$');

/// Null for text that isn't a version — the callers have an answer for that
/// (see [releasesSince]).
Version? _parseVersion(String text) {
  final t = text.trim();
  return _versionLike.hasMatch(t) ? Version.parse(t) : null;
}

DateTime? _date(RegExpMatch heading) {
  final a = heading.group(2), b = heading.group(3), c = heading.group(4);
  if (a == null || b == null || c == null) return null;
  final yearFirst = a.length == 4;
  final year = int.parse(yearFirst ? a : c);
  final day = int.parse(yearFirst ? c : a);
  return DateTime(year, int.parse(b), day);
}

ChangeKind? _classify(String heading) {
  final h = heading.toLowerCase();
  if (h.contains('fix')) return ChangeKind.fixed;
  if (h.contains('improv')) return ChangeKind.improved;
  if (h.contains('feature') || h.startsWith('new')) return ChangeKind.added;
  return null;
}

String _clean(String text) => text.replaceAll(_strayBold, '').trim();
