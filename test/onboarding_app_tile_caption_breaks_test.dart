// App names on the step-1 tiles wrap only between words: at phone width a
// three-column tile is ~110 px, narrower than "TrainingPeaks" in real fonts.
import 'package:bike_control/pages/onboarding/steps/step_app.dart' show OnboardingAppTile, onboardingAppBody;
import 'package:flutter/widgets.dart' show KeyedSubtree, ValueKey;
import 'package:flutter_test/flutter_test.dart';

import 'helpers/text_breaks.dart';
import 'widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  for (final locale in const ['en', 'de', 'es', 'fr', 'it', 'pl']) {
    testWidgets('app tile names break only between words at 380 px ($locale)', (tester) async {
      // 380 px screen minus the wizard body's 16 px padding on either side.
      // Shot twice: the first pass loads the real fonts, the second lays the
      // tiles out afresh with them — the first layout ran on the test font,
      // and nothing re-measures once the real one arrives.
      for (final pass in const ['fonts', 'measured']) {
        await captureWidget(
          tester,
          name: 'onboarding_step_app_tile_breaks_$locale',
          width: 348,
          locales: [locale],
          builder: (c) => KeyedSubtree(
            key: ValueKey(pass),
            child: onboardingAppBody(c, selected: null, onSelect: (_) {}),
          ),
        );
      }

      for (final tile in find.byType(OnboardingAppTile).evaluate()) {
        final app = (tile.widget as OnboardingAppTile).app;
        final caption = find.descendant(of: find.byWidget(tile.widget), matching: find.text(app.name));
        expectBreaksOnlyBetweenWords(tester, caption, reason: '[$locale] "${app.name}"');
      }
    });
  }
}
