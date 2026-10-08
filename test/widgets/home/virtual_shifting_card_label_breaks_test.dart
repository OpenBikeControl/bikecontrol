// The labels under Ride's power / cadence / ratio (/ heart rate) readings
// break only between words, in every locale, on a 390 px phone: German
// "Trittfrequenz" and "Übersetzung" used to wrap mid-word in the drivetrain's
// column ("Trittfrequen" / "z").
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/widgets/home/virtual_shifting_card.dart';
import 'package:flutter/widgets.dart' show EdgeInsets, KeyedSubtree, ValueKey;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/live_trainer.dart';
import '../../helpers/text_breaks.dart';
import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  // Ride's card on a 390 px phone: the page keeps 12 px either side.
  const cardWidth = 366.0;

  for (final heart in const [false, true]) {
    for (final locale in const ['en', 'de', 'es', 'fr', 'it', 'pl']) {
      final variant = heart ? 'with heart rate' : 'without heart rate';
      testWidgets('stat labels break only between words at 390 px, $variant ($locale)', (tester) async {
        final definition = attachLiveTrainer(register: false).definition;
        if (heart) definition.setExternalHeartRate(142);

        // Twice: the first pass loads the real fonts, the second lays the card
        // out afresh with them (nothing re-measures once they arrive).
        for (final pass in const ['fonts', 'measured']) {
          await captureWidget(
            tester,
            name: 'vs_card_stat_breaks_${heart ? 'heart_' : ''}$locale',
            width: cardWidth,
            padding: const EdgeInsets.all(12),
            locales: [locale],
            builder: (_) => KeyedSubtree(
              key: ValueKey(pass),
              child: VirtualShiftingCard(definition: definition, trainerName: 'KICKR CORE'),
            ),
          );
        }

        final l = AppLocalizations.current;
        final labels = [
          l.sensorQuantityPower,
          l.sensorQuantityCadence,
          l.rideRatio,
          if (heart) l.sensorQuantityHeartRate,
        ];
        for (final label in labels) {
          final finder = find.descendant(of: find.byType(RideStat), matching: find.text(label));
          expect(finder, findsOneWidget, reason: '[$locale] "$label"');
          expectBreaksOnlyBetweenWords(tester, finder, reason: '[$locale] "$label"');
        }

        // English keeps the phone layout: without heart rate the readings sit
        // under the drivetrain, beside the gear, not below it.
        if (locale == 'en' && !heart) {
          final power = tester.getRect(find.text(l.sensorQuantityPower));
          final gear = tester.getRect(find.byKey(const ValueKey('ride-vs-number')));
          final shiftUp = tester.getRect(find.bySemanticsLabel(l.actionShiftUp));
          expect(power.right, lessThan(gear.left), reason: 'the readings sit left of the gear');
          expect(power.top, lessThan(shiftUp.bottom), reason: 'the readings sit beside the gear, not under it');
        }
      });
    }
  }
}
