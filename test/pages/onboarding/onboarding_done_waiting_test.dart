// The done step while it waits for the trainer app: the status reads on one
// line beside a short app name, and the steps follow the method the rider
// switched on — Bluetooth for MyWhoosh pairs as a steering device.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show debugKeepsTrainerAppNamesInScreenshotMode;
import 'package:bike_control/pages/onboarding/steps/step_done.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

Widget _done(BuildContext c) => onboardingDoneBody(
  c,
  app: MyWhoosh(),
  controllerName: null,
  trainerName: null,
  appConnected: false,
  trainerAppConnected: false,
  reduceMotion: true,
  showTestMode: false,
  onPairController: () {},
);

Future<void> main() async {
  // Live binding with the real fonts: wrapping is the point, and the test
  // font's square glyphs wrap anything.
  await ensureSnapshotHarness();
  setUpAll(() => debugKeepsTrainerAppNamesInScreenshotMode = true);
  tearDownAll(() => debugKeepsTrainerAppNamesInScreenshotMode = false);
  tearDown(() async {
    core.bc2BluetoothEmulator.isStarted.value = false;
    await core.settings.setBc2BleEnabled(false);
  });

  testWidgets('"Warte auf MyWhoosh …" stays on one line beside the short name', (tester) async {
    await captureWidget(
      tester,
      name: 'onboarding_done_waiting',
      width: 358, // a 390 pt phone minus the step's padding
      locales: const ['de'],
      settle: false,
      builder: _done,
      beforeCapture: (tester) async {
        final l = await AppLocalizations.load(const Locale('de'));
        final label = find.text(l.onboardingSummaryWaitingFor('MyWhoosh'));
        expect(label, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(label);
        final lineTops = paragraph
            .getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: paragraph.text.toPlainText().length))
            .map((b) => b.top)
            .toSet();
        expect(lineTops, hasLength(1), reason: 'wrapped onto a second line');
      },
    );
  });

  testWidgets('switching Bluetooth on swaps in the steering-device steps', (tester) async {
    await captureWidget(
      tester,
      name: 'onboarding_done_waiting_bc2',
      width: 358,
      settle: false,
      builder: _done,
      beforeCapture: (tester) async {
        final l = await AppLocalizations.load(const Locale('en'));
        expect(find.text(l.onboardingGuideMyWhoosh2), findsOneWidget, reason: 'network steps first');
        await core.settings.setBc2BleEnabled(true);
        core.bc2BluetoothEmulator.isStarted.value = true;
        await tester.pump();
        expect(find.text(l.onboardingGuideMyWhooshBc2Pair), findsOneWidget);
        expect(find.text(l.onboardingGuideMyWhoosh2), findsNothing);
      },
    );
  });
}
