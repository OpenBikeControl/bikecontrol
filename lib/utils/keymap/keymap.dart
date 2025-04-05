import 'dart:convert';

import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

class Keymap {
  static Keymap custom = Keymap(keyPairs: []);

  List<KeyPair> keyPairs;

  Keymap({required this.keyPairs});

  @override
  String toString() {
    return keyPairs.toString();
  }

  PhysicalKeyboardKey? getPhysicalKey(ZwiftButton action) {
    // get the key pair by in game action
    return keyPairs.firstOrNullWhere((element) => element.buttons.contains(action))?.physicalKey ??
        action.action?.defaultPhysicalKey;
  }

  KeyPair? getKeyPair(ZwiftButton action) {
    // get the key pair by in game action
    return keyPairs.firstOrNullWhere((element) => element.buttons.contains(action));
  }
}

class KeyPair {
  final List<ZwiftButton> buttons;
  PhysicalKeyboardKey physicalKey;
  LogicalKeyboardKey logicalKey;

  KeyPair({required this.buttons, required this.physicalKey, required this.logicalKey});
  String encode() {
    // encode to save in preferences
    return jsonEncode({
      'actions': buttons.map((e) => e.name).toList(),
      'logicalKey': logicalKey.keyId.toString() ?? '',
      'physicalKey': physicalKey.usbHidUsage.toString() ?? '',
    });
  }

  static KeyPair? decode(String data) {
    // decode from preferences
    final decoded = jsonDecode(data);
    if (decoded['actions'] == null || decoded['logicalKey'] == null || decoded['physicalKey'] == null) {
      return null;
    }
    return KeyPair(
      buttons:
          decoded['actions']
              .map<ZwiftButton>((e) => ZwiftButton.values.firstWhere((element) => element.name == e))
              .toList(),
      logicalKey: LogicalKeyboardKey(int.parse(decoded['logicalKey'])),
      physicalKey: PhysicalKeyboardKey(int.parse(decoded['physicalKey'])),
    );
  }
}
