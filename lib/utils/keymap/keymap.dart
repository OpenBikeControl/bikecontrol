import 'dart:async';
import 'dart:convert';

import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

import '../actions/base_actions.dart';
import 'apps/custom_app.dart';

class Keymap {
  static Keymap custom = Keymap(keyPairs: []);

  List<KeyPair> keyPairs;

  Keymap({required this.keyPairs});

  final StreamController<void> _updateStream = StreamController<void>.broadcast();
  Stream<void> get updateStream => _updateStream.stream;

  @override
  String toString() {
    return keyPairs.joinToString(
      separator: ('\n---------\n'),
      transform: (k) =>
          '''Button: ${k.buttons.joinToString(transform: (e) => e.name)}\nKeyboard key: ${k.logicalKey?.keyLabel ?? 'Not assigned'}\nAction: ${k.buttons.firstOrNull?.action}${k.touchPosition != Offset.zero ? '\nTouch Position: ${k.touchPosition.toString()}' : ''}${k.isLongPress ? '\nLong Press: Enabled' : ''}''',
    );
  }

  PhysicalKeyboardKey? getPhysicalKey(ControllerButton action) {
    // get the key pair by in game action
    return keyPairs.firstOrNullWhere((element) => element.buttons.contains(action))?.physicalKey;
  }

  KeyPair? getKeyPair(ControllerButton action) {
    // get the key pair by in game action
    return keyPairs.firstOrNullWhere((element) => element.buttons.contains(action));
  }

  void reset() {
    keyPairs = [];
    _updateStream.add(null);
  }

  void addKeyPair(KeyPair keyPair) {
    keyPairs.add(keyPair);
    _updateStream.add(null);

    if (actionHandler.supportedApp is CustomApp) {
      settings.setKeyMap(actionHandler.supportedApp!);
    }
  }
}

class KeyPair {
  final List<ControllerButton> buttons;
  PhysicalKeyboardKey? physicalKey;
  LogicalKeyboardKey? logicalKey;
  Offset touchPosition;
  bool isLongPress;
  InGameAction? inGameAction;
  int? inGameActionValue;

  KeyPair({
    required this.buttons,
    required this.physicalKey,
    required this.logicalKey,
    this.touchPosition = Offset.zero,
    this.isLongPress = false,
    this.inGameAction,
    this.inGameActionValue,
  });

  bool get isSpecialKey =>
      physicalKey == PhysicalKeyboardKey.mediaPlayPause ||
      physicalKey == PhysicalKeyboardKey.mediaTrackNext ||
      physicalKey == PhysicalKeyboardKey.mediaTrackPrevious ||
      physicalKey == PhysicalKeyboardKey.mediaStop ||
      physicalKey == PhysicalKeyboardKey.audioVolumeUp ||
      physicalKey == PhysicalKeyboardKey.audioVolumeDown;

  IconData get icon {
    return switch (physicalKey) {
      PhysicalKeyboardKey.mediaPlayPause ||
      PhysicalKeyboardKey.mediaStop ||
      PhysicalKeyboardKey.mediaTrackPrevious ||
      PhysicalKeyboardKey.mediaTrackNext ||
      PhysicalKeyboardKey.audioVolumeUp ||
      PhysicalKeyboardKey.audioVolumeDown => Icons.music_note_outlined,
      _ when physicalKey != null && actionHandler.supportedModes.contains(SupportedMode.keyboard) => Icons.keyboard,
      _ when inGameAction != null && whooshLink.isConnected.value => Icons.link,
      _ => Icons.touch_app,
    };
  }

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
      if (logicalKey != null) 'logicalKey': logicalKey?.keyId.toString(),
      if (physicalKey != null) 'physicalKey': physicalKey?.usbHidUsage.toString() ?? '0',
      if (touchPosition != Offset.zero) 'touchPosition': {'x': touchPosition.dx, 'y': touchPosition.dy},
      'isLongPress': isLongPress,
      'inGameAction': inGameAction?.name,
      'inGameActionValue': inGameActionValue,
    });
  }

  static KeyPair? decode(String data) {
    // decode from preferences
    final decoded = jsonDecode(data);

    // Support both percentage-based (new) and pixel-based (old) formats for backward compatibility
    final Offset touchPosition = decoded.containsKey('touchPosition')
        ? Offset(
            (decoded['touchPosition']['x'] as num).toDouble(),
            (decoded['touchPosition']['y'] as num).toDouble(),
          )
        : Offset.zero;

    final buttons = decoded['actions']
        .map<ControllerButton>(
          (e) => ControllerButton.values.firstOrNullWhere((element) => element.name == e) ?? ControllerButton(e),
        )
        .cast<ControllerButton>()
        .toList();
    if (buttons.isEmpty) {
      return null;
    }
    return KeyPair(
      buttons: buttons,
      logicalKey: decoded.containsKey('logicalKey') && int.parse(decoded['logicalKey']) != 0
          ? LogicalKeyboardKey(int.parse(decoded['logicalKey']))
          : null,
      physicalKey: decoded.containsKey('physicalKey') && int.parse(decoded['physicalKey']) != 0
          ? PhysicalKeyboardKey(int.parse(decoded['physicalKey']))
          : null,
      touchPosition: touchPosition,
      isLongPress: decoded['isLongPress'] ?? false,
      inGameAction: decoded.containsKey('inGameAction')
          ? InGameAction.values.firstOrNullWhere((element) => element.name == decoded['inGameAction'])
          : null,
      inGameActionValue: decoded['inGameActionValue'],
    );
  }
}
