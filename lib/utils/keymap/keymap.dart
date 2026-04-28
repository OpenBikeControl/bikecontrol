import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:accessibility/accessibility.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/actions/android.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../bluetooth/devices/base_device.dart';
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
  recents('Recents', Icons.apps, GlobalAction.recents),
  assistant('Open Assistant', Icons.assistant_outlined, null);

  final String title;
  final IconData icon;
  final GlobalAction? globalAction;

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
          '''Button: ${k.buttons.joinToString(transform: (e) => e.name)}\nTrigger: ${k.trigger.title}\nKeyboard key: ${k.logicalKey?.keyLabel ?? 'Not assigned'}\nAction: ${k.buttons.firstOrNull?.action}${k.touchPosition != Offset.zero ? '\nTouch Position: ${k.touchPosition.toString()}' : ''}''',
    );
  }

  PhysicalKeyboardKey? getPhysicalKey(ControllerButton action) {
    // get the key pair by in game action
    return getKeyPair(action, trigger: ButtonTrigger.singleClick)?.physicalKey;
  }

  List<KeyPair> getKeyPairs(ControllerButton action) {
    return keyPairs.where((element) => element.buttons.contains(action)).toList();
  }

  KeyPair? getKeyPair(ControllerButton action, {ButtonTrigger? trigger}) {
    final pairs = getKeyPairs(action);
    if (trigger != null) {
      return pairs.firstOrNullWhere((element) => element.trigger == trigger);
    }
    return pairs.firstOrNullWhere((element) => element.trigger == ButtonTrigger.singleClick) ?? pairs.firstOrNull;
  }

  KeyPair? findSimilarKeyPair(ControllerButton button, {ButtonTrigger? trigger}) {
    final existing = getKeyPair(button, trigger: trigger);
    if (existing != null) {
      return existing;
    }
    final pairs = keyPairs.where((element) => element.buttons.any((b) => b.action == button.action)).toList();
    if (trigger != null) {
      return pairs.firstOrNullWhere((element) => element.trigger == trigger);
    }
    return pairs.firstOrNullWhere((element) => element.trigger == ButtonTrigger.singleClick) ?? pairs.firstOrNull;
  }

  KeyPair getOrCreateKeyPair(ControllerButton button, {required ButtonTrigger trigger}) {
    final existing = getKeyPair(button, trigger: trigger);
    if (existing != null) {
      if (existing.buttons.length > 1) {
        existing.buttons.remove(button);
        final keyPair = KeyPair(
          touchPosition: existing.touchPosition,
          buttons: [button],
          physicalKey: existing.physicalKey,
          logicalKey: existing.logicalKey,
          modifiers: List.of(existing.modifiers),
          trigger: existing.trigger,
          inGameAction: existing.inGameAction,
          inGameActionValue: existing.inGameActionValue,
          androidAction: existing.androidAction,
          androidIntentAction: existing.androidIntentAction,
          command: existing.command,
          screenshotPath: existing.screenshotPath,
        );
        addKeyPair(keyPair);
        return keyPair;
      }
      return existing;
    }

    final keyPair = KeyPair(
      touchPosition: Offset.zero,
      buttons: [button],
      physicalKey: null,
      logicalKey: null,
      trigger: trigger,
    );
    addKeyPair(keyPair);
    return keyPair;
  }

  bool hasAnyMappedAction(ControllerButton button) {
    return getKeyPairs(button).any((keyPair) => !keyPair.hasNoAction);
  }

  void reset() {
    for (final keyPair in keyPairs) {
      _resetKeyPair(keyPair);
    }
    _updateStream.add(null);
  }

  void resetForDevice(BaseDevice device) {
    final deviceButtonNames = device.availableButtons.map((b) => b.name).toSet();
    for (final keyPair in keyPairs) {
      if (keyPair.buttons.any((b) => deviceButtonNames.contains(b.name))) {
        _resetKeyPair(keyPair);
      }
    }
    _updateStream.add(null);
  }

  void _resetKeyPair(KeyPair keyPair) {
    keyPair.physicalKey = null;
    keyPair.logicalKey = null;
    keyPair.touchPosition = Offset.zero;
    keyPair.trigger = ButtonTrigger.singleClick;
    keyPair.inGameAction = null;
    keyPair.inGameActionValue = null;
    keyPair.androidAction = null;
    keyPair.androidIntentAction = null;
    keyPair.command = null;
    keyPair.screenshotPath = null;
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
          trigger: button.action?.isLongPress == true ? ButtonTrigger.longPress : ButtonTrigger.singleClick,
        ),
      );
      return button;
    } else {
      final found = allButtons.firstWhere((b) => b.name == name);
      return found.copyWith(icon: found.icon ?? button.icon);
    }
  }

  void addNewButtons(List<ControllerButton> availableButtons) {
    final newButtons = availableButtons.filter(
      (button) {
        final existing = getKeyPair(button, trigger: ButtonTrigger.singleClick);
        return existing == null;
      },
    ).toList();
    for (final button in newButtons) {
      final buttonFromBase = core.settings.getTrainerApp()?.keymap.findSimilarKeyPair(
        button,
        trigger: ButtonTrigger.singleClick,
      );
      addKeyPair(
        KeyPair(
          touchPosition: buttonFromBase?.touchPosition ?? Offset.zero,
          buttons: [button],
          inGameAction: button.action,
          physicalKey: buttonFromBase?.physicalKey,
          logicalKey: buttonFromBase?.logicalKey,
          trigger:
              buttonFromBase?.trigger ??
              (button.action?.isLongPress == true ? ButtonTrigger.longPress : ButtonTrigger.singleClick),
          inGameActionValue: buttonFromBase?.inGameActionValue,
          androidAction: buttonFromBase?.androidAction,
          androidIntentAction: buttonFromBase?.androidIntentAction,
          command: buttonFromBase?.command,
          screenshotPath: buttonFromBase?.screenshotPath,
        ),
      );
    }
  }

  void signalUpdate() {
    _updateStream.add(null);
  }
}

class KeyPair {
  static const String intentActionPrefix = 'app.bikecontrol.trigger.';

  final List<ControllerButton> buttons;
  PhysicalKeyboardKey? physicalKey;
  LogicalKeyboardKey? logicalKey;
  List<ModifierKey> modifiers;
  Offset touchPosition;
  ButtonTrigger trigger;
  InGameAction? inGameAction;
  int? inGameActionValue;
  AndroidSystemAction? androidAction;
  String? androidIntentAction;
  String? command;
  String? screenshotPath;

  KeyPair({
    required this.buttons,
    required this.physicalKey,
    required this.logicalKey,
    this.modifiers = const [],
    this.touchPosition = Offset.zero,
    this.trigger = ButtonTrigger.singleClick,
    bool isLongPress = false,
    this.inGameAction,
    this.inGameActionValue,
    this.androidAction,
    this.androidIntentAction,
    this.command,
    this.screenshotPath,
  }) {
    if (isLongPress) {
      this.trigger = ButtonTrigger.longPress;
    }
  }

  String? get fullAndroidIntentAction {
    final suffix = androidIntentAction?.trim();
    if (suffix == null || suffix.isEmpty) return null;
    return '$intentActionPrefix$suffix';
  }

  bool get isLongPress => trigger == ButtonTrigger.longPress;

  bool get doesNotNeedTrainerConnection => inGameAction?.isOutsideTrainerApp == true || androidIntentAction != null;

  set isLongPress(bool value) {
    if (value) {
      trigger = ButtonTrigger.longPress;
    } else if (trigger == ButtonTrigger.longPress) {
      trigger = ButtonTrigger.singleClick;
    }
  }

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
      _
          when inGameAction != null &&
              inGameAction!.icon != null &&
              (core.logic.emulatorEnabled ||
                  [
                    InGameAction.headwindHeartRateMode,
                    InGameAction.headwindSpeed,
                    ...trainerActions,
                  ].contains(inGameAction!)) =>
        inGameAction!.icon,

      _ when screenshotPath != null && screenshotPath!.trim().isNotEmpty => Icons.image_outlined,
      _ when command != null && command!.trim().isNotEmpty =>
        Platform.isMacOS || Platform.isIOS ? Icons.rocket_launch_outlined : Icons.terminal,
      _
          when androidAction != null &&
              core.logic.showLocalControl &&
              core.settings.getLocalEnabled() &&
              core.actionHandler is AndroidActions =>
        androidAction!.icon,
      _
          when androidIntentAction != null &&
              androidIntentAction!.trim().isNotEmpty &&
              defaultTargetPlatform == TargetPlatform.android =>
        Icons.broadcast_on_home_outlined,
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
      androidAction == null &&
      (androidIntentAction == null || androidIntentAction!.trim().isEmpty) &&
      (screenshotPath == null || screenshotPath!.trim().isEmpty) &&
      (command == null || command!.trim().isEmpty);

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
      (androidIntentAction != null &&
          androidIntentAction!.trim().isNotEmpty &&
          core.logic.showLocalControl &&
          defaultTargetPlatform == TargetPlatform.android) ||
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
          core.zwiftMdnsEmulator.supportedActions.contains(inGameAction)) ||
      (inGameAction != null &&
          [InGameAction.headwindHeartRateMode, InGameAction.headwindSpeed].contains(inGameAction) &&
          (core.connection.accessories.isNotEmpty || kDebugMode)) ||
      (screenshotPath != null && screenshotPath!.trim().isNotEmpty) ||
      (command != null && command!.trim().isNotEmpty);

  @override
  String toString() {
    final text = (inGameAction != null && (core.logic.emulatorEnabled || inGameAction!.isOutsideTrainerApp))
        ? [
            inGameAction!.title,
            if (inGameActionValue != null) '$inGameActionValue',
          ].joinToString(separator: ': ')
        : (androidAction != null && core.logic.showLocalControl && core.actionHandler is AndroidActions)
        ? androidAction!.title
        : (androidIntentAction != null &&
              androidIntentAction!.trim().isNotEmpty &&
              defaultTargetPlatform == TargetPlatform.android)
        ? fullAndroidIntentAction!
        : (screenshotPath != null && screenshotPath!.trim().isNotEmpty)
        ? screenshotPath!
        : (command != null && command!.trim().isNotEmpty)
        ? command!
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
    final baseKey = logicalKey?.keyLabel ?? text ?? AppLocalizations.current.notAssignedOrNoConnectionMethodActive;

    if (physicalKey == null || !core.actionHandler.supportedModes.contains(SupportedMode.keyboard)) {
      return AppLocalizations.current.notAssignedOrNoConnectionMethodActive;
    }
    if (modifiers.isEmpty || baseKey == AppLocalizations.current.notAssignedOrNoConnectionMethodActive) {
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

  /// Serialise a [ControllerButton] for storage. Emits a plain string when
  /// only the name is needed (legacy format), or a map carrying any of
  /// `deviceId` / `icon`. Icons are stored as `{codePoint, fontFamily,
  /// fontPackage}` so we can rebuild the [IconData] on decode.
  static dynamic _encodeButton(ControllerButton e) {
    if (e.sourceDeviceId == null && e.icon == null) {
      return e.name;
    }
    return {
      'name': e.name,
      if (e.sourceDeviceId != null) 'deviceId': e.sourceDeviceId,
      if (e.icon != null)
        'icon': {
          'codePoint': e.icon!.codePoint,
          if (e.icon!.fontFamily != null) 'fontFamily': e.icon!.fontFamily,
          if (e.icon!.fontPackage != null) 'fontPackage': e.icon!.fontPackage,
        },
    };
  }

  String encode() {
    // encode to save in preferences

    return jsonEncode({
      'actions': buttons.map(_encodeButton).toList(),
      if (logicalKey != null) 'logicalKey': logicalKey?.keyId.toString(),
      if (physicalKey != null) 'physicalKey': physicalKey?.usbHidUsage.toString() ?? '0',
      if (modifiers.isNotEmpty) 'modifiers': modifiers.map((e) => e.name).toList(),
      if (touchPosition != Offset.zero) 'touchPosition': {'x': touchPosition.dx, 'y': touchPosition.dy},
      'trigger': trigger.name,
      // Keep for backward compatibility with older app versions.
      'isLongPress': isLongPress,
      'inGameAction': inGameAction?.name,
      'inGameActionValue': inGameActionValue,
      'androidAction': androidAction?.name,
      'androidIntentAction': androidIntentAction,
      'command': command,
      'screenshotPath': screenshotPath,
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
      IconData? icon;

      if (raw is String) {
        name = raw;
      } else if (raw is Map) {
        name = raw['name']?.toString();
        deviceId = raw['deviceId']?.toString();
        final rawIcon = raw['icon'];
        if (rawIcon is Map && rawIcon['codePoint'] is num) {
          icon = IconData(
            (rawIcon['codePoint'] as num).toInt(),
            fontFamily: rawIcon['fontFamily']?.toString(),
            fontPackage: rawIcon['fontPackage']?.toString(),
          );
        }
      }

      if (name == null) {
        return null;
      }

      final baseButton = ControllerButton.values.firstOrNullWhere((element) => element.name == name);

      if (baseButton != null) {
        return baseButton.copyWith(sourceDeviceId: deviceId, icon: icon);
      }

      return ControllerButton(name, sourceDeviceId: deviceId, icon: icon);
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

    final rawCommand = decoded['command']?.toString().trim();
    final rawScreenshotPath = decoded['screenshotPath']?.toString().trim();
    final rawLegacyShortcutName = decoded['shortcutName']?.toString().trim();
    final rawAndroidIntentAction = decoded['androidIntentAction']?.toString().trim();

    final decodedTrigger = decoded.containsKey('trigger')
        ? ButtonTrigger.values.firstOrNullWhere((element) => element.name == decoded['trigger'])
        : null;

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
      trigger:
          decodedTrigger ?? ((decoded['isLongPress'] ?? false) ? ButtonTrigger.longPress : ButtonTrigger.singleClick),
      inGameAction: decoded.containsKey('inGameAction')
          ? InGameAction.values.firstOrNullWhere((element) => element.name == decoded['inGameAction'])
          : null,
      inGameActionValue: decoded['inGameActionValue'],
      androidAction: decoded.containsKey('androidAction')
          ? AndroidSystemAction.values.firstOrNullWhere((element) => element.name == decoded['androidAction'])
          : null,
      androidIntentAction: rawAndroidIntentAction != null && rawAndroidIntentAction.isNotEmpty
          ? rawAndroidIntentAction
          : null,
      command: rawCommand != null && rawCommand.isNotEmpty
          ? rawCommand
          : (rawLegacyShortcutName != null && rawLegacyShortcutName.isNotEmpty ? rawLegacyShortcutName : null),
      screenshotPath: rawScreenshotPath != null && rawScreenshotPath.isNotEmpty ? rawScreenshotPath : null,
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
          trigger == other.trigger &&
          inGameAction == other.inGameAction &&
          inGameActionValue == other.inGameActionValue &&
          androidAction == other.androidAction &&
          androidIntentAction == other.androidIntentAction &&
          command == other.command &&
          screenshotPath == other.screenshotPath;

  @override
  int get hashCode => Object.hash(
    physicalKey,
    logicalKey,
    modifiers,
    touchPosition,
    trigger,
    inGameAction,
    inGameActionValue,
    androidAction,
    androidIntentAction,
    command,
    screenshotPath,
  );

  bool get isProAction =>
      command != null && command!.trim().isNotEmpty ||
      screenshotPath != null && screenshotPath!.trim().isNotEmpty ||
      isSpecialKey ||
      (androidAction != null && core.logic.showLocalControl && core.actionHandler is AndroidActions) ||
      (androidIntentAction != null &&
          androidIntentAction!.trim().isNotEmpty &&
          core.logic.showLocalControl &&
          core.actionHandler is AndroidActions);
}

enum ButtonTrigger {
  singleClick,
  doubleClick,
  longPress;

  String get title {
    return switch (this) {
      ButtonTrigger.singleClick => 'Single Click',
      ButtonTrigger.doubleClick => 'Double Click',
      ButtonTrigger.longPress => 'Long Press',
    };
  }
}
