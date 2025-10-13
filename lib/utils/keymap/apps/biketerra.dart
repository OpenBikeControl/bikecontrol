import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:swift_control/utils/keymap/apps/supported_app.dart';

import '../buttons.dart';
import '../keymap.dart';

class Biketerra extends SupportedApp {
  Biketerra()
    : super(
        name: 'Biketerra',
        packageName: "biketerra",
        keymap: Keymap(
          keyPairs: [
            KeyPair(
              buttons: ControllerButton.values.filter((e) => e.action == InGameAction.shiftDown).toList(),
              physicalKey: PhysicalKeyboardKey.keyS,
              logicalKey: LogicalKeyboardKey.keyS,
            ),
            KeyPair(
              buttons: ControllerButton.values.filter((e) => e.action == InGameAction.shiftUp).toList(),
              physicalKey: PhysicalKeyboardKey.keyW,
              logicalKey: LogicalKeyboardKey.keyW,
            ),
            KeyPair(
              buttons: ControllerButton.values.filter((e) => e.action == InGameAction.navigateRight).toList(),
              physicalKey: PhysicalKeyboardKey.arrowRight,
              logicalKey: LogicalKeyboardKey.arrowRight,
            ),
            KeyPair(
              buttons: ControllerButton.values.filter((e) => e.action == InGameAction.navigateLeft).toList(),
              physicalKey: PhysicalKeyboardKey.arrowLeft,
              logicalKey: LogicalKeyboardKey.arrowLeft,
            ),
            KeyPair(
              buttons: ControllerButton.values.filter((e) => e.action == InGameAction.toggleUi).toList(),
              physicalKey: PhysicalKeyboardKey.keyU,
              logicalKey: LogicalKeyboardKey.keyU,
            ),
          ],
        ),
      );
}
