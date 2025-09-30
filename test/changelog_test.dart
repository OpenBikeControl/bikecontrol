import 'package:flutter_test/flutter_test.dart';
import 'package:swift_control/utils/changelog.dart';

void main() {
  group('ChangelogParser', () {
    test('parses changelog entries correctly', () {
      const testContent = '''
### 2.6.0 (2025-09-28)
- Fix crashes on some Android devices
- refactor touch placements: show touches on screen
- show firmware version of connected device

### 2.5.0 (2025-09-25)
- Improve usability
- SwiftControl is now available via the Play Store
  - SwiftControl will continue to be available to download for free on GitHub
''';

      final entries = ChangelogParser.parseContent(testContent);

      expect(entries.length, 2);
      
      expect(entries[0].version, '2.6.0');
      expect(entries[0].date, '2025-09-28');
      expect(entries[0].changes.length, 3);
      expect(entries[0].changes[0], 'Fix crashes on some Android devices');
      
      expect(entries[1].version, '2.5.0');
      expect(entries[1].date, '2025-09-25');
      expect(entries[1].changes.length, 3);
      expect(entries[1].changes[0], 'Improve usability');
      expect(entries[1].changes[1], 'SwiftControl is now available via the Play Store');
      expect(entries[1].changes[2], 'SwiftControl will continue to be available to download for free on GitHub');
    });

    test('handles empty content', () {
      const testContent = '';
      final entries = ChangelogParser.parseContent(testContent);
      expect(entries.length, 0);
    });

    test('handles single entry', () {
      const testContent = '''
### 1.0.0 (2025-01-01)
- Initial release
''';

      final entries = ChangelogParser.parseContent(testContent);

      expect(entries.length, 1);
      expect(entries[0].version, '1.0.0');
      expect(entries[0].changes.length, 1);
      expect(entries[0].changes[0], 'Initial release');
    });

    test('ChangelogEntry toString formats correctly', () {
      final entry = ChangelogEntry(
        version: '1.0.0',
        date: '2025-01-01',
        changes: ['Change 1', 'Change 2'],
      );

      final result = entry.toString();
      expect(result, contains('### 1.0.0 (2025-01-01)'));
      expect(result, contains('- Change 1'));
      expect(result, contains('- Change 2'));
    });
  });
}
