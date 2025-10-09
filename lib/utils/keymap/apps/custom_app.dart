import 'package:accessibility/accessibility.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:swift_control/utils/keymap/apps/supported_app.dart';

import '../../single_line_exception.dart';
import '../buttons.dart';
import '../keymap.dart';

class CustomApp extends SupportedApp {
  final String profileName;
  
  CustomApp({this.profileName = 'Custom'}) 
      : super(name: profileName, packageName: "custom_$profileName", keymap: Keymap(keyPairs: []));

  @override
  Offset resolveTouchPosition({required ZwiftButton action, required WindowEvent? windowInfo}) {
    final keyPair = keymap.getKeyPair(action);
    if (keyPair == null || keyPair.touchPosition == Offset.zero) {
      throw SingleLineException("No key pair found for action: $action. You may want to adjust the keymap.");
    }
    return keyPair.touchPosition;
  }

  List<String> encodeKeymap({Size? screenSize}) {
    // encode to save in preferences
    return keymap.keyPairs.map((e) => e.encode(screenSize: screenSize)).toList();
  }

  void decodeKeymap(List<String> data, {Size? screenSize}) {
    // decode from preferences

    if (data.isEmpty) {
      return;
    }

    final keyPairs = data.map((e) => KeyPair.decode(e, screenSize: screenSize)).whereNotNull().toList();
    if (keyPairs.isEmpty) {
      return;
    }
    keymap.keyPairs = keyPairs;
  }

  void setKey(
    ZwiftButton zwiftButton, {
    required PhysicalKeyboardKey physicalKey,
    required LogicalKeyboardKey? logicalKey,
    bool isLongPress = false,
    Offset? touchPosition,
  }) {
    // set the key for the zwift button
    final keyPair = keymap.getKeyPair(zwiftButton);
    if (keyPair != null) {
      keyPair.physicalKey = physicalKey;
      keyPair.logicalKey = logicalKey;
      keyPair.isLongPress = isLongPress;
      keyPair.touchPosition = touchPosition ?? Offset.zero;
    } else {
      keymap.keyPairs.add(
        KeyPair(
          buttons: [zwiftButton],
          physicalKey: physicalKey,
          logicalKey: logicalKey,
          isLongPress: isLongPress,
          touchPosition: touchPosition ?? Offset.zero,
        ),
      );
    }
  }
}
