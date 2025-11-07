import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:swift_control/bluetooth/devices/zwift/constants.dart';
import 'package:swift_control/utils/keymap/apps/supported_app.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/utils/requirements/multi.dart';

import '../keymap.dart';

class Rouvy extends SupportedApp {
  Rouvy()
    : super(
        name: 'Rouvy',
        packageName: "eu.virtualtraining.rouvy.android",
        compatibleTargets: Target.values,
        supportsZwiftEmulation: true,
        keymap: Keymap(
          keyPairs: [
            // https://support.rouvy.com/hc/de/articles/32452137189393-Virtuelles-Schalten#h_01K5GMVG4KVYZ0Y6W7RBRZC9MA
            KeyPair(
              buttons: ControllerButton.values.filter((e) => e.action == InGameAction.shiftDown).toList(),
              inGameAction: InGameAction.shiftDown,
              physicalKey: PhysicalKeyboardKey.numpadSubtract,
              logicalKey: LogicalKeyboardKey.numpadSubtract,
            ),
            KeyPair(
              buttons: ControllerButton.values.filter((e) => e.action == InGameAction.shiftUp).toList(),
              inGameAction: InGameAction.shiftUp,
              physicalKey: PhysicalKeyboardKey.numpadAdd,
              logicalKey: LogicalKeyboardKey.numpadAdd,
            ),
            // like escape
            KeyPair(
              buttons: [ZwiftButtons.b],
              physicalKey: PhysicalKeyboardKey.keyB,
              logicalKey: LogicalKeyboardKey.keyB,
              inGameAction: InGameAction.back,
            ),
          ],
        ),
      );
}
