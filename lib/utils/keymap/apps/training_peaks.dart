import 'package:accessibility/accessibility.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:swift_control/utils/keymap/apps/supported_app.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/utils/single_line_exception.dart';

import '../keymap.dart';

class TrainingPeaks extends SupportedApp {
  TrainingPeaks()
    : super(
        name: 'IndieVelo / TrainingPeaks',
        packageName: "com.indieVelo.client",
        keymap: Keymap(
          keyPairs: [
            // https://help.trainingpeaks.com/hc/en-us/articles/31340399556877-TrainingPeaks-Virtual-Controls-and-Keyboard-Shortcuts
            KeyPair(
              buttons: ZwiftButton.values.filter((e) => e.action == InGameAction.shiftDown).toList(),
              physicalKey: PhysicalKeyboardKey.minus,
              logicalKey: LogicalKeyboardKey.minus,
            ),
            KeyPair(
              buttons: ZwiftButton.values.filter((e) => e.action == InGameAction.shiftUp).toList(),
              physicalKey: PhysicalKeyboardKey.equal,
              logicalKey: LogicalKeyboardKey.equal,
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

  @override
  Offset resolveTouchPosition({required ZwiftButton action, required WindowEvent? windowInfo}) {
    final superPosition = super.resolveTouchPosition(action: action, windowInfo: windowInfo);
    if (superPosition != Offset.zero) {
      return superPosition;
    }
    if (windowInfo == null) {
      throw SingleLineException("Window size not known - open $this first");
    }
    return switch (action.action) {
      InGameAction.shiftUp => Offset(windowInfo.windowWidth / 2 * 1.32, windowInfo.windowHeight * 0.74),
      InGameAction.shiftDown => Offset(windowInfo.windowWidth / 2 * 1.15, windowInfo.windowHeight * 0.74),
      _ => throw SingleLineException("Unsupported action for IndieVelo: $action"),
    };
  }
}
