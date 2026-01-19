import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';

import '../buttons.dart';
import '../keymap.dart';

class MyWhoosh extends SupportedApp {
  MyWhoosh()
    : super(
        name: 'MyWhoosh',
        packageName: "com.mywhoosh.whooshgame",
        compatibleTargets: Target.values,
        supportsZwiftEmulation: false,
        star: true,
        keymap: Keymap(
          keyPairs: [
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.shiftDown)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.keyI,
                    logicalKey: LogicalKeyboardKey.keyI,
                    touchPosition: Offset(80, 94),
                    inGameAction: InGameAction.shiftDown,
                  ),
                ),
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.shiftUp)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.keyK,
                    logicalKey: LogicalKeyboardKey.keyK,
                    touchPosition: Offset(97, 94),
                    inGameAction: InGameAction.shiftUp,
                  ),
                ),
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.steerRight)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.keyD,
                    logicalKey: LogicalKeyboardKey.keyD,
                    touchPosition: Offset(60, 80),
                    isLongPress: true,
                    inGameAction: InGameAction.steerRight,
                  ),
                ),
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.steerLeft)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.keyA,
                    logicalKey: LogicalKeyboardKey.keyA,
                    touchPosition: Offset(32, 80),
                    isLongPress: true,
                    inGameAction: InGameAction.steerLeft,
                  ),
                ),
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.navigateLeft)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.arrowLeft,
                    logicalKey: LogicalKeyboardKey.arrowLeft,
                    touchPosition: Offset(32, 80),
                    isLongPress: true,
                    inGameAction: InGameAction.steerLeft,
                  ),
                ),
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.navigateRight)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.arrowRight,
                    logicalKey: LogicalKeyboardKey.arrowRight,
                    touchPosition: Offset(32, 80),
                    isLongPress: true,
                    inGameAction: InGameAction.steerLeft,
                  ),
                ),
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.toggleUi)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.keyH,
                    logicalKey: LogicalKeyboardKey.keyH,
                    inGameAction: InGameAction.toggleUi,
                  ),
                ),
          ],
        ),
      );
}
