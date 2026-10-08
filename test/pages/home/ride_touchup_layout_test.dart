// The brand touch-up recolours Ride; it must not move anything. A rider's
// muscle memory for SIM / ERG, − / + and "Edit buttons" stays where it was:
// these are Ride's positions at 390 × 844 before the touch-up.
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/live_trainer.dart';
import '../../helpers/shell_harness.dart';
import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();
  quietShellEnvironment();

  for (final brightness in Brightness.values) {
    testWidgets('Ride keeps its layout at 390 x 844 (${brightness.name})', (tester) async {
      attachLiveTrainer();
      core.connection.hasDevices.value = true;
      await pumpShell(tester, const Size(390, 844), brightness: brightness);
      await tester.pump(const Duration(seconds: 1));

      Rect rect(String key) => tester.getRect(find.byKey(ValueKey(key)).first);
      final card = rect('ride-vs-live');
      final number = rect('ride-vs-number');
      final erg = rect('ride-vs-mode-erg');
      final buttons = rect('ride-your-buttons');
      final title = tester.getRect(find.text('BikeControl').first);

      const tolerance = 12.0;
      expect(card.top, closeTo(_before.cardTop, tolerance), reason: 'shifting card top');
      expect(card.height, closeTo(_before.cardHeight, tolerance), reason: 'shifting card height');
      expect(number.top, closeTo(_before.numberTop, tolerance), reason: 'gear numeral');
      expect(erg.center.dy, closeTo(_before.ergCenterY, tolerance), reason: 'SIM / ERG');
      expect(title.center.dy, closeTo(_before.titleCenterY, 2), reason: 'large title');
      expect(buttons.top, closeTo(_before.buttonsTop, tolerance), reason: 'Your buttons');

      await disposeShell(tester);
    });
  }
}

/// Measured on the layout before the touch-up; the numeral and everything
/// under it since moved down once, on purpose, for room under the brand band
/// (ride_vs_band_gap_test.dart). The card has since grown by one line, on
/// purpose too: what the selected SIM / ERG mode does, under the readings —
/// everything above that line stays put. And the whole card sits 29 dp
/// higher since the banner's steps lost their buttons for a chevron: rows
/// with the full width for their words wrap less.
const _before = (
  cardTop: 600.0,
  cardHeight: 517.0,
  numberTop: 720.0,
  ergCenterY: 648.0,
  buttonsTop: 1137.0,
  titleCenterY: 32.0,
);
