// Ride's "Your buttons" card on a portrait Android tablet (~600 px), the
// rider's MyWhoosh setup over Local: the list beside the pods got a column so
// narrow that every action wrapped to five lines and broke mid-word
// ("Verbindungs" / "methode", "(Ru" / "nterschalten)"); the same
// "doesn't work yet" sentence stood on ten rows; and Local's tap actions
// read as raw coordinates ("X:80, Y:94 (Shift down)").
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/utils/actions/base_actions.dart' show StubActions, SupportedMode;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/home/your_buttons.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../helpers/text_breaks.dart';
import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  setUp(() async {
    // The harness turns screenshotMode on, which counts as a live connection
    // method; the rider had none but Local.
    screenshotMode = false;
    debugHostPlatformOverride = TargetPlatform.android;
    core.settings.setTrainerApp(MyWhoosh());
    // "This device" as stored, without setLastTarget swapping in the real
    // Android handler (and its accessibility-service channels).
    await core.settings.prefs.setString('last_target', Target.thisDevice.name);
    core.actionHandler = StubActions(supportedModes: const [SupportedMode.touch]);
    core.actionHandler.init(MyWhoosh());
  });
  tearDown(() {
    debugHostPlatformOverride = null;
    screenshotMode = true;
  });

  final device = ZwiftRide(BleDevice(name: 'Zwift Ride', deviceId: 'tablet-ride'));
  final buttons = device.availableButtons.distinctBy((b) => b.name).toList();
  // Her mapping: shifting on Local taps, everything else on actions only a
  // connection method can carry.
  final keymap = Keymap(
    keyPairs: [
      for (final button in buttons)
        switch (button.action) {
          InGameAction.shiftUp || InGameAction.shiftDown => KeyPair(
            buttons: [button],
            physicalKey: null,
            logicalKey: null,
            touchPosition: Offset(button.action == InGameAction.shiftUp ? 97 : 80, 94),
            inGameAction: button.action,
          ),
          final action => KeyPair(
            buttons: [button],
            physicalKey: null,
            logicalKey: null,
            inGameAction: action ?? InGameAction.toggleUi,
            trigger: button.action == InGameAction.navigateLeft || button.action == InGameAction.navigateRight
                ? ButtonTrigger.longPress
                : ButtonTrigger.singleClick,
          ),
        },
    ],
  );

  for (final locale in const ['en', 'de', 'es', 'fr', 'it', 'pl']) {
    testWidgets('600 px tablet card: every row reads whole, no coordinates, one "waits" note ($locale)', (
      tester,
    ) async {
      for (final pass in const ['fonts', 'measured']) {
        await captureWidget(
          tester,
          name: 'ride_button_list_tablet_$locale',
          width: 600,
          locales: [locale],
          builder: (_) => KeyedSubtree(
            key: ValueKey(pass),
            child: ControllerButtonsCard(
              device: device,
              keymap: keymap,
              presses: ValueNotifier((button: null, generation: 0, trigger: null)),
              onUpdate: () {},
              onEdit: () {},
              wide: true,
            ),
          ),
        );
      }
      final l = AppLocalizations.current;
      expect(core.logic.showLocalRemoteOptions, isTrue, reason: 'harness must reproduce Local touch mode');
      expect(find.textContaining(RegExp(r'X:\d+, Y:\d+')), findsNothing, reason: 'raw tap coordinates shown');
      expect(find.text(l.actionWaitsForConnectionMethod), findsNothing, reason: 'repeated on every row');
      expect(find.byKey(const ValueKey('ride-button-list-waits-note')), findsOneWidget);
      expect(find.text(l.actionShiftDown), findsWidgets, reason: 'a Local tap reads as its action');
      for (final button in buttons) {
        final row = find.byKey(ValueKey('ride-button-row-${button.name}'));
        expect(row, findsOneWidget, reason: button.name);
        expectReadsWhole(tester, row, reason: '[$locale] ${button.name}');
        expect(tester.getSize(row).height, lessThanOrEqualTo(48), reason: '[$locale] ${button.name} row too tall');
      }
    });
  }
}
