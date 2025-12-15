import 'dart:async';
import 'dart:convert';

import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    for (final keyPair in keyPairs) {
      keyPair.physicalKey = null;
      keyPair.logicalKey = null;
      keyPair.touchPosition = Offset.zero;
      keyPair.isLongPress = false;
      keyPair.inGameAction = null;
      keyPair.inGameActionValue = null;
    }
    _updateStream.add(null);
  }

  void addKeyPair(KeyPair keyPair) {
    keyPairs.add(keyPair);
    _updateStream.add(null);

    if (core.actionHandler.supportedApp is CustomApp) {
      core.settings.setKeyMap(core.actionHandler.supportedApp!);
    }
  }

  ControllerButton getOrAddButton(String name, ControllerButton Function() button) {
    final allButtons = keyPairs.expand((kp) => kp.buttons).toSet().toList();
    if (allButtons.none((b) => b.name == name)) {
      final newButton = button();
      addKeyPair(
        KeyPair(
          touchPosition: Offset.zero,
          buttons: [newButton],
          physicalKey: null,
          logicalKey: null,
          isLongPress: false,
        ),
      );
      return newButton;
    } else {
      return allButtons.firstWhere((b) => b.name == name);
    }
  }
}

class KeyPair {
  final List<ControllerButton> buttons;
  PhysicalKeyboardKey? physicalKey;
  LogicalKeyboardKey? logicalKey;
  List<ModifierKey> modifiers;
  Offset touchPosition;
  bool isLongPress;
  InGameAction? inGameAction;
  int? inGameActionValue;

  KeyPair({
    required this.buttons,
    required this.physicalKey,
    required this.logicalKey,
    this.modifiers = const [],
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

  IconData? get icon {
    return switch (physicalKey) {
      _ when inGameAction != null && core.logic.emulatorEnabled => Icons.link,

      PhysicalKeyboardKey.mediaPlayPause ||
      PhysicalKeyboardKey.mediaStop ||
      PhysicalKeyboardKey.mediaTrackPrevious ||
      PhysicalKeyboardKey.mediaTrackNext ||
      PhysicalKeyboardKey.audioVolumeUp ||
      PhysicalKeyboardKey.audioVolumeDown => Icons.music_note_outlined,
      _ when physicalKey != null && core.actionHandler.supportedModes.contains(SupportedMode.keyboard) =>
        Icons.keyboard,
      _ when touchPosition != Offset.zero && core.logic.showLocalRemoteOptions => Icons.touch_app,
      _ => null,
    };
  }

  bool get hasNoAction =>
      logicalKey == null && physicalKey == null && touchPosition == Offset.zero && inGameAction == null;

  bool get hasActiveAction =>
      (physicalKey != null &&
          core.logic.showLocalControl &&
          core.settings.getLocalEnabled() &&
          core.actionHandler.supportedModes.contains(SupportedMode.keyboard)) ||
      (touchPosition != Offset.zero &&
          core.logic.showLocalRemoteOptions &&
          core.actionHandler.supportedModes.contains(SupportedMode.touch)) ||
      (inGameAction != null &&
          core.logic.obpConnectedApp != null &&
          core.logic.obpConnectedApp!.supportedActions.contains(inGameAction)) ||
      (inGameAction != null && core.logic.emulatorEnabled);

  @override
  String toString() {
    final baseKey =
        logicalKey?.keyLabel ??
        switch (physicalKey) {
          PhysicalKeyboardKey.mediaPlayPause => 'Play/Pause',
          PhysicalKeyboardKey.mediaTrackNext => 'Next Track',
          PhysicalKeyboardKey.mediaTrackPrevious => 'Previous Track',
          PhysicalKeyboardKey.mediaStop => 'Stop',
          PhysicalKeyboardKey.audioVolumeUp => 'Volume Up',
          PhysicalKeyboardKey.audioVolumeDown => 'Volume Down',
          _ => 'Not assigned',
        };

    if (modifiers.isEmpty || baseKey == 'Not assigned') {
      if (baseKey.trim().isEmpty) {
        return 'Space';
      }
      return baseKey;
    }

    // Format modifiers + key (e.g., "Ctrl+Alt+R")
    final modifierStrings = modifiers.map((m) {
      return switch (m) {
        ModifierKey.shiftModifier => 'Shift',
        ModifierKey.controlModifier => 'Ctrl',
        ModifierKey.altModifier => 'Alt',
        ModifierKey.metaModifier => 'Meta',
        ModifierKey.functionModifier => 'Fn',
        _ => m.name,
      };
    }).toList();

    return '${modifierStrings.join('+')}+$baseKey';
  }

  String encode() {
    // encode to save in preferences

    return jsonEncode({
      'actions': buttons.map((e) => e.name).toList(),
      if (logicalKey != null) 'logicalKey': logicalKey?.keyId.toString(),
      if (physicalKey != null) 'physicalKey': physicalKey?.usbHidUsage.toString() ?? '0',
      if (modifiers.isNotEmpty) 'modifiers': modifiers.map((e) => e.name).toList(),
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

    // Decode modifiers if present
    final List<ModifierKey> modifiers = decoded.containsKey('modifiers')
        ? (decoded['modifiers'] as List)
              .map<ModifierKey?>((e) => ModifierKey.values.firstOrNullWhere((element) => element.name == e))
              .whereType<ModifierKey>()
              .toList()
        : [];

    return KeyPair(
      buttons: buttons,
      logicalKey: decoded.containsKey('logicalKey') && int.parse(decoded['logicalKey']) != 0
          ? LogicalKeyboardKey(int.parse(decoded['logicalKey']))
          : null,
      physicalKey: decoded.containsKey('physicalKey') && int.parse(decoded['physicalKey']) != 0
          ? PhysicalKeyboardKey(int.parse(decoded['physicalKey']))
          : null,
      modifiers: modifiers,
      touchPosition: touchPosition,
      isLongPress: decoded['isLongPress'] ?? false,
      inGameAction: decoded.containsKey('inGameAction')
          ? InGameAction.values.firstOrNullWhere((element) => element.name == decoded['inGameAction'])
          : null,
      inGameActionValue: decoded['inGameActionValue'],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeyPair &&
          runtimeType == other.runtimeType &&
          physicalKey == other.physicalKey &&
          logicalKey == other.logicalKey &&
          modifiers == other.modifiers &&
          touchPosition == other.touchPosition &&
          isLongPress == other.isLongPress &&
          inGameAction == other.inGameAction &&
          inGameActionValue == other.inGameActionValue;

  @override
  int get hashCode => Object.hash(
    physicalKey,
    logicalKey,
    modifiers,
    touchPosition,
    isLongPress,
    inGameAction,
    inGameActionValue,
  );
}
