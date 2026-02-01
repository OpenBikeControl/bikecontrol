import 'dart:async';

import 'package:accessibility/accessibility.dart';
import 'package:bike_control/bluetooth/devices/hid/hid_device.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';

import '../keymap/apps/supported_app.dart';
import '../single_line_exception.dart';

class AndroidActions extends BaseActions {
  WindowEvent? windowInfo;

  final accessibilityHandler = Accessibility();
  StreamSubscription<void>? _keymapUpdateSubscription;
  StreamSubscription<WindowEvent>? _accessibilitySubscription;
  StreamSubscription<AKeyEvent>? _hidKeyPressedSubscription;

  AndroidActions({super.supportedModes = const [SupportedMode.touch, SupportedMode.media]});

  @override
  void init(SupportedApp? supportedApp) {
    super.init(supportedApp);
    _accessibilitySubscription = streamEvents().listen((windowEvent) {
      if (supportedApp != null) {
        windowInfo = windowEvent;
      }
    });

    // Update handled keys list when keymap changes
    updateHandledKeys();

    // Listen to keymap changes and update handled keys
    _keymapUpdateSubscription?.cancel();
    _keymapUpdateSubscription = supportedApp?.keymap.updateStream.listen((_) {
      updateHandledKeys();
    });

    _hidKeyPressedSubscription = hidKeyPressed().listen((keyPressed) async {
      final hidDevice = HidDevice(keyPressed.source);
      final button = hidDevice.getOrAddButton(keyPressed.hidKey, () => ControllerButton(keyPressed.hidKey));

      var availableDevice = core.connection.controllerDevices.firstOrNullWhere(
        (e) => e.toString() == hidDevice.toString(),
      );
      if (availableDevice == null) {
        core.connection.addDevices([hidDevice]);
        availableDevice = hidDevice;
      }
      if (keyPressed.keyDown) {
        availableDevice.handleButtonsClicked([button]);
      } else if (keyPressed.keyUp) {
        availableDevice.handleButtonsClicked([]);
      }
    });
  }

  @override
  Future<ActionResult> performAction(ControllerButton button, {required bool isKeyDown, required bool isKeyUp}) async {
    final superResult = await super.performAction(button, isKeyDown: isKeyDown, isKeyUp: isKeyUp);
    if (superResult is! NotHandled) {
      // Increment command count after successful execution
      return superResult;
    }
    final keyPair = supportedApp!.keymap.getKeyPair(button)!;

    if (keyPair.isSpecialKey) {
      await accessibilityHandler.controlMedia(switch (keyPair.physicalKey) {
        PhysicalKeyboardKey.mediaTrackNext => MediaAction.next,
        PhysicalKeyboardKey.mediaPlayPause => MediaAction.playPause,
        PhysicalKeyboardKey.audioVolumeUp => MediaAction.volumeUp,
        PhysicalKeyboardKey.audioVolumeDown => MediaAction.volumeDown,
        _ => throw SingleLineException("No action for key: ${keyPair.physicalKey}"),
      });
      // Increment command count after successful execution
      await IAPManager.instance.incrementCommandCount();
      return Success("Key pressed: ${keyPair.toString()}");
    }

    if (keyPair.androidAction != null) {
      if (!core.settings.getLocalEnabled() || !core.logic.showLocalControl || !isKeyDown) {
        return Ignored('Global action ignored');
      }
      await accessibilityHandler.performGlobalAction(keyPair.androidAction!.globalAction);
      await IAPManager.instance.incrementCommandCount();
      return Success("Global action: ${keyPair.androidAction!.title}");
    }

    final point = await resolveTouchPosition(keyPair: keyPair, windowInfo: windowInfo);
    if (point != Offset.zero) {
      try {
        await accessibilityHandler.performTouch(point.dx, point.dy, isKeyDown: isKeyDown, isKeyUp: isKeyUp);
      } on PlatformException catch (e) {
        return Error("Accessibility Service not working. Follow instructions at https://dontkillmyapp.com/");
      }
      // Increment command count after successful execution
      await IAPManager.instance.incrementCommandCount();
      return Success(
        "Touch performed at: ${point.dx.toInt()}, ${point.dy.toInt()} -> ${isKeyDown && isKeyUp
            ? "click"
            : isKeyDown
            ? "down"
            : "up"}",
      );
    }
    return NotHandled('No action assigned for ${button.name}');
  }

  void ignoreHidDevices() {
    accessibilityHandler.ignoreHidDevices();
  }

  void updateHandledKeys() {
    if (supportedApp == null) {
      accessibilityHandler.setHandledKeys([]);
      return;
    }

    // Get all keys from the keymap that have a mapping defined
    final handledKeys = supportedApp!.keymap.keyPairs
        .filter((keyPair) => !keyPair.hasNoAction)
        .expand((keyPair) => keyPair.buttons)
        .filter((e) => e.action == null && e.icon == null)
        .map((button) => button.name)
        .toSet()
        .toList();

    accessibilityHandler.setHandledKeys(handledKeys);
  }

  @override
  void cleanup() {
    _accessibilitySubscription?.cancel();
    _keymapUpdateSubscription?.cancel();
    _hidKeyPressedSubscription?.cancel();
  }
}
