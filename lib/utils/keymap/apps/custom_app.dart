import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../buttons.dart';
import '../keymap.dart';

class CustomApp extends SupportedApp {
  final String profileName;

  @override
  List<(AppConnectionMethod, ConnectionSupport)> get connections => [
    if (!kIsWeb) (AppConnectionMethod.zwiftMdns, ConnectionSupport.supported),
    if (!kIsWeb) (AppConnectionMethod.zwiftBle, ConnectionSupport.beta),
  ];

  CustomApp({this.profileName = 'Other'})
    : super(
        name: profileName,
        packageName: "custom_$profileName",
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
    ButtonTrigger trigger = ButtonTrigger.singleClick,
    bool isLongPress = false,
    Offset? touchPosition,
    InGameAction? inGameAction,
    int? inGameActionValue,
  }) {
    // set the key for the zwift button
    final resolvedTrigger = isLongPress ? ButtonTrigger.longPress : trigger;
    final keyPair = keymap.getKeyPair(zwiftButton, trigger: resolvedTrigger);
    if (keyPair != null) {
      keyPair.physicalKey = physicalKey;
      keyPair.logicalKey = logicalKey;
      keyPair.modifiers = modifiers;
      keyPair.trigger = resolvedTrigger;
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
          trigger: resolvedTrigger,
          touchPosition: touchPosition ?? Offset.zero,
          inGameAction: inGameAction,
          inGameActionValue: inGameActionValue,
        ),
      );
    }
  }
}
