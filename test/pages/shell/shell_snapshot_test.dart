@Tags(['screenshots'])
library;

import 'package:bike_control/pages/navigation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/shell_harness.dart';
import '../../widget_snapshot.dart';

/// Renders the app shell's navigation chrome at each layout. Run:
/// `flutter test --run-skipped test/pages/shell/shell_snapshot_test.dart`
/// Output: `build/snapshots/shell-<width>x<height>-<theme>.png`
Future<void> main() async {
  await ensureSnapshotHarness();
  quietShellEnvironment();

  const sizes = [Size(390, 844), Size(820, 1180), Size(1180, 820), Size(1280, 800)];
  for (final size in sizes) {
    for (final brightness in Brightness.values) {
      final name = 'shell-${size.width.toInt()}x${size.height.toInt()}-${brightness.name}';
      testWidgets(name, (tester) async {
        await captureWidget(
          tester,
          name: name,
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
    }
  }
}
