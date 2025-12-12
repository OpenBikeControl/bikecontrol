import 'dart:async';

import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:swift_control/bluetooth/devices/zwift/constants.dart';
import 'package:swift_control/utils/actions/desktop.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/iap/iap_manager.dart';
import 'package:swift_control/utils/keymap/apps/custom_app.dart';
import 'package:swift_control/utils/keymap/manager.dart';

import '../../utils/keymap/buttons.dart';
import '../messages/notification.dart';

abstract class BaseDevice {
  final String name;
  final bool isBeta;
  final List<ControllerButton> availableButtons;

  BaseDevice(this.name, {required this.availableButtons, this.isBeta = false}) {
    if (availableButtons.isEmpty && core.actionHandler.supportedApp is CustomApp) {
      // TODO we should verify where the buttons came from
      final allButtons = core.actionHandler.supportedApp!.keymap.keyPairs.flatMap((e) => e.buttons);
      availableButtons.addAll(allButtons);
    }
  }

  bool isConnected = false;

  Timer? _longPressTimer;
  Set<ControllerButton> _previouslyPressedButtons = <ControllerButton>{};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BaseDevice && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() {
    return name;
  }

  final StreamController<BaseNotification> actionStreamInternal = StreamController<BaseNotification>.broadcast();

  Stream<BaseNotification> get actionStream => actionStreamInternal.stream;

  Future<void> connect();

  Future<void> handleButtonsClicked(List<ControllerButton>? buttonsClicked) async {
    try {
      await _handleButtonsClickedInternal(buttonsClicked);
    } catch (e, st) {
      actionStreamInternal.add(
        LogNotification('Error handling button clicks: $e\n$st'),
      );
    }
  }

  Future<void> _handleButtonsClickedInternal(List<ControllerButton>? buttonsClicked) async {
    if (buttonsClicked == null) {
      // ignore, no changes
    } else if (buttonsClicked.isEmpty) {
      actionStreamInternal.add(LogNotification('Buttons released'));
      _longPressTimer?.cancel();

      // Handle release events for long press keys
      final buttonsReleased = _previouslyPressedButtons.toList();
      final isLongPress =
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
          buttonsReleased.singleOrNull != null &&
          core.actionHandler.supportedApp?.keymap.getKeyPair(buttonsReleased.single)?.isLongPress == true;
      if (buttonsReleased.isNotEmpty && wasLongPress) {
        await performRelease(buttonsReleased);
      }

      final isLongPress =
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

  Future<void> performDown(List<ControllerButton> buttonsClicked) async {
    for (final action in buttonsClicked) {
      // Check IAP status before executing command
      if (!IAPManager.instance.canExecuteCommand) {
        actionStreamInternal.add(
          LogNotification(
            'Command limit reached. ${IAPManager.instance.commandsRemainingToday} commands remaining today. Upgrade to unlock unlimited commands.',
          ),
        );
        continue;
      }
      
      // For repeated actions, don't trigger key down/up events (useful for long press)
      final result = await core.actionHandler.performAction(action, isKeyDown: true, isKeyUp: false);
      actionStreamInternal.add(LogNotification(result.message));
      
      // Increment command count after successful execution
      await IAPManager.instance.incrementCommandCount();
    }
  }

  Future<void> performClick(List<ControllerButton> buttonsClicked) async {
    for (final action in buttonsClicked) {
      // Check IAP status before executing command
      if (!IAPManager.instance.canExecuteCommand) {
        final remaining = IAPManager.instance.commandsRemainingToday;
        actionStreamInternal.add(
          LogNotification(
            remaining > 0 
              ? 'Command limit: $remaining commands remaining today. Upgrade to unlock unlimited commands.'
              : 'Daily command limit reached (0/15). Upgrade to unlock unlimited commands or try again tomorrow.',
          ),
        );
        continue;
      }
      
      final result = await core.actionHandler.performAction(action, isKeyDown: true, isKeyUp: true);
      actionStreamInternal.add(ActionNotification(result));
      
      // Increment command count after successful execution
      await IAPManager.instance.incrementCommandCount();
    }
  }

  Future<void> performRelease(List<ControllerButton> buttonsReleased) async {
    for (final action in buttonsReleased) {
      // Check IAP status before executing command
      if (!IAPManager.instance.canExecuteCommand) {
        actionStreamInternal.add(
          LogNotification(
            'Command limit reached. ${IAPManager.instance.commandsRemainingToday} commands remaining today. Upgrade to unlock unlimited commands.',
          ),
        );
        continue;
      }
      
      final result = await core.actionHandler.performAction(action, isKeyDown: false, isKeyUp: true);
      actionStreamInternal.add(ActionNotification(result));
      
      // Increment command count after successful execution
      await IAPManager.instance.incrementCommandCount();
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
    if (core.actionHandler.supportedApp is! CustomApp) {
      final currentProfile = core.actionHandler.supportedApp!.name;
      // should we display this to the user?
      KeymapManager().duplicateSync(currentProfile, '$currentProfile (Copy)');
    }
    final button = core.actionHandler.supportedApp!.keymap.getOrAddButton(key, creator);

    if (availableButtons.none((e) => e.name == button.name)) {
      availableButtons.add(button);
      core.settings.setKeyMap(core.actionHandler.supportedApp!);
    }
    return button;
  }
}
