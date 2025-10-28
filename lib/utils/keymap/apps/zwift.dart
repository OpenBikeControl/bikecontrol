import 'package:dartx/dartx.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/keymap/apps/supported_app.dart';
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
              .map((b) => KeyPair(buttons: [b], physicalKey: null, logicalKey: null, inGameAction: b.action))
              .toList(),
        ),
      );
}
