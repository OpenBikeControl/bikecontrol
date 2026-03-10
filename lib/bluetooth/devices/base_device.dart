import 'dart:async';

import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/actions/desktop.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/keymap/manager.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:prop/prop.dart' show LogLevel;

import '../../utils/keymap/buttons.dart';
import '../messages/notification.dart';

abstract class BaseDevice {
  final String? _name;
  final bool isBeta;
  bool supportsLongPress;
  final String uniqueId;
  final List<ControllerButton> availableButtons;

  BaseDevice(
    this._name, {
    required this.uniqueId,
    required this.availableButtons,
    this.isBeta = false,
    this.supportsLongPress = true,
    String? buttonPrefix,
  }) {
    if (availableButtons.isEmpty && core.actionHandler.supportedApp is CustomApp) {
      final allButtons = core.actionHandler.supportedApp!.keymap.keyPairs
          .flatMap((e) => e.buttons)
          .filter(
            (e) =>
                e.sourceDeviceId == uniqueId ||
                (e.sourceDeviceId == null && buttonPrefix != null && e.name.startsWith(buttonPrefix)),
          )
          .toSet();
      availableButtons.addAll(allButtons);
    }
  }

  bool isConnected = false;

  static const Duration _longPressTriggerDelay = Duration(milliseconds: 550);
  static const Duration _doubleClickDelay = Duration(milliseconds: 320);

  Timer? _longPressTimer;
  Timer? _singleClickTimer;
  Set<ControllerButton> _previouslyPressedButtons = <ControllerButton>{};
  Set<ControllerButton> _activeLongPressButtons = <ControllerButton>{};
  ControllerButton? _pendingSingleClickButton;

  String get name => _name ?? runtimeType.toString();

  String get buttonExplanation => isConnected ? 'Connecting...' : 'Click a button on this device to configure them.';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BaseDevice && runtimeType == other.runtimeType && toString() == other.toString();

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;

  final StreamController<BaseNotification> actionStreamInternal = StreamController<BaseNotification>.broadcast();

  Stream<BaseNotification> get actionStream => actionStreamInternal.stream;

  Future<void> connect();

  Future<void> handleButtonsClicked(List<ControllerButton>? buttonsClicked, {bool longPress = false}) async {
    try {
      if (buttonsClicked == null) {
        return;
      }

      if (longPress) {
        await _handleExplicitLongPress(buttonsClicked);
        return;
      }

      if (buttonsClicked.isEmpty) {
        await _handleButtonsReleased();
        return;
      }

      actionStreamInternal.add(ButtonNotification(buttonsClicked: buttonsClicked, device: this));

      if (buttonsClicked.length != 1) {
        _cancelPendingClickTimers();
        if (_activeLongPressButtons.isNotEmpty) {
          await performRelease(_activeLongPressButtons.toList(), trigger: ButtonTrigger.longPress);
          _activeLongPressButtons.clear();
        }
        _previouslyPressedButtons = buttonsClicked.toSet();
        await performClick(buttonsClicked, trigger: ButtonTrigger.singleClick);
        return;
      }

      final button = buttonsClicked.single;
      final wasAlreadyPressed =
          _previouslyPressedButtons.length == 1 && _previouslyPressedButtons.singleOrNull == button;
      _previouslyPressedButtons = {button};
      if (wasAlreadyPressed) {
        return;
      }

      final hasSingleAction = _hasTriggerAction(button, ButtonTrigger.singleClick);
      final hasDoubleAction = _hasTriggerAction(button, ButtonTrigger.doubleClick);
      final hasLongPressAction = _hasTriggerAction(button, ButtonTrigger.longPress);
      final isLongPressOnly = hasLongPressAction && !hasSingleAction && !hasDoubleAction;
      if (supportsLongPress && isLongPressOnly && !_isLongPressSuppressed(button)) {
        _cancelPendingClickTimers();
        _longPressTimer?.cancel();
        _activeLongPressButtons = {button};
        await performDown([button], trigger: ButtonTrigger.longPress);
        return;
      }

      if (!hasLongPressAction && !hasDoubleAction && !hasSingleAction) {
        // make sure we see this as an error
        await performClick([button]);
        return;
      }

      _scheduleLongPress(button);
    } catch (e, st) {
      actionStreamInternal.add(
        LogNotification('Error handling button clicks: $e\n$st'),
      );
    }
  }

  Future<void> _handleButtonsReleased() async {
    actionStreamInternal.add(LogNotification('Buttons released'));

    _longPressTimer?.cancel();
    final releasedButtons = _previouslyPressedButtons.toList();
    _previouslyPressedButtons.clear();

    if (releasedButtons.isEmpty) {
      return;
    }

    if (_activeLongPressButtons.isNotEmpty && supportsLongPress) {
      await performRelease(_activeLongPressButtons.toList(), trigger: ButtonTrigger.longPress);
      _activeLongPressButtons.clear();
      return;
    }

    if (releasedButtons.length != 1) {
      return;
    }

    await _handleSingleButtonTap(releasedButtons.single);
  }

  Future<void> _handleExplicitLongPress(List<ControllerButton> buttonsClicked) async {
    if (buttonsClicked.isEmpty) {
      if (_activeLongPressButtons.isNotEmpty) {
        await performRelease(_activeLongPressButtons.toList(), trigger: ButtonTrigger.longPress);
        _activeLongPressButtons.clear();
      }
      _previouslyPressedButtons.clear();
      return;
    }

    actionStreamInternal.add(ButtonNotification(buttonsClicked: buttonsClicked, device: this));
    _cancelPendingClickTimers();
    _activeLongPressButtons = buttonsClicked.toSet();
    _previouslyPressedButtons = buttonsClicked.toSet();
    await performDown(buttonsClicked, trigger: ButtonTrigger.longPress);
  }

  void _scheduleLongPress(ControllerButton button) {
    _longPressTimer?.cancel();
    if (!supportsLongPress || !_hasTriggerAction(button, ButtonTrigger.longPress)) {
      return;
    }
    if (_isLongPressSuppressed(button)) {
      return;
    }

    _longPressTimer = Timer(_longPressTriggerDelay, () {
      final stillPressed = _previouslyPressedButtons.length == 1 && _previouslyPressedButtons.singleOrNull == button;
      if (!stillPressed) {
        return;
      }
      _activeLongPressButtons = {button};
      unawaited(performDown([button], trigger: ButtonTrigger.longPress));
    });
  }

  bool _isLongPressSuppressed(ControllerButton button) {
    return button == ZwiftButtons.onOffLeft || button == ZwiftButtons.onOffRight;
  }

  Future<void> _handleSingleButtonTap(ControllerButton button) async {
    final hasSingleAction = _hasTriggerAction(button, ButtonTrigger.singleClick);
    final hasDoubleAction = _hasTriggerAction(button, ButtonTrigger.doubleClick);
    final hasLongPressAction = _hasTriggerAction(button, ButtonTrigger.longPress);

    if (!supportsLongPress && hasLongPressAction) {
      _cancelPendingClickTimers();
      final isLongPressAlreadyHeld = _activeLongPressButtons.contains(button);
      if (isLongPressAlreadyHeld) {
        await performRelease([button], trigger: ButtonTrigger.longPress);
        _activeLongPressButtons.remove(button);
      } else {
        await performDown([button], trigger: ButtonTrigger.longPress);
        _activeLongPressButtons.add(button);
      }
      return;
    }

    if (hasDoubleAction) {
      final isSecondTap =
          _pendingSingleClickButton == button &&
          (_singleClickTimer?.isActive ?? false) &&
          _activeLongPressButtons.isEmpty;

      if (isSecondTap) {
        _singleClickTimer?.cancel();
        _singleClickTimer = null;
        _pendingSingleClickButton = null;
        await performClick([button], trigger: ButtonTrigger.doubleClick);
        return;
      }

      _singleClickTimer?.cancel();
      _singleClickTimer = Timer(_doubleClickDelay, () {
        final pendingButton = _pendingSingleClickButton;
        _pendingSingleClickButton = null;
        _singleClickTimer = null;
        if (pendingButton != null && hasSingleAction) {
          unawaited(performClick([pendingButton], trigger: ButtonTrigger.singleClick));
        }
      });
      _pendingSingleClickButton = button;
      return;
    }

    if (hasSingleAction) {
      await performClick([button], trigger: ButtonTrigger.singleClick);
    }
  }

  bool _hasTriggerAction(ControllerButton button, ButtonTrigger trigger) {
    final keyPair = core.actionHandler.supportedApp?.keymap.getKeyPair(button, trigger: trigger);
    if (keyPair == null && core.actionHandler.supportedApp == null) {
      return trigger == ButtonTrigger.singleClick;
    }
    return keyPair != null && !keyPair.hasNoAction;
  }

  void _cancelPendingClickTimers() {
    _singleClickTimer?.cancel();
    _singleClickTimer = null;
    _pendingSingleClickButton = null;
  }

  String _getCommandLimitMessage() {
    return AppLocalizations.current.dailyCommandLimitReachedNotification;
  }

  String _getCommandLimitTitle() {
    return AppLocalizations.current
        .dailyLimitReached(IAPManager.dailyCommandLimit, IAPManager.dailyCommandLimit)
        .replaceAll(
          '${IAPManager.dailyCommandLimit}/${IAPManager.dailyCommandLimit}',
          IAPManager.dailyCommandLimit.toString(),
        )
        .replaceAll(
          '${IAPManager.dailyCommandLimit} / ${IAPManager.dailyCommandLimit}',
          IAPManager.dailyCommandLimit.toString(),
        );
  }

  bool _canExecuteCommand() {
    try {
      return IAPManager.instance.canExecuteCommand;
    } catch (_) {
      return true;
    }
  }

  Future<void> performDown(
    List<ControllerButton> buttonsClicked, {
    ButtonTrigger trigger = ButtonTrigger.longPress,
  }) async {
    for (final action in buttonsClicked) {
      // Check IAP status before executing command
      if (!_canExecuteCommand()) {
        //actionStreamInternal.add(AlertNotification(LogLevel.LOGLEVEL_ERROR, _getCommandLimitMessage()));
        continue;
      }

      // For repeated actions, don't trigger key down/up events (useful for long press)
      final result = await core.actionHandler.performAction(
        action,
        isKeyDown: true,
        isKeyUp: false,
        trigger: trigger,
      );

      actionStreamInternal.add(
        ActionNotification(result, button: action.copyWith(sourceDeviceId: action.sourceDeviceId ?? uniqueId)),
      );
    }
  }

  Future<void> performClick(
    List<ControllerButton> buttonsClicked, {
    ButtonTrigger trigger = ButtonTrigger.singleClick,
  }) async {
    for (final action in buttonsClicked) {
      // Check IAP status before executing command
      if (!_canExecuteCommand()) {
        _showCommandLimitAlert();
        continue;
      }

      final result = await core.actionHandler.performAction(
        action,
        isKeyDown: true,
        isKeyUp: true,
        trigger: trigger,
      );
      actionStreamInternal.add(
        ActionNotification(result, button: action.copyWith(sourceDeviceId: action.sourceDeviceId ?? uniqueId)),
      );
    }
  }

  Future<void> performRelease(
    List<ControllerButton> buttonsReleased, {
    ButtonTrigger trigger = ButtonTrigger.longPress,
  }) async {
    for (final action in buttonsReleased) {
      // Check IAP status before executing command
      if (!_canExecuteCommand()) {
        _showCommandLimitAlert();
        continue;
      }

      final result = await core.actionHandler.performAction(
        action,
        isKeyDown: false,
        isKeyUp: true,
        trigger: trigger,
      );
      actionStreamInternal.add(LogNotification(result.message));
    }
  }

  Future<void> disconnect() async {
    _longPressTimer?.cancel();
    _singleClickTimer?.cancel();
    _singleClickTimer = null;
    _pendingSingleClickButton = null;
    // Release any held keys in long press mode
    if (core.actionHandler is DesktopActions) {
      await (core.actionHandler as DesktopActions).releaseAllHeldKeys(_activeLongPressButtons.toList());
    }
    _activeLongPressButtons.clear();
    _previouslyPressedButtons.clear();
    isConnected = false;
  }

  Widget showInformation(BuildContext context);

  Widget? buildPreferences(BuildContext context) => null;

  ControllerButton getOrAddButton(String key, ControllerButton Function() creator) {
    if (core.actionHandler.supportedApp == null) {
      return creator();
    }
    if (core.actionHandler.supportedApp is! CustomApp) {
      final currentProfile = core.actionHandler.supportedApp!.name;
      // should we display this to the user?
      KeymapManager().duplicateSync(currentProfile, '$currentProfile (Copy)');
    }
    var createdButton = creator();
    if (createdButton.sourceDeviceId == null) {
      createdButton = createdButton.copyWith(sourceDeviceId: uniqueId);
    }
    final button = core.actionHandler.supportedApp!.keymap.getOrAddButton(key, createdButton);

    if (availableButtons.none((e) => e.name == button.name)) {
      availableButtons.add(button);
      core.settings.setKeyMap(core.actionHandler.supportedApp!);
    }
    return button;
  }

  void _showCommandLimitAlert() {
    actionStreamInternal.add(
      AlertNotification(
        LogLevel.LOGLEVEL_ERROR,
        _getCommandLimitMessage(),
        buttonTitle: AppLocalizations.current.purchase,
        onTap: () {
          IAPManager.instance.purchaseFullVersion(navigatorKey.currentContext!);
        },
      ),
    );
    core.flutterLocalNotificationsPlugin.show(
      1337,
      _getCommandLimitTitle(),
      _getCommandLimitMessage(),
      NotificationDetails(
        android: AndroidNotificationDetails('Limit', 'Limit reached'),
        iOS: DarwinNotificationDetails(presentAlert: true),
      ),
    );
  }
}
