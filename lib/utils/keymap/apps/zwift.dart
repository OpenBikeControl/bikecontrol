import 'package:dartx/dartx.dart';
import 'package:swift_control/bluetooth/devices/zwift/constants.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/keymap/apps/supported_app.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/utils/requirements/multi.dart';
import 'package:universal_ble/universal_ble.dart';

import '../keymap.dart';

class Zwift extends SupportedApp {
  Zwift()
    : super(
        name: 'Zwift',
        packageName: "com.zwift.zwiftgame",
        connectionType: ConnectionType.zwift,
        compatibleTargets: Target.values.whereNot((e) => e == Target.thisDevice).toList(),
        keymap: Keymap(
          keyPairs: ZwiftClickV2(BleDevice(name: '', deviceId: '')).availableButtons
              .map(
                (b) => KeyPair(
                  buttons: [b],
                  physicalKey: null,
                  logicalKey: null,
                  inGameAction: switch (true) {
                    _ when b == ZwiftButtons.navigationUp => InGameAction.openActionBar,
                    _ when b == ZwiftButtons.navigationDown => InGameAction.uturn,
                    _ when b == ZwiftButtons.navigationLeft => InGameAction.steerLeft,
                    _ when b == ZwiftButtons.navigationRight => InGameAction.steerRight,
                    _ when b == ZwiftButtons.shiftUpLeft => InGameAction.shiftDown,
                    _ when b == ZwiftButtons.shiftUpRight => InGameAction.shiftUp,
                    _ when b == ZwiftButtons.shiftDownLeft => InGameAction.shiftDown,
                    _ when b == ZwiftButtons.shiftDownRight => InGameAction.shiftUp,
                    _ when b == ZwiftButtons.paddleLeft => InGameAction.shiftDown,
                    _ when b == ZwiftButtons.paddleRight => InGameAction.shiftUp,
                    _ when b == ZwiftButtons.y => InGameAction.usePowerUp,
                    _ when b == ZwiftButtons.a => InGameAction.select,
                    _ when b == ZwiftButtons.b => InGameAction.back,
                    _ when b == ZwiftButtons.z => InGameAction.rideOnBomb,
                    _ => null,
                  },
                ),
              )
              .toList(),
        ),
      );
}
