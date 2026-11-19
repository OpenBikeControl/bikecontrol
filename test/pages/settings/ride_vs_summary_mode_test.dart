// Ride's shifting summary must not name a mode it is about to take back:
// with nothing saved, the default mode waits on the trainer's feature probe
// (Target Power first, Track Resistance a moment later on most trainers).
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/settings/virtual_shifting_settings_page.dart' show rideVirtualShiftingSummary;
import 'package:flutter/widgets.dart' show Text;
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart' show VirtualShiftingMode;

import '../../helpers/live_trainer.dart';
import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  Future<(String, String)> summary(WidgetTester tester, {required bool modeKnown}) async {
    final definition = attachLiveTrainer(register: false).definition;
    definition.setVirtualShiftingMode(VirtualShiftingMode.targetPower);
    late String text;
    late String modeLabel;
    await captureWidget(
      tester,
      name: 'ride_vs_summary_mode_$modeKnown',
      width: 400,
      locales: const ['en'],
      builder: (context) {
        modeLabel = AppLocalizations.of(context).targetPowerMode;
        text = rideVirtualShiftingSummary(context, definition, modeKnown: modeKnown);
        return Text(text);
      },
    );
    return (text, modeLabel);
  }

  testWidgets('before the feature probe, an unsaved default mode is left out', (tester) async {
    final (text, modeLabel) = await summary(tester, modeKnown: false);
    expect(text, isNot(contains(modeLabel)));
  });

  testWidgets('a saved mode is always named', (tester) async {
    final (text, modeLabel) = await summary(tester, modeKnown: true);
    expect(text, contains(modeLabel));
  });
}
