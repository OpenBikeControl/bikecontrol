import 'package:flutter/services.dart';

class ChangelogEntry {
  final String version;
  final String date;
  final List<String> changes;

  ChangelogEntry({
    required this.version,
    required this.date,
    required this.changes,
  });

  @override
  String toString() {
    return '### $version ($date)\n${changes.map((c) => '- $c').join('\n')}';
  }
}

class ChangelogParser {
  static Future<List<ChangelogEntry>> parse() async {
    final content = await rootBundle.loadString('CHANGELOG.md');
    return parseContent(content);
  }

  static List<ChangelogEntry> parseContent(String content) {
    final entries = <ChangelogEntry>[];
    final lines = content.split('\n');
    
    ChangelogEntry? currentEntry;
    
    for (var line in lines) {
      // Check if this is a version header (e.g., "### 2.6.0 (2025-09-28)")
      if (line.startsWith('### ')) {
        // Save previous entry if exists
        if (currentEntry != null) {
          entries.add(currentEntry);
        }
        
        // Parse new entry
        final header = line.substring(4).trim();
        final match = RegExp(r'^(\S+)\s+\(([^)]+)\)').firstMatch(header);
        if (match != null) {
          currentEntry = ChangelogEntry(
            version: match.group(1)!,
            date: match.group(2)!,
            changes: [],
          );
        }
      } else if (line.startsWith('- ') && currentEntry != null) {
        // Add change to current entry
        currentEntry.changes.add(line.substring(2).trim());
      } else if (line.startsWith('  - ') && currentEntry != null) {
        // Sub-bullet point
        currentEntry.changes.add(line.substring(4).trim());
      }
    }
    
    // Add the last entry
    if (currentEntry != null) {
      entries.add(currentEntry);
    }
    
    return entries;
  }

  static Future<ChangelogEntry?> getLatestEntry() async {
    final entries = await parse();
    return entries.isNotEmpty ? entries.first : null;
  }

  static Future<String?> getLatestEntryForPlayStore() async {
    final entry = await getLatestEntry();
    if (entry == null) return null;
    
    // Format for Play Store: just the changes, no version header
    return entry.changes.join('\n');
  }
}
