import 'package:accessibility/accessibility.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:swift_control/main.dart';
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

    // just my personal preference
    switch (action) {
      case ZwiftButton.y:
        accessibilityHandler.controlMedia(MediaAction.volumeUp);
        return Offset.zero;
      case ZwiftButton.b:
        accessibilityHandler.controlMedia(MediaAction.volumeUp);
      case ZwiftButton.a:
        accessibilityHandler.controlMedia(MediaAction.next);
        return Offset.zero;
      case ZwiftButton.z:
        accessibilityHandler.controlMedia(MediaAction.playPause);
        return Offset.zero;
      default:
        break;
    }

    return switch (action.action) {
      InGameAction.shiftUp => Offset(
        windowInfo.right - windowInfo.width * 0.02,
        windowInfo.bottom - windowInfo.height * 0.06,
      ),
      InGameAction.shiftDown => Offset(
        windowInfo.right - windowInfo.width * 0.20,
        windowInfo.bottom - windowInfo.height * 0.06,
      ),
      InGameAction.navigateRight => Offset(
        windowInfo.right - windowInfo.width * 0.02,
        windowInfo.bottom - windowInfo.height * 0.20,
      ),
      _ => throw SingleLineException("Unsupported action for MyWhoosh: $action"),
    };
  }
}

extension WindowSize on WindowEvent {
  int get width => right - left;
  int get height => bottom - top;
}
