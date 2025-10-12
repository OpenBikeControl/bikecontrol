import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:swift_control/utils/keymap/apps/supported_app.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

import '../keymap.dart';

class TrainingPeaks extends SupportedApp {
  TrainingPeaks()
    : super(
        name: 'TrainingPeaks Virtual / IndieVelo',
        packageName: "com.indieVelo.client",
        keymap: Keymap(
          keyPairs: [
            // https://help.trainingpeaks.com/hc/en-us/articles/31340399556877-TrainingPeaks-Virtual-Controls-and-Keyboard-Shortcuts
            KeyPair(
              buttons: ZwiftButton.values.filter((e) => e.action == InGameAction.shiftDown).toList(),
              physicalKey: PhysicalKeyboardKey.numpadSubtract,
              logicalKey: LogicalKeyboardKey.numpadSubtract,
              touchPosition: Offset(50 * 1.32, 74),
            ),
            KeyPair(
              buttons: ZwiftButton.values.filter((e) => e.action == InGameAction.shiftUp).toList(),
              physicalKey: PhysicalKeyboardKey.numpadAdd,
              logicalKey: LogicalKeyboardKey.numpadAdd,
              touchPosition: Offset(50 * 1.15, 74),
            ),
            KeyPair(
              buttons: ZwiftButton.values.filter((e) => e.action == InGameAction.navigateRight).toList(),
              physicalKey: PhysicalKeyboardKey.arrowRight,
              logicalKey: LogicalKeyboardKey.arrowRight,
            ),
            KeyPair(
              buttons: ZwiftButton.values.filter((e) => e.action == InGameAction.navigateLeft).toList(),
              physicalKey: PhysicalKeyboardKey.arrowLeft,
              logicalKey: LogicalKeyboardKey.arrowLeft,
            ),
            KeyPair(
              buttons: ZwiftButton.values.filter((e) => e.action == InGameAction.toggleUi).toList(),
              physicalKey: PhysicalKeyboardKey.keyH,
              logicalKey: LogicalKeyboardKey.keyH,
            ),
            KeyPair(
              buttons: ZwiftButton.values.filter((e) => e.action == InGameAction.increaseResistance).toList(),
              physicalKey: PhysicalKeyboardKey.pageUp,
              logicalKey: LogicalKeyboardKey.pageUp,
            ),
            KeyPair(
              buttons: ZwiftButton.values.filter((e) => e.action == InGameAction.decreaseResistance).toList(),
              physicalKey: PhysicalKeyboardKey.pageDown,
              logicalKey: LogicalKeyboardKey.pageDown,
            ),
          ],
        ),
      );
}
