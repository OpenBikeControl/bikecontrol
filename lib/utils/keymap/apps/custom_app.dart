import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:swift_control/utils/keymap/apps/supported_app.dart';
import 'package:swift_control/utils/requirements/multi.dart';

import '../buttons.dart';
import '../keymap.dart';

class CustomApp extends SupportedApp {
  final String profileName;

  CustomApp({this.profileName = 'Other'})
    : super(
        name: profileName,
        compatibleTargets: kIsWeb
            ? [Target.thisDevice]
            : [
                if (!Platform.isIOS) Target.thisDevice,
                Target.otherDevice,
              ],
        packageName: "custom_$profileName",
        supportsZwiftEmulation: !kIsWeb,
        keymap: Keymap(keyPairs: []),
      );

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
    ControllerButton zwiftButton, {
    required PhysicalKeyboardKey? physicalKey,
    required LogicalKeyboardKey? logicalKey,
    List<ModifierKey> modifiers = const [],
    bool isLongPress = false,
    Offset? touchPosition,
    InGameAction? inGameAction,
    int? inGameActionValue,
  }) {
    // set the key for the zwift button
    final keyPair = keymap.getKeyPair(zwiftButton);
    if (keyPair != null) {
      keyPair.physicalKey = physicalKey;
      keyPair.logicalKey = logicalKey;
      keyPair.modifiers = modifiers;
      keyPair.isLongPress = isLongPress;
      keyPair.touchPosition = touchPosition ?? Offset.zero;
      keyPair.inGameAction = inGameAction;
      keyPair.inGameActionValue = inGameActionValue;
    } else {
      keymap.addKeyPair(
        KeyPair(
          buttons: [zwiftButton],
          physicalKey: physicalKey,
          logicalKey: logicalKey,
          modifiers: modifiers,
          isLongPress: isLongPress,
          touchPosition: touchPosition ?? Offset.zero,
          inGameAction: inGameAction,
          inGameActionValue: inGameActionValue,
        ),
      );
    }
  }
}
