import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:swift_control/utils/keymap/apps/supported_app.dart';
import 'package:swift_control/utils/requirements/multi.dart';

import '../buttons.dart';
import '../keymap.dart';

class Biketerra extends SupportedApp {
  Biketerra()
    : super(
        name: 'Biketerra',
        packageName: "biketerra",
        compatibleTargets: Target.values,
        supportsZwiftEmulation: !(Platform.isIOS || Platform.isMacOS),
        supportsOpenBikeProtocol: kDebugMode,
        keymap: Keymap(
          keyPairs: [
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.shiftDown)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.keyS,
                    logicalKey: LogicalKeyboardKey.keyS,
                  ),
                ),
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.shiftUp)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.keyW,
                    logicalKey: LogicalKeyboardKey.keyW,
                  ),
                ),
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.navigateRight)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.arrowRight,
                    logicalKey: LogicalKeyboardKey.arrowRight,
                  ),
                ),
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.navigateLeft)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.arrowLeft,
                    logicalKey: LogicalKeyboardKey.arrowLeft,
                  ),
                ),

            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.toggleUi)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.keyU,
                    logicalKey: LogicalKeyboardKey.keyU,
                  ),
                ),
          ],
        ),
      );
}
