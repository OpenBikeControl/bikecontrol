import 'dart:async';

import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/actions/desktop.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
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
  final String uniqueId;
  final List<ControllerButton> availableButtons;

  BaseDevice(
    this._name, {
    required this.uniqueId,
    required this.availableButtons,
    this.isBeta = false,
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

  Timer? _longPressTimer;
  Set<ControllerButton> _previouslyPressedButtons = <ControllerButton>{};

  String get name => _name ?? runtimeType.toString();

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

  Future<void> handleButtonsClickedWithoutLongPressSupport(List<ControllerButton> clickedButtons) async {
    await handleButtonsClicked(clickedButtons, longPress: true);
    if (clickedButtons.length == 1) {
      final keyPair = core.actionHandler.supportedApp?.keymap.getKeyPair(clickedButtons.single);
      if (keyPair != null && (keyPair.isLongPress || keyPair.inGameAction?.isLongPress == true)) {
        // simulate release after click
        _longPressTimer?.cancel();
        await Future.delayed(const Duration(milliseconds: 800));
        await handleButtonsClicked([], longPress: true);
      } else {
        await handleButtonsClicked([], longPress: true);
      }
    } else {
      await handleButtonsClicked([]);
    }
  }

  Future<void> handleButtonsClicked(List<ControllerButton>? buttonsClicked, {bool longPress = false}) async {
    try {
      await _handleButtonsClickedInternal(buttonsClicked, longPress: longPress);
    } catch (e, st) {
      actionStreamInternal.add(
        LogNotification('Error handling button clicks: $e\n$st'),
      );
    }
  }

  Future<void> _handleButtonsClickedInternal(List<ControllerButton>? buttonsClicked, {required bool longPress}) async {
    if (buttonsClicked == null) {
      // ignore, no changes
    } else if (buttonsClicked.isEmpty) {
      actionStreamInternal.add(LogNotification('Buttons released'));
      _longPressTimer?.cancel();

      // Handle release events for long press keys
      final buttonsReleased = _previouslyPressedButtons.toList();
      final isLongPress =
          longPress ||
          buttonsReleased.singleOrNull != null &&
              core.actionHandler.supportedApp?.keymap.getKeyPair(buttonsReleased.single)?.isLongPress == true;
      if (buttonsReleased.isNotEmpty && isLongPress) {
        await performRelease(buttonsReleased);
      }
      _previouslyPressedButtons.clear();
    } else {
      actionStreamInternal.add(ButtonNotification(buttonsClicked: buttonsClicked));

      // Handle release events for buttons that are no longer pressed
      final buttonsReleased = _previouslyPressedButtons.difference(buttonsClicked.toSet()).toList();
      final wasLongPress =
          longPress ||
          buttonsReleased.singleOrNull != null &&
              core.actionHandler.supportedApp?.keymap.getKeyPair(buttonsReleased.single)?.isLongPress == true;
      if (buttonsReleased.isNotEmpty && wasLongPress) {
        await performRelease(buttonsReleased);
      }

      final isLongPress =
          longPress ||
          buttonsClicked.singleOrNull != null &&
              core.actionHandler.supportedApp?.keymap.getKeyPair(buttonsClicked.single)?.isLongPress == true;

      if (!isLongPress &&
          !(buttonsClicked.singleOrNull == ZwiftButtons.onOffLeft ||
              buttonsClicked.singleOrNull == ZwiftButtons.onOffRight)) {
        // we don't want to trigger the long press timer for the on/off buttons, also not when it's a long press key
        _longPressTimer?.cancel();
        _longPressTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) async {
          performClick(buttonsClicked);
        });
      }
      // Update currently pressed buttons
      _previouslyPressedButtons = buttonsClicked.toSet();

      if (isLongPress) {
        return performDown(buttonsClicked);
      } else {
        return performClick(buttonsClicked);
      }
    }
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

  Future<void> performDown(List<ControllerButton> buttonsClicked) async {
    for (final action in buttonsClicked) {
      // Check IAP status before executing command
      if (!IAPManager.instance.canExecuteCommand) {
        //actionStreamInternal.add(AlertNotification(LogLevel.LOGLEVEL_ERROR, _getCommandLimitMessage()));
        continue;
      }

      // For repeated actions, don't trigger key down/up events (useful for long press)
      final result = await core.actionHandler.performAction(action, isKeyDown: true, isKeyUp: false);

      actionStreamInternal.add(ActionNotification(result));
    }
  }

  Future<void> performClick(List<ControllerButton> buttonsClicked) async {
    for (final action in buttonsClicked) {
      // Check IAP status before executing command
      if (!IAPManager.instance.canExecuteCommand) {
        _showCommandLimitAlert();
        continue;
      }

      final result = await core.actionHandler.performAction(action, isKeyDown: true, isKeyUp: true);
      actionStreamInternal.add(ActionNotification(result));
    }
  }

  Future<void> performRelease(List<ControllerButton> buttonsReleased) async {
    for (final action in buttonsReleased) {
      // Check IAP status before executing command
      if (!IAPManager.instance.canExecuteCommand) {
        _showCommandLimitAlert();
        continue;
      }

      final result = await core.actionHandler.performAction(action, isKeyDown: false, isKeyUp: true);
      actionStreamInternal.add(LogNotification(result.message));
    }
  }

  Future<void> disconnect() async {
    _longPressTimer?.cancel();
    // Release any held keys in long press mode
    if (core.actionHandler is DesktopActions) {
      await (core.actionHandler as DesktopActions).releaseAllHeldKeys(_previouslyPressedButtons.toList());
    }
    _previouslyPressedButtons.clear();
    isConnected = false;
  }

  Widget showInformation(BuildContext context);

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
