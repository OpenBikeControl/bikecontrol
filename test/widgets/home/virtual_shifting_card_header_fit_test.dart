// Ride's virtual shifting card: the header's title and trainer name read
// whole beside (or above) the SIM / ERG switch — in Ride's narrow left column
// on a tablet or desktop (~295 px card) and on a 414 px phone — and the
// summary at the card's foot ("24 vitesses · Puissance …") is never cut.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/settings/virtual_shifting_settings_page.dart' show rideVirtualShiftingSummary;
import 'package:bike_control/widgets/home/ride_overlay_notice.dart';
import 'package:bike_control/widgets/home/virtual_shifting_card.dart';
import 'package:flutter/widgets.dart' show EdgeInsets, KeyedSubtree, ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons;

import '../../helpers/live_trainer.dart';
import '../../helpers/text_breaks.dart';
import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  const locales = ['en', 'de', 'es', 'fr', 'it', 'pl'];

  // Ride's two-column card on the 853 / 917 px store boards, and the card on
  // a 414 px phone (12 px page margin either side).
  for (final width in const [295.0, 390.0]) {
    for (final locale in locales) {
      testWidgets('${width.toInt()} px card: the header reads whole ($locale)', (tester) async {
        final definition = attachLiveTrainer(register: false).definition;
        for (final pass in const ['fonts', 'measured']) {
          await captureWidget(
            tester,
            name: 'vs_card_header_fit_${width.toInt()}_$locale',
            width: width,
            padding: const EdgeInsets.all(12),
            locales: [locale],
            builder: (_) => KeyedSubtree(
              key: ValueKey(pass),
              child: VirtualShiftingCard(
                definition: definition,
                trainerName: 'Smart Trainer',
                onOpenSettings: () {},
                onOpenTrainer: () {},
              ),
            ),
          );
        }
        for (final key in const ['ride-vs-settings-link', 'ride-vs-trainer-link']) {
          expectReadsWhole(tester, find.byKey(ValueKey(key)), reason: '[$locale] $key');
        }
        // On a phone, English keeps the switch beside the title, where a
        // rider's thumb knows it.
        if (locale == 'en' && width == 390) {
          expect(find.byKey(const ValueKey('ride-vs-header-stacked')), findsNothing);
          final title = tester.getRect(find.byKey(const ValueKey('ride-vs-settings-link')));
          final sim = tester.getRect(find.byKey(const ValueKey('ride-vs-mode-sim')));
          expect(sim.top, lessThan(title.bottom), reason: 'the switch sits beside the title');
        }
      });
    }
  }

  for (final locale in locales) {
    testWidgets('the summary line at a 414 px phone card\'s foot reads whole ($locale)', (tester) async {
      final definition = attachLiveTrainer(register: false).definition;
      for (final pass in const ['fonts', 'measured']) {
        await captureWidget(
          tester,
          name: 'vs_settings_line_fit_$locale',
          // The phone card's 390 less its 16 px padding either side.
          width: 358,
          locales: [locale],
          builder: (context) => KeyedSubtree(
            key: ValueKey(pass),
            child: RideSettingsLine(
              key: const ValueKey('line'),
              icon: LucideIcons.slidersHorizontal,
              text: rideVirtualShiftingSummary(context, definition),
              linkLabel: AppLocalizations.of(context).rideVsSettingsLink,
              onPressed: () {},
            ),
          ),
        );
      }
      expectReadsWhole(tester, find.byKey(const ValueKey('line')), reason: '[$locale]');
    });
  }
}
