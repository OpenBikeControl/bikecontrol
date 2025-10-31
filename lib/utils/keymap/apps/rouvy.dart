import 'package:dartx/dartx.dart';
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
            KeyPair(
              buttons: ControllerButton.values.filter((e) => e.action == InGameAction.shiftDown).toList(),
              inGameAction: InGameAction.shiftDown,
              physicalKey: null,
              logicalKey: null,
            ),
            KeyPair(
              buttons: ControllerButton.values.filter((e) => e.action == InGameAction.shiftUp).toList(),
              inGameAction: InGameAction.shiftUp,
              physicalKey: null,
              logicalKey: null,
            ),
          ],
        ),
      );
}
