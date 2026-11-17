@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:bike_control/models/changelog.dart';
import 'package:bike_control/pages/navigation.dart';
import 'package:bike_control/widgets/changelog/whats_new.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/shell_harness.dart';
import '../../widget_snapshot.dart';

/// The "What's new" banner in the shell and the page it opens. Run:
/// `flutter test --run-skipped test/pages/changelog/whats_new_snapshot_test.dart`
/// Output: `build/snapshots/whats-new-*.png`
Future<void> main() async {
  await ensureSnapshotHarness();
  quietShellEnvironment();
  final releases = releasesSince(parseChangelog(File('CHANGELOG.md').readAsStringSync()), '7.4.0');
  final version = releases.first.version;

  const sizes = [Size(390, 844), Size(1280, 800)];
  for (final size in sizes) {
    for (final brightness in Brightness.values) {
      final tag = '${size.width.toInt()}x${size.height.toInt()}-${brightness.name}';
      testWidgets('whats-new-banner-$tag', (tester) async {
        WhatsNew.pending.value = (version, '7.4.0');
        addTearDown(() => WhatsNew.pending.value = null);
        await captureWidget(
          tester,
          name: 'whats-new-banner-$tag',
          width: size.width,
          height: size.height,
          padding: EdgeInsets.zero,
          pixelRatio: 2,
          brightness: brightness,
          settle: false,
          builder: (context) => const Navigation(),
        );
        await disposeShell(tester);
      });

      for (final scrolled in [false, true]) {
        final name = 'whats-new-page${scrolled ? '-end' : ''}-$tag';
        testWidgets(name, (tester) async {
          await captureWidget(
            tester,
            name: name,
            width: size.width,
            height: size.height,
            padding: EdgeInsets.zero,
            pixelRatio: 2,
            brightness: brightness,
            builder: (context) => WhatsNewPage(currentVersion: version, sinceVersion: '7.4.0', releases: releases),
            beforeCapture: scrolled
                ? (tester) async {
                    await tester.ensureVisible(find.byKey(const ValueKey('whats-new-rate')));
                    await tester.pumpAndSettle();
                  }
                : null,
          );
        });
      }
    }
  }

  testWidgets('whats-new-page-de', (tester) async {
    final de = localizeReleases(
      releases,
      parseChangelog(File('changelog/de.md').readAsStringSync()),
    );
    await captureWidget(
      tester,
      name: 'whats-new-page-de',
      locales: const ['de'],
      width: 390,
      height: 844,
      padding: EdgeInsets.zero,
      pixelRatio: 2,
      brightness: Brightness.light,
      builder: (context) => WhatsNewPage(currentVersion: version, sinceVersion: '7.4.0', releases: de),
    );
  });
}
