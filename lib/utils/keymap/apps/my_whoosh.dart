import 'package:accessibility/accessibility.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:swift_control/utils/keymap/apps/supported_app.dart';

import '../../single_line_exception.dart';
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
              buttons: ZwiftButton.values.filter((e) => e.action == InGameAction.shiftDown).toList(),
              physicalKey: PhysicalKeyboardKey.keyK,
              logicalKey: LogicalKeyboardKey.keyK,
            ),
            KeyPair(
              buttons: ZwiftButton.values.filter((e) => e.action == InGameAction.shiftUp).toList(),
              physicalKey: PhysicalKeyboardKey.keyI,
              logicalKey: LogicalKeyboardKey.keyI,
            ),
            KeyPair(
              buttons: ZwiftButton.values.filter((e) => e.action == InGameAction.navigateRight).toList(),
              physicalKey: PhysicalKeyboardKey.keyD,
              logicalKey: LogicalKeyboardKey.keyD,
            ),
            KeyPair(
              buttons: ZwiftButton.values.filter((e) => e.action == InGameAction.navigateLeft).toList(),
              physicalKey: PhysicalKeyboardKey.keyA,
              logicalKey: LogicalKeyboardKey.keyA,
            ),
            KeyPair(
              buttons: ZwiftButton.values.filter((e) => e.action == InGameAction.toggleUi).toList(),
              physicalKey: PhysicalKeyboardKey.keyH,
              logicalKey: LogicalKeyboardKey.keyH,
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
      InGameAction.shiftUp => Offset(windowInfo.windowWidth * 0.98, windowInfo.windowHeight * 0.94),
      InGameAction.shiftDown => Offset(windowInfo.windowWidth * 0.80, windowInfo.windowHeight * 0.94),
      _ => throw SingleLineException("Unsupported action for MyWhoosh: $action"),
    };
  }
}
