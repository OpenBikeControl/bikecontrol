import 'package:bike_control/bluetooth/devices/elite/elite_square.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';

import '../keymap.dart';

class TrainingPeaks extends SupportedApp {
  @override
  List<(AppConnectionMethod, ConnectionSupport)> get connections => [
    (AppConnectionMethod.obpBle, ConnectionSupport.supported),
    (AppConnectionMethod.obpDirCon, ConnectionSupport.experimental),
  ];

  TrainingPeaks()
    : super(
        name: 'TrainingPeaks Virtual',
        packageName: "TPVirtual",
        star: true,
        keymap: Keymap(
          keyPairs: [
            // Explicit controller-button mappings with updated touch coordinates
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.shiftUp)
                .map(
                  (b) => KeyPair(
                    buttons: [ZwiftButtons.shiftUpRight],
                    physicalKey: PhysicalKeyboardKey.numpadAdd,
                    logicalKey: LogicalKeyboardKey.numpadAdd,
                    inGameAction: InGameAction.shiftUp,
                    touchPosition: Offset(22.65384615384622, 7.0769230769229665),
                  ),
                ),
            KeyPair(
              buttons: [ZwiftButtons.shiftDownRight],
              physicalKey: PhysicalKeyboardKey.numpadAdd,
              logicalKey: LogicalKeyboardKey.numpadAdd,
              inGameAction: InGameAction.shiftUp,
              touchPosition: Offset(22.61769250748708, 8.13909075507417),
            ),
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.shiftDown)
                .map(
                  (b) => KeyPair(
                    buttons: [ZwiftButtons.shiftUpLeft],
                    physicalKey: PhysicalKeyboardKey.numpadSubtract,
                    logicalKey: LogicalKeyboardKey.numpadSubtract,
                    inGameAction: InGameAction.shiftDown,
                    touchPosition: Offset(18.14448747554958, 6.772862761010401),
                  ),
                ),
            KeyPair(
              buttons: [ZwiftButtons.shiftDownLeft],
              physicalKey: PhysicalKeyboardKey.numpadSubtract,
              logicalKey: LogicalKeyboardKey.numpadSubtract,
              inGameAction: InGameAction.shiftDown,
              touchPosition: Offset(18.128205128205135, 6.75213675213675),
            ),

            // Navigation buttons (keep arrow key mappings and add touch positions)
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.steerRight)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.arrowRight,
                    logicalKey: LogicalKeyboardKey.arrowRight,
                    inGameAction: InGameAction.steerRight,
                    touchPosition: Offset(56.75858807279006, 92.42753954973301),
                  ),
                ),

            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.steerLeft)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.arrowLeft,
                    logicalKey: LogicalKeyboardKey.arrowLeft,
                    inGameAction: InGameAction.steerLeft,
                    touchPosition: Offset(41.11538461538456, 92.64957264957286),
                  ),
                ),
            KeyPair(
              buttons: [ZwiftButtons.navigationUp],
              physicalKey: PhysicalKeyboardKey.arrowUp,
              logicalKey: LogicalKeyboardKey.arrowUp,
              touchPosition: Offset(42.28406293368177, 92.61854987939971),
            ),

            // Face buttons with touch positions and keyboard fallbacks where sensible
            KeyPair(
              buttons: [ZwiftButtons.z, EliteSquareButtons.z],
              physicalKey: null,
              logicalKey: null,
              touchPosition: Offset(33.993890038715456, 92.43667306401531),
            ),
            KeyPair(
              buttons: [ZwiftButtons.a, EliteSquareButtons.a],
              physicalKey: null,
              logicalKey: null,
              touchPosition: Offset(47.37191097597044, 92.86963594239016),
            ),
            KeyPair(
              buttons: [ZwiftButtons.b, EliteSquareButtons.b],
              physicalKey: null,
              logicalKey: null,
              touchPosition: Offset(41.12364102683652, 83.72743323236598),
            ),
            KeyPair(
              buttons: [ZwiftButtons.y, EliteSquareButtons.y],
              physicalKey: null,
              logicalKey: null,
              touchPosition: Offset(58.52936866684111, 84.31131200977018),
            ),

            // Keep other existing mappings (toggle UI, increase/decrease resistance)
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.toggleUi)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.keyH,
                    logicalKey: LogicalKeyboardKey.keyH,
                  ),
                ),
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.increaseResistance)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.pageUp,
                    logicalKey: LogicalKeyboardKey.pageUp,
                  ),
                ),
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.decreaseResistance)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.pageDown,
                    logicalKey: LogicalKeyboardKey.pageDown,
                  ),
                ),
          ],
        ),
      );
}
