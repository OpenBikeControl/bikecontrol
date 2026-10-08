// CHANGELOG.md as releases: version, date, the notes above the lists, and
// the entries grouped by what kind of change they are.
import 'dart:io';

import 'package:bike_control/models/changelog.dart';
import 'package:flutter_test/flutter_test.dart';

const _sample = '''
### 7.0.0 (18-09-2026)
**Features**:
- Sensors: pair a heart-rate strap.
- Shift feedback: sound and vibration.

Read more in our blog at https://bikecontrol.app/blog/bikecontrol-7-0/

**Fixes**:
- Smart trainers: more trainers.

### 5.5.0 (14-05-2026)

**Features**:
Virtual Shifting overlay:
- on macOS you can now show the gear
- on iOS the Dynamic Island

Virtual Shifting:
- Support for devices without FTMS:
  - FE-C over BLE devices
  - fix for Zwift ready Smart Trainers

### 5.0.0 (10-03-2026)

****BikeControl Pro is now available. *Everyone keeps their functions*.

**Fixes**:
- You can now download BikeControl without the Store****

### 4.7.0 (04-02-2026)

**Features**:
- new connection method: act as Bluetooth Keyboard:
Your device can now act as Bluetooth keyboard.
- added shortcuts for [Rouvy](https://rouvy.com)

**Fixes:**
- iOS: Remote pairing now works again

### 3.5.0 (16-11-2025)
**New Features:**
- Dark mode support

### 3.2.0 (2025-10-22)
- a brand-new way of controlling the app:
  - device pairing no longer required
''';

void main() {
  final releases = parseChangelog(_sample);

  test('one release per version heading, newest first, with its date', () {
    expect(releases.map((r) => r.version), ['7.0.0', '5.5.0', '5.0.0', '4.7.0', '3.5.0', '3.2.0']);
    expect(releases.first.date, DateTime(2026, 9, 18));
    // Both date orders the file has used.
    expect(releases.last.date, DateTime(2025, 10, 22));
  });

  test('entries are grouped by kind, in the order the file lists them', () {
    final latest = releases.first;
    expect(latest.sections.map((s) => s.kind), [ChangeKind.added, ChangeKind.fixed]);
    expect(latest.sections.first.entries.map((e) => e.text), [
      'Sensors: pair a heart-rate strap.',
      'Shift feedback: sound and vibration.',
    ]);
    expect(latest.sections.last.entries.single.text, 'Smart trainers: more trainers.');
  });

  test('a paragraph between the lists is a note of the release, not an entry', () {
    expect(releases.first.notes, ['Read more in our blog at https://bikecontrol.app/blog/bikecontrol-7-0/']);
  });

  test('plain "Title:" lines over a list are named groups of the kind above them', () {
    final sections = releases[1].sections;
    expect(sections.map((s) => s.title), ['Virtual Shifting overlay', 'Virtual Shifting']);
    expect(sections.every((s) => s.kind == ChangeKind.added), isTrue);
    final nested = sections.last.entries.single;
    expect(nested.text, 'Support for devices without FTMS:');
    expect(nested.children, ['FE-C over BLE devices', 'fix for Zwift ready Smart Trainers']);
  });

  test('stray bold markers are dropped', () {
    final pro = releases[2];
    expect(pro.notes.single, 'BikeControl Pro is now available. *Everyone keeps their functions*.');
    expect(pro.sections.single.entries.single.text, 'You can now download BikeControl without the Store');
  });

  test('a line run on under an item belongs to it; "Fixes:" and "New Features:" are recognised', () {
    final r = releases[3];
    expect(r.sections.map((s) => s.kind), [ChangeKind.added, ChangeKind.fixed]);
    expect(
      r.sections.first.entries.first.text,
      'new connection method: act as Bluetooth Keyboard: Your device can now act as Bluetooth keyboard.',
    );
    expect(releases[4].sections.single.kind, ChangeKind.added);
  });

  test('a list with no heading is an untitled group of changes', () {
    final r = releases.last;
    expect(r.sections.single.kind, ChangeKind.other);
    expect(r.sections.single.title, isNull);
    expect(r.sections.single.entries.single.children, ['device pairing no longer required']);
  });

  test('releases since a version: everything newer than the last one seen', () {
    expect(releasesSince(releases, '5.0.0').map((r) => r.version), ['7.0.0', '5.5.0']);
    expect(releasesSince(releases, '7.0.0'), isEmpty);
    expect(releasesSince(releases, 'not-a-version').map((r) => r.version), ['7.0.0']);
  });

  test('the bundled CHANGELOG.md parses into dated releases with entries', () {
    final real = parseChangelog(File('CHANGELOG.md').readAsStringSync());
    expect(real.length, greaterThan(40));
    expect(real.every((r) => r.date != null), isTrue);
    expect(real.every((r) => r.sections.isNotEmpty || r.notes.isNotEmpty), isTrue);
    expect(real.expand((r) => r.sections).expand((s) => s.entries).any((e) => e.text.contains('**')), isFalse);
  });
}
