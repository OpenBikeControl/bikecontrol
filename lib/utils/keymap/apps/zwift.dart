import 'package:flutter/services.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/requirements/multi.dart';

import '../keymap.dart';

class Zwift extends SupportedApp {
  Zwift()
    : super(
        name: 'Zwift',
        packageName: "com.zwift.zwiftgame",
        supportsZwiftEmulation: true,
        compatibleTargets: [
          Target.thisDevice,
          Target.otherDevice,
        ],
        keymap: Keymap(
          keyPairs: [
            KeyPair(
              buttons: [ZwiftButtons.navigationUp],
              physicalKey: PhysicalKeyboardKey.arrowUp,
              logicalKey: LogicalKeyboardKey.arrowUp,
              inGameAction: InGameAction.openActionBar,
            ),
            KeyPair(
              buttons: [ZwiftButtons.navigationDown],
              physicalKey: PhysicalKeyboardKey.arrowDown,
              logicalKey: LogicalKeyboardKey.arrowDown,
              inGameAction: InGameAction.uturn,
            ),
            KeyPair(
              buttons: [ZwiftButtons.navigationLeft],
              physicalKey: PhysicalKeyboardKey.arrowLeft,
              logicalKey: LogicalKeyboardKey.arrowLeft,
              inGameAction: InGameAction.steerLeft,
            ),
            KeyPair(
              buttons: [ZwiftButtons.navigationRight],
              physicalKey: PhysicalKeyboardKey.arrowRight,
              logicalKey: LogicalKeyboardKey.arrowRight,
              inGameAction: InGameAction.steerRight,
            ),
            KeyPair(
              buttons: [ZwiftButtons.shiftUpLeft],
              physicalKey: null,
              logicalKey: null,
              inGameAction: InGameAction.shiftDown,
            ),
            KeyPair(
              buttons: [ZwiftButtons.shiftUpRight],
              physicalKey: null,
              logicalKey: null,
              inGameAction: InGameAction.shiftUp,
            ),
            KeyPair(
              buttons: [ZwiftButtons.shiftDownLeft],
              physicalKey: null,
              logicalKey: null,
              inGameAction: InGameAction.shiftDown,
            ),
            KeyPair(
              buttons: [ZwiftButtons.shiftDownRight],
              physicalKey: null,
              logicalKey: null,
              inGameAction: InGameAction.shiftUp,
            ),
            KeyPair(
              buttons: [ZwiftButtons.paddleLeft],
              physicalKey: null,
              logicalKey: null,
              inGameAction: InGameAction.shiftDown,
            ),
            KeyPair(
              buttons: [ZwiftButtons.paddleRight],
              physicalKey: null,
              logicalKey: null,
              inGameAction: InGameAction.shiftUp,
            ),
            KeyPair(
              buttons: [ZwiftButtons.y],
              physicalKey: PhysicalKeyboardKey.space,
              logicalKey: LogicalKeyboardKey.space,
              inGameAction: InGameAction.usePowerUp,
            ),
            KeyPair(
              buttons: [ZwiftButtons.a],
              physicalKey: PhysicalKeyboardKey.enter,
              logicalKey: LogicalKeyboardKey.enter,
              inGameAction: InGameAction.select,
            ),
            KeyPair(
              buttons: [ZwiftButtons.b],
              physicalKey: PhysicalKeyboardKey.escape,
              logicalKey: LogicalKeyboardKey.escape,
              inGameAction: InGameAction.back,
            ),
            KeyPair(
              buttons: [ZwiftButtons.z],
              physicalKey: null,
              logicalKey: null,
              inGameAction: InGameAction.rideOnBomb,
            ),
          ],
        ),
      );
}
