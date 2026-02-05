import 'dart:async';
import 'dart:convert';

import 'package:accessibility/accessibility.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/actions/android.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../actions/base_actions.dart';
import 'apps/custom_app.dart';

enum AndroidSystemAction {
  back('Back', Icons.arrow_back_ios, GlobalAction.back),
  dpadCenter('Select', Icons.radio_button_checked_outlined, GlobalAction.dpadCenter),
  down('Arrow Down', Icons.arrow_downward, GlobalAction.down),
  right('Arrow Right', Icons.arrow_forward, GlobalAction.right),
  up('Arrow Up', Icons.arrow_upward, GlobalAction.up),
  left('Arrow Left', Icons.arrow_back, GlobalAction.left),
  home('Home', Icons.home_outlined, GlobalAction.home),
  recents('Recents', Icons.apps, GlobalAction.recents);

  final String title;
  final IconData icon;
  final GlobalAction globalAction;

  const AndroidSystemAction(this.title, this.icon, this.globalAction);
}

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
      keyPair.androidAction = null;
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

  ControllerButton getOrAddButton(String name, ControllerButton button) {
    final allButtons = keyPairs.expand((kp) => kp.buttons).toSet().toList();
    if (allButtons.none((b) => b.name == name)) {
      addKeyPair(
        KeyPair(
          touchPosition: Offset.zero,
          buttons: [button],
          physicalKey: null,
          logicalKey: null,
          inGameAction: button.action,
          isLongPress: button.action?.isLongPress ?? false,
        ),
      );
      return button;
    } else {
      return allButtons.firstWhere((b) => b.name == name);
    }
  }

  void addNewButtons(List<ControllerButton> availableButtons) {
    final newButtons = availableButtons.filter((button) => getKeyPair(button) == null);
    for (final button in newButtons) {
      final buttonFromBase = core.settings.getTrainerApp()?.keymap.getKeyPair(button);
      addKeyPair(
        KeyPair(
          touchPosition: buttonFromBase?.touchPosition ?? Offset.zero,
          buttons: [button],
          inGameAction: button.action,
          physicalKey: buttonFromBase?.physicalKey,
          logicalKey: buttonFromBase?.logicalKey,
          isLongPress: buttonFromBase?.isLongPress ?? false,
          inGameActionValue: buttonFromBase?.inGameActionValue,
          androidAction: buttonFromBase?.androidAction,
        ),
      );
    }
  }

  void signalUpdate() {
    _updateStream.add(null);
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
  AndroidSystemAction? androidAction;

  KeyPair({
    required this.buttons,
    required this.physicalKey,
    required this.logicalKey,
    this.modifiers = const [],
    this.touchPosition = Offset.zero,
    this.isLongPress = false,
    this.inGameAction,
    this.inGameActionValue,
    this.androidAction,
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
      _ when isSpecialKey && core.actionHandler.supportedModes.contains(SupportedMode.media) => switch (physicalKey) {
        PhysicalKeyboardKey.mediaPlayPause => Icons.play_arrow_outlined,
        PhysicalKeyboardKey.mediaStop => Icons.stop,
        PhysicalKeyboardKey.mediaTrackPrevious => Icons.skip_previous,
        PhysicalKeyboardKey.mediaTrackNext => Icons.skip_next,
        PhysicalKeyboardKey.audioVolumeUp => Icons.volume_up,
        PhysicalKeyboardKey.audioVolumeDown => Icons.volume_down,
        _ => Icons.keyboard,
      },
      //_ when inGameAction != null && core.logic.emulatorEnabled => Icons.link,
      _ when inGameAction != null && inGameAction!.icon != null && core.logic.emulatorEnabled => inGameAction!.icon,

      _
          when androidAction != null &&
              core.logic.showLocalControl &&
              core.settings.getLocalEnabled() &&
              core.actionHandler is AndroidActions =>
        androidAction!.icon,
      _ when physicalKey != null && core.actionHandler.supportedModes.contains(SupportedMode.keyboard) =>
        RadixIcons.keyboard,
      _
          when touchPosition != Offset.zero &&
              core.logic.showLocalRemoteOptions &&
              core.actionHandler is AndroidActions =>
        Icons.touch_app,
      _ when touchPosition != Offset.zero && core.logic.showLocalRemoteOptions => BootstrapIcons.mouse,
      _ => null,
    };
  }

  bool get hasNoAction =>
      logicalKey == null &&
      physicalKey == null &&
      touchPosition == Offset.zero &&
      inGameAction == null &&
      androidAction == null;

  bool get hasActiveAction =>
      screenshotMode ||
      (physicalKey != null && (core.logic.showLocalControl && core.settings.getLocalEnabled()) ||
          (core.logic.showRemote && core.settings.getRemoteKeyboardControlEnabled()) &&
              core.actionHandler.supportedModes.contains(SupportedMode.keyboard)) ||
      (isSpecialKey &&
          core.logic.showLocalControl &&
          core.settings.getLocalEnabled() &&
          core.actionHandler is AndroidActions) ||
      (androidAction != null &&
          core.logic.showLocalControl &&
          core.settings.getLocalEnabled() &&
          core.actionHandler is AndroidActions) ||
      (touchPosition != Offset.zero &&
          core.logic.showLocalRemoteOptions &&
          core.actionHandler.supportedModes.contains(SupportedMode.touch)) ||
      (inGameAction != null &&
          core.logic.obpConnectedApp != null &&
          core.logic.obpConnectedApp!.supportedActions.contains(inGameAction)) ||
      (inGameAction != null &&
          core.logic.showMyWhooshLink &&
          core.settings.getMyWhooshLinkEnabled() &&
          core.whooshLink.supportedActions.contains(inGameAction)) ||
      (inGameAction != null &&
          core.logic.showZwiftBleEmulator &&
          core.settings.getZwiftBleEmulatorEnabled() &&
          core.zwiftEmulator.supportedActions.contains(inGameAction)) ||
      (inGameAction != null &&
          core.logic.showZwiftMsdnEmulator &&
          core.settings.getZwiftMdnsEmulatorEnabled() &&
          core.zwiftMdnsEmulator.supportedActions.contains(inGameAction));

  @override
  String toString() {
    final text = (inGameAction != null && core.logic.emulatorEnabled)
        ? [
            inGameAction!.title,
            if (inGameActionValue != null) '$inGameActionValue',
          ].joinToString(separator: ': ')
        : (androidAction != null && core.logic.showLocalControl && core.actionHandler is AndroidActions)
        ? androidAction!.title
        : (isSpecialKey && core.actionHandler.supportedModes.contains(SupportedMode.media))
        ? switch (physicalKey) {
            PhysicalKeyboardKey.mediaPlayPause => AppLocalizations.current.playPause,
            PhysicalKeyboardKey.mediaStop => AppLocalizations.current.stop,
            PhysicalKeyboardKey.mediaTrackPrevious => AppLocalizations.current.previous,
            PhysicalKeyboardKey.mediaTrackNext => AppLocalizations.current.next,
            PhysicalKeyboardKey.audioVolumeUp => AppLocalizations.current.volumeUp,
            PhysicalKeyboardKey.audioVolumeDown => AppLocalizations.current.volumeDown,
            _ => 'Unknown',
          }
        : (physicalKey != null && core.actionHandler.supportedModes.contains(SupportedMode.keyboard))
        ? null
        : (touchPosition != Offset.zero && core.logic.showLocalRemoteOptions)
        ? 'X:${touchPosition.dx.toInt()}, Y:${touchPosition.dy.toInt()}${inGameAction != null ? ' (${inGameAction!.title})' : ''}'
        : '';
    if (text != null && text.isNotEmpty) {
      return text;
    }
    final baseKey = logicalKey?.keyLabel ?? text ?? 'Not assigned';

    if (physicalKey == null || !core.actionHandler.supportedModes.contains(SupportedMode.keyboard)) {
      return 'Not assigned';
    }
    if (modifiers.isEmpty || baseKey == 'Not assigned') {
      if (baseKey.trim().isEmpty) {
        return 'Space';
      }
      return baseKey + (inGameAction != null ? ' (${inGameAction!.title})' : '');
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
      'actions': buttons
          .map(
            (e) => e.sourceDeviceId == null
                ? e.name
                : {
                    'name': e.name,
                    'deviceId': e.sourceDeviceId,
                  },
          )
          .toList(),
      if (logicalKey != null) 'logicalKey': logicalKey?.keyId.toString(),
      if (physicalKey != null) 'physicalKey': physicalKey?.usbHidUsage.toString() ?? '0',
      if (modifiers.isNotEmpty) 'modifiers': modifiers.map((e) => e.name).toList(),
      if (touchPosition != Offset.zero) 'touchPosition': {'x': touchPosition.dx, 'y': touchPosition.dy},
      'isLongPress': isLongPress,
      'inGameAction': inGameAction?.name,
      'inGameActionValue': inGameActionValue,
      'androidAction': androidAction?.name,
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

    ControllerButton? decodeButton(dynamic raw) {
      String? name;
      String? deviceId;

      if (raw is String) {
        name = raw;
      } else if (raw is Map) {
        name = raw['name']?.toString();
        deviceId = raw['deviceId']?.toString();
      }

      if (name == null) {
        return null;
      }

      final baseButton = ControllerButton.values.firstOrNullWhere((element) => element.name == name);

      if (baseButton != null) {
        return baseButton.copyWith(sourceDeviceId: deviceId);
      }

      return ControllerButton(name, sourceDeviceId: deviceId);
    }

    final buttons = (decoded['actions'] as List)
        .map<ControllerButton?>(decodeButton)
        .whereType<ControllerButton>()
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
      androidAction: decoded.containsKey('androidAction')
          ? AndroidSystemAction.values.firstOrNullWhere((element) => element.name == decoded['androidAction'])
          : null,
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
          inGameActionValue == other.inGameActionValue &&
          androidAction == other.androidAction;

  @override
  int get hashCode => Object.hash(
    physicalKey,
    logicalKey,
    modifiers,
    touchPosition,
    isLongPress,
    inGameAction,
    inGameActionValue,
    androidAction,
  );
}
