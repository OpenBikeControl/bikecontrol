import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:swift_control/utils/keymap/apps/supported_app.dart';

import '../buttons.dart';
import '../keymap.dart';

class MyWhoosh extends SupportedApp {
  MyWhoosh()
    : super(
        name: 'MyWhoosh',
        packageName: "com.mywhoosh.whooshgame",
        keymap: Keymap(
          keyPairs: [
            KeyPair(
              buttons: ControllerButton.values.filter((e) => e.action == InGameAction.shiftDown).toList(),
              physicalKey: PhysicalKeyboardKey.keyI,
              logicalKey: LogicalKeyboardKey.keyI,
              touchPosition: Offset(80, 94),
            ),
            KeyPair(
              buttons: ControllerButton.values.filter((e) => e.action == InGameAction.shiftUp).toList(),
              physicalKey: PhysicalKeyboardKey.keyK,
              logicalKey: LogicalKeyboardKey.keyK,
              touchPosition: Offset(98, 94),
            ),
            KeyPair(
              buttons: ControllerButton.values.filter((e) => e.action == InGameAction.navigateRight).toList(),
              physicalKey: PhysicalKeyboardKey.keyD,
              logicalKey: LogicalKeyboardKey.keyD,
              touchPosition: Offset(98, 80),
              isLongPress: true,
            ),
            KeyPair(
              buttons: ControllerButton.values.filter((e) => e.action == InGameAction.navigateLeft).toList(),
              physicalKey: PhysicalKeyboardKey.keyA,
              logicalKey: LogicalKeyboardKey.keyA,
              touchPosition: Offset(32, 80),
              isLongPress: true,
            ),
            KeyPair(
              buttons: ControllerButton.values.filter((e) => e.action == InGameAction.toggleUi).toList(),
              physicalKey: PhysicalKeyboardKey.keyH,
              logicalKey: LogicalKeyboardKey.keyH,
            ),
          ],
        ),
      );
}
