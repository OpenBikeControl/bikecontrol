import 'package:accessibility/accessibility.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';

import '../single_line_exception.dart';
import 'keymap.dart';

enum InGameAction {
  shiftUp,
  shiftDown,
  mediaPlayPause(defaultPhysicalKey: PhysicalKeyboardKey.mediaPlayPause),
  mediaNext(defaultPhysicalKey: PhysicalKeyboardKey.mediaTrackNext),
  mediaVolumeUp(defaultPhysicalKey: PhysicalKeyboardKey.audioVolumeUp),
  mediaVolumeDown(defaultPhysicalKey: PhysicalKeyboardKey.audioVolumeDown);

  final PhysicalKeyboardKey? defaultPhysicalKey;

  const InGameAction({this.defaultPhysicalKey});
}

enum ZwiftButton {
  // left controller
  navigationUp._(InGameAction.mediaVolumeUp),
  navigationDown._(InGameAction.mediaVolumeDown),
  navigationLeft._(InGameAction.mediaPlayPause),
  navigationRight._(InGameAction.mediaNext),
  onOffLeft._(null),
  sideButtonLeft._(InGameAction.shiftDown),
  paddleLeft._(InGameAction.shiftDown),

  // zwift ride only
  shiftUpLeft._(InGameAction.shiftDown),
  shiftDownLeft._(InGameAction.shiftDown),
  powerUpLeft._(InGameAction.shiftDown),

  // right controller
  a._(null),
  b._(null),
  z._(null),
  y._(null),
  onOffRight._(null),
  sideButtonRight._(InGameAction.shiftUp),
  paddleRight._(InGameAction.shiftUp),

  // zwift ride only
  shiftUpRight._(InGameAction.shiftUp),
  shiftDownRight._(InGameAction.shiftUp),
  powerUpRight._(InGameAction.shiftUp);

  final InGameAction? action;
  const ZwiftButton._(this.action);

  @override
  String toString() {
    return name;
  }
}

abstract class SupportedApp {
  final String packageName;
  final String name;
  final Keymap keymap;

  Offset resolveTouchPosition({required ZwiftButton action, required WindowEvent windowInfo});

  const SupportedApp({required this.name, required this.packageName, required this.keymap});

  static final List<SupportedApp> supportedApps = [MyWhoosh(), TrainingPeaks(), CustomApp()];

  @override
  String toString() {
    return runtimeType.toString();
  }
}

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
          ],
        ),
      );

  @override
  Offset resolveTouchPosition({required ZwiftButton action, required WindowEvent windowInfo}) {
    return switch (action.action) {
      InGameAction.shiftUp => Offset(windowInfo.windowWidth * 0.98, windowInfo.windowHeight * 0.94),
      InGameAction.shiftDown => Offset(windowInfo.windowWidth * 0.80, windowInfo.windowHeight * 0.94),
      _ => throw SingleLineException("Unsupported action for MyWhoosh: $action"),
    };
  }
}

class TrainingPeaks extends SupportedApp {
  TrainingPeaks()
    : super(name: 'IndieVelo / TrainingPeaks', packageName: "com.indieVelo.client", keymap: Keymap.custom);

  @override
  Offset resolveTouchPosition({required ZwiftButton action, required WindowEvent windowInfo}) {
    return switch (action.action) {
      InGameAction.shiftUp => Offset(windowInfo.windowWidth / 2 * 1.32, windowInfo.windowHeight * 0.74),
      InGameAction.shiftDown => Offset(windowInfo.windowWidth / 2 * 1.15, windowInfo.windowHeight * 0.74),
      _ => throw SingleLineException("Unsupported action for IndieVelo: $action"),
    };
  }
}

class CustomApp extends SupportedApp {
  CustomApp() : super(name: 'Custom', packageName: "custom", keymap: Keymap.custom);

  @override
  Offset resolveTouchPosition({required ZwiftButton action, required WindowEvent windowInfo}) {
    final keyPair = keymap.getKeyPair(action);
    if (keyPair == null || keyPair.touchPosition == Offset.zero) {
      throw SingleLineException("No key pair found for action: $action");
    }
    return keyPair.touchPosition;
  }

  List<String> encodeKeymap() {
    // encode to save in preferences
    return keymap.keyPairs.map((e) => e.encode()).toList();
  }

  void decodeKeymap(List<String> data) {
    // decode from preferences

    if (data.isEmpty) {
      return;
    }

    final keyPairs = data.map((e) => KeyPair.decode(e)).whereNotNull().toList();
    if (keyPairs.isEmpty) {
      return;
    }
    keymap.keyPairs = keyPairs;
  }

  void setKey(ZwiftButton zwiftButton, KeyDownEvent keyDownEvent) {
    // set the key for the zwift button
    final keyPair = keymap.getKeyPair(zwiftButton);
    if (keyPair != null) {
      keyPair.physicalKey = keyDownEvent.physicalKey;
      keyPair.logicalKey = keyDownEvent.logicalKey;
    } else {
      keymap.keyPairs.add(
        KeyPair(buttons: [zwiftButton], physicalKey: keyDownEvent.physicalKey, logicalKey: keyDownEvent.logicalKey),
      );
    }
  }
}
