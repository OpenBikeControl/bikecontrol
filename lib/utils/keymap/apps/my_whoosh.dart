import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:swift_control/utils/keymap/apps/supported_app.dart';
import 'package:swift_control/utils/requirements/multi.dart';

import '../buttons.dart';
import '../keymap.dart';

class MyWhoosh extends SupportedApp {
  MyWhoosh()
    : super(
        name: 'MyWhoosh',
        packageName: "com.mywhoosh.whooshgame",
        compatibleTargets: Target.values,
        supportsZwiftEmulation: false,
        keymap: Keymap(
          keyPairs: [
            KeyPair(
              buttons: ControllerButton.values.filter((e) => e.action == InGameAction.shiftDown).toList(),
              physicalKey: PhysicalKeyboardKey.keyI,
              logicalKey: LogicalKeyboardKey.keyI,
              touchPosition: Offset(80, 94),
              inGameAction: InGameAction.shiftDown,
            ),
            KeyPair(
              buttons: ControllerButton.values.filter((e) => e.action == InGameAction.shiftUp).toList(),
              physicalKey: PhysicalKeyboardKey.keyK,
              logicalKey: LogicalKeyboardKey.keyK,
              touchPosition: Offset(97, 94),
              inGameAction: InGameAction.shiftUp,
            ),
            KeyPair(
              buttons: ControllerButton.values.filter((e) => e.action == InGameAction.navigateRight).toList(),
              physicalKey: PhysicalKeyboardKey.arrowRight,
              logicalKey: LogicalKeyboardKey.arrowRight,
              touchPosition: Offset(60, 80),
              isLongPress: true,
              inGameAction: InGameAction.navigateRight,
            ),
            KeyPair(
              buttons: ControllerButton.values.filter((e) => e.action == InGameAction.navigateLeft).toList(),
              physicalKey: PhysicalKeyboardKey.arrowLeft,
              logicalKey: LogicalKeyboardKey.arrowLeft,
              touchPosition: Offset(32, 80),
              isLongPress: true,
              inGameAction: InGameAction.navigateLeft,
            ),
            KeyPair(
              buttons: ControllerButton.values.filter((e) => e.action == InGameAction.toggleUi).toList(),
              physicalKey: PhysicalKeyboardKey.keyH,
              logicalKey: LogicalKeyboardKey.keyH,
              inGameAction: InGameAction.toggleUi,
            ),
          ],
        ),
      );
}
