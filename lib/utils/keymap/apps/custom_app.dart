import 'package:accessibility/accessibility.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:swift_control/utils/keymap/apps/supported_app.dart';

import '../../single_line_exception.dart';
import '../buttons.dart';
import '../keymap.dart';

class CustomApp extends SupportedApp {
  CustomApp() : super(name: 'Custom', packageName: "custom", keymap: Keymap.custom);

  @override
  Offset resolveTouchPosition({required ZwiftButton action, required WindowEvent? windowInfo}) {
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

  void setKey(
    ZwiftButton zwiftButton, {
    required PhysicalKeyboardKey physicalKey,
    required LogicalKeyboardKey? logicalKey,
  }) {
    // set the key for the zwift button
    final keyPair = keymap.getKeyPair(zwiftButton);
    if (keyPair != null) {
      keyPair.physicalKey = physicalKey;
      keyPair.logicalKey = logicalKey;
    } else {
      keymap.keyPairs.add(KeyPair(buttons: [zwiftButton], physicalKey: physicalKey, logicalKey: logicalKey));
    }
  }
}
