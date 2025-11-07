import 'package:accessibility/accessibility.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:swift_control/bluetooth/devices/hid/hid_device.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_emulator.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/keymap/apps/custom_app.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/widgets/keymap_explanation.dart';

import '../keymap/apps/supported_app.dart';
import '../single_line_exception.dart';

class AndroidActions extends BaseActions {
  WindowEvent? windowInfo;

  final accessibilityHandler = Accessibility();

  AndroidActions({super.supportedModes = const [SupportedMode.touch, SupportedMode.media]});

  @override
  void init(SupportedApp? supportedApp) {
    super.init(supportedApp);
    streamEvents().listen((windowEvent) {
      if (supportedApp != null) {
        windowInfo = windowEvent;
      }
    });

    hidKeyPressed().listen((keyPressed) {
      if (supportedApp is CustomApp) {
        final button = supportedApp.keymap.getOrAddButton(keyPressed, () => ControllerButton(keyPressed));

        final hidDevice = HidDevice('HID Device');
        var availableDevice = connection.controllerDevices.firstOrNullWhere((e) => e.name == hidDevice.name);
        if (availableDevice == null) {
          connection.addDevices([hidDevice]);
          availableDevice = hidDevice;
        }
        availableDevice.handleButtonsClicked([button]);
        availableDevice.handleButtonsClicked([]);
      }
    });
  }

  @override
  Future<String> performAction(ControllerButton button, {bool isKeyDown = true, bool isKeyUp = false}) async {
    if (supportedApp == null) {
      return ("Could not perform ${button.name.splitByUpperCase()}: No keymap set");
    }

    final keyPair = supportedApp!.keymap.getKeyPair(button);

    if (keyPair == null) {
      return ("Could not perform ${button.name.splitByUpperCase()}: No action assigned");
    }

    if (keyPair.inGameAction != null && whooshLink.isConnected.value) {
      return whooshLink.sendAction(keyPair.inGameAction!, keyPair.inGameActionValue);
    } else if (keyPair.inGameAction != null && zwiftEmulator.isConnected.value) {
      return zwiftEmulator.sendAction(keyPair.inGameAction!, keyPair.inGameActionValue);
    } else if (keyPair.isSpecialKey) {
      await accessibilityHandler.controlMedia(switch (keyPair.physicalKey) {
        PhysicalKeyboardKey.mediaTrackNext => MediaAction.next,
        PhysicalKeyboardKey.mediaPlayPause => MediaAction.playPause,
        PhysicalKeyboardKey.audioVolumeUp => MediaAction.volumeUp,
        PhysicalKeyboardKey.audioVolumeDown => MediaAction.volumeDown,
        _ => throw SingleLineException("No action for key: ${keyPair.physicalKey}"),
      });
      return "Key pressed: ${keyPair.toString()}";
    }

    final point = await resolveTouchPosition(keyPair: keyPair, windowInfo: windowInfo);
    if (point != Offset.zero) {
      try {
        await accessibilityHandler.performTouch(point.dx, point.dy, isKeyDown: isKeyDown, isKeyUp: isKeyUp);
      } on PlatformException catch (e) {
        return "Accessibility Service not working. Follow instructions at https://dontkillmyapp.com/";
      }
      return "Touch performed at: ${point.dx.toInt()}, ${point.dy.toInt()} -> ${isKeyDown && isKeyUp
          ? "click"
          : isKeyDown
          ? "down"
          : "up"}";
    }
    return "No action assigned";
  }

  void ignoreHidDevices() {
    accessibilityHandler.ignoreHidDevices();
  }
}
