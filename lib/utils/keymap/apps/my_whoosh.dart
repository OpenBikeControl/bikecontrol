import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';

import '../buttons.dart';
import '../keymap.dart';

class MyWhoosh extends SupportedApp {
  @override
  List<(AppConnectionMethod, ConnectionSupport)> get connections => [
    (AppConnectionMethod.myWhooshLink, ConnectionSupport.supported),
    (AppConnectionMethod.obpMdns, ConnectionSupport.supported),
  ];

  @override
  String? get logoAsset => 'assets/mywhoosh.png';

  @override
  int get virtualGearAmount => 30;

  @override
  List<ControllerButton> get defaultObpSupportedButtons => const [
    0x01, // Shift Up
    0x02, // Shift Down
    0x03, // Gear Set
    0x10, // Up
    0x11, // Down
    0x12, // Left/Look Left
    0x13, // Right/Look Right
    0x14, // Select/Confirm
    0x15, // Back/Cancel
    0x16, // Menu
    0x17, // Home
    0x18, // Steer Left
    0x19, // Steer Right
    0x40, // Camera View (Change Camera Angle)
  ].map((id) => OpenBikeProtocolParser.BUTTON_NAMES[id]!).toList();

  MyWhoosh()
    : super(
        name: 'MyWhoosh',
        packageName: "MyWhoosh",
        officialIntegration: true,
        additionalKeyPairs: [
          KeyPair(
            buttons: [ControllerButton('Peace', action: InGameAction.emote)],
            inGameAction: InGameAction.emote,
            inGameActionValue: 1,
            physicalKey: PhysicalKeyboardKey.digit1,
            logicalKey: LogicalKeyboardKey.digit1,
          ),
          KeyPair(
            buttons: [ControllerButton('Wave', action: InGameAction.emote)],
            inGameAction: InGameAction.emote,
            inGameActionValue: 2,
            physicalKey: PhysicalKeyboardKey.digit2,
            logicalKey: LogicalKeyboardKey.digit2,
          ),
          KeyPair(
            buttons: [ControllerButton('First Bump', action: InGameAction.emote)],
            inGameAction: InGameAction.emote,
            inGameActionValue: 3,
            physicalKey: PhysicalKeyboardKey.digit3,
            logicalKey: LogicalKeyboardKey.digit3,
          ),
          KeyPair(
            buttons: [ControllerButton('Dab', action: InGameAction.emote)],
            inGameAction: InGameAction.emote,
            inGameActionValue: 4,
            physicalKey: PhysicalKeyboardKey.digit4,
            logicalKey: LogicalKeyboardKey.digit4,
          ),
          KeyPair(
            buttons: [ControllerButton('Elbow Flick', action: InGameAction.emote)],
            inGameAction: InGameAction.emote,
            inGameActionValue: 5,
            physicalKey: PhysicalKeyboardKey.digit5,
            logicalKey: LogicalKeyboardKey.digit5,
          ),
          KeyPair(
            buttons: [ControllerButton('Toast', action: InGameAction.emote)],
            inGameAction: InGameAction.emote,
            inGameActionValue: 6,
            physicalKey: PhysicalKeyboardKey.digit6,
            logicalKey: LogicalKeyboardKey.digit6,
          ),
          KeyPair(
            buttons: [ControllerButton('Thumbs up', action: InGameAction.emote)],
            inGameAction: InGameAction.emote,
            inGameActionValue: 7,
            physicalKey: PhysicalKeyboardKey.digit7,
            logicalKey: LogicalKeyboardKey.digit7,
          ),
        ],
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
