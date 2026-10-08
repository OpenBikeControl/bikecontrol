// Ride's "Your buttons" list in the narrow right-hand column of a tablet or
// desktop window (~290 px card on the 853 / 917 px store boards): a button's
// name never breaks mid-word ("Navigatio" / "n Left") and the trigger under
// it reads whole ("Long Pre…"), in every locale.
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_play.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/home/your_buttons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../helpers/text_breaks.dart';
import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  KeyPair pair(ControllerButton button, InGameAction action, [ButtonTrigger trigger = ButtonTrigger.singleClick]) =>
      KeyPair(buttons: [button], physicalKey: null, logicalKey: null, inGameAction: action, trigger: trigger);

  final keymap = Keymap(
    keyPairs: [
      pair(ZwiftButtons.navigationLeft, InGameAction.steerLeft, ButtonTrigger.longPress),
      pair(ZwiftButtons.navigationRight, InGameAction.steerRight, ButtonTrigger.longPress),
      pair(ZwiftButtons.navigationUp, InGameAction.up),
      pair(ZwiftButtons.navigationDown, InGameAction.down),
    ],
  );
  final device = ZwiftPlay(
    BleDevice(name: 'Zwift Play', deviceId: 'fit'),
    deviceType: ZwiftDeviceType.playLeft,
  );

  for (final locale in const ['en', 'de', 'es', 'fr', 'it', 'pl']) {
    testWidgets('290 px card: every row reads whole, broken only between words ($locale)', (tester) async {
      for (final pass in const ['fonts', 'measured']) {
        await captureWidget(
          tester,
          name: 'ride_button_list_fit_$locale',
          width: 290,
          locales: [locale],
          builder: (_) => KeyedSubtree(
            key: ValueKey(pass),
            child: ControllerButtonsCard(
              device: device,
              keymap: keymap,
              presses: ValueNotifier((button: null, generation: 0)),
              onUpdate: () {},
              onEdit: () {},
              wide: true,
            ),
          ),
        );
      }
      for (final button in [
        ZwiftButtons.navigationLeft,
        ZwiftButtons.navigationRight,
        ZwiftButtons.navigationUp,
        ZwiftButtons.navigationDown,
      ]) {
        final row = find.byKey(ValueKey('ride-button-row-${button.name}'));
        expect(row, findsOneWidget, reason: button.name);
        expectReadsWhole(tester, row, reason: '[$locale] ${button.name}');
      }
    });
  }
}
