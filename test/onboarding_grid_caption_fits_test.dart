// On narrow screens (3 columns, ~100 px tiles) a two-line caption such as
// "TrainingPeaks Virtual" must still be drawn inside its tile instead of
// spilling out over the card border.
import 'package:bike_control/pages/onboarding/steps/step_app.dart' show OnboardingAppTile, onboardingAppBody;
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  Future<void> expectCaptionsInsideTiles(WidgetTester tester, {required double width}) async {
    await captureWidget(
      tester,
      name: 'onboarding_step_app_caption_fits_$width',
      width: width,
      locales: const ['de'],
      builder: (c) => onboardingAppBody(
        c,
        selected: SupportedApp.supportedApps.first,
        onSelect: (_) {},
      ),
    );

    for (final tile in find.byType(OnboardingAppTile).evaluate()) {
      final app = (tile.widget as OnboardingAppTile).app;
      final tileRect = tester.getRect(find.byWidget(tile.widget));
      final caption = find.descendant(of: find.byWidget(tile.widget), matching: find.text(app.name));
      final captionRect = tester.getRect(caption);
      expect(captionRect.bottom, lessThanOrEqualTo(tileRect.bottom),
          reason: '"${app.name}" caption spills below its tile at width $width: $captionRect vs $tileRect');
      expect(captionRect.top, greaterThanOrEqualTo(tileRect.top),
          reason: '"${app.name}" caption spills above its tile at width $width: $captionRect vs $tileRect');
    }
  }

  testWidgets('app grid captions fit inside their tiles at 340 px', (tester) async {
    await expectCaptionsInsideTiles(tester, width: 340);
  });

  testWidgets('app grid captions fit inside their tiles at 320 px', (tester) async {
    await expectCaptionsInsideTiles(tester, width: 320);
  });
}
