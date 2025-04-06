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
    return keyPairs.joinToString(
      separator: ('\n---------\n'),
      transform:
          (k) =>
              '''Button: ${k.buttons.joinToString(transform: (e) => e.name)}\nKeyboard key: ${k.logicalKey?.keyLabel ?? 'Not assigned'}\nAction: ${k.buttons.firstOrNull?.action}${k.touchPosition != Offset.zero ? '\nTouch Position: ${k.touchPosition.toString()}' : ''}''',
    );
  }

  PhysicalKeyboardKey? getPhysicalKey(ZwiftButton action) {
    // get the key pair by in game action
    return keyPairs.firstOrNullWhere((element) => element.buttons.contains(action))?.physicalKey;
  }

  KeyPair? getKeyPair(ZwiftButton action) {
    // get the key pair by in game action
    return keyPairs.firstOrNullWhere((element) => element.buttons.contains(action));
  }

  void reset() {
    keyPairs = [];
  }
}

class KeyPair {
  final List<ZwiftButton> buttons;
  PhysicalKeyboardKey? physicalKey;
  LogicalKeyboardKey? logicalKey;
  Offset touchPosition;

  KeyPair({
    required this.buttons,
    required this.physicalKey,
    required this.logicalKey,
    this.touchPosition = Offset.zero,
  });

  @override
  String toString() {
    return logicalKey?.keyLabel ??
        switch (physicalKey) {
          PhysicalKeyboardKey.mediaPlayPause => 'Play/Pause',
          PhysicalKeyboardKey.mediaTrackNext => 'Next Track',
          PhysicalKeyboardKey.mediaTrackPrevious => 'Previous Track',
          PhysicalKeyboardKey.mediaStop => 'Stop',
          PhysicalKeyboardKey.audioVolumeUp => 'Volume Up',
          PhysicalKeyboardKey.audioVolumeDown => 'Volume Down',
          _ => 'Not assigned',
        };
  }

  String encode() {
    // encode to save in preferences
    return jsonEncode({
      'actions': buttons.map((e) => e.name).toList(),
      'logicalKey': logicalKey?.keyId.toString() ?? '0',
      'physicalKey': physicalKey?.usbHidUsage.toString() ?? '0',
      'touchPosition': {'x': touchPosition.dx, 'y': touchPosition.dy},
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
      logicalKey: int.parse(decoded['logicalKey']) != 0 ? LogicalKeyboardKey(int.parse(decoded['logicalKey'])) : null,
      physicalKey:
          int.parse(decoded['physicalKey']) != 0 ? PhysicalKeyboardKey(int.parse(decoded['physicalKey'])) : null,
      touchPosition: Offset(decoded['touchPosition']['x'], decoded['touchPosition']['y']),
    );
  }
}
