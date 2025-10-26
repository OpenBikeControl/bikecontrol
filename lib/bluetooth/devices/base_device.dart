import 'dart:async';

import 'package:flutter/material.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/desktop.dart';

import '../../utils/keymap/buttons.dart';
import '../messages/notification.dart';

abstract class BaseDevice {
  final String name;
  final bool isBeta;
  final List<ControllerButton> availableButtons;

  BaseDevice(this.name, {required this.availableButtons, this.isBeta = false});

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
    return runtimeType.toString();
  }

  final StreamController<BaseNotification> actionStreamInternal = StreamController<BaseNotification>.broadcast();

  Stream<BaseNotification> get actionStream => actionStreamInternal.stream;

  Future<void> connect();

  Future<void> handleButtonsClicked(List<ControllerButton>? buttonsClicked) async {
    if (buttonsClicked == null) {
      // ignore, no changes
    } else if (buttonsClicked.isEmpty) {
      actionStreamInternal.add(LogNotification('Buttons released'));
      _longPressTimer?.cancel();

      // Handle release events for long press keys
      final buttonsReleased = _previouslyPressedButtons.toList();
      final isLongPress =
          buttonsReleased.singleOrNull != null &&
          actionHandler.supportedApp?.keymap.getKeyPair(buttonsReleased.single)?.isLongPress == true;
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
          actionHandler.supportedApp?.keymap.getKeyPair(buttonsReleased.single)?.isLongPress == true;
      if (buttonsReleased.isNotEmpty && wasLongPress) {
        await performRelease(buttonsReleased);
      }

      final isLongPress =
          buttonsClicked.singleOrNull != null &&
          actionHandler.supportedApp?.keymap.getKeyPair(buttonsClicked.single)?.isLongPress == true;

      if (!isLongPress &&
          !(buttonsClicked.singleOrNull == ControllerButton.onOffLeft ||
              buttonsClicked.singleOrNull == ControllerButton.onOffRight)) {
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
      // For repeated actions, don't trigger key down/up events (useful for long press)
      actionStreamInternal.add(
        LogNotification(await actionHandler.performAction(action, isKeyDown: true, isKeyUp: false)),
      );
    }
  }

  Future<void> performClick(List<ControllerButton> buttonsClicked) async {
    for (final action in buttonsClicked) {
      actionStreamInternal.add(
        LogNotification(await actionHandler.performAction(action, isKeyDown: true, isKeyUp: true)),
      );
    }
  }

  Future<void> performRelease(List<ControllerButton> buttonsReleased) async {
    for (final action in buttonsReleased) {
      actionStreamInternal.add(
        LogNotification(await actionHandler.performAction(action, isKeyDown: false, isKeyUp: true)),
      );
    }
  }

  Future<void> disconnect() async {
    _longPressTimer?.cancel();
    // Release any held keys in long press mode
    if (actionHandler is DesktopActions) {
      await (actionHandler as DesktopActions).releaseAllHeldKeys(_previouslyPressedButtons.toList());
    }
    _previouslyPressedButtons.clear();
    isConnected = false;
  }

  Widget showInformation(BuildContext context);
}
