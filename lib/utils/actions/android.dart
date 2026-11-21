import 'dart:async';

import 'package:accessibility/accessibility.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:bike_control/bluetooth/devices/gamepad/gamepad_device.dart';
import 'package:bike_control/bluetooth/devices/hid/hid_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/keymap_explanation.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener, ValueNotifier, visibleForTesting;

import '../keymap/apps/supported_app.dart';
import '../single_line_exception.dart';

class AndroidActions extends BaseActions {
  WindowEvent? windowInfo;

  final accessibilityHandler = Accessibility();
  StreamSubscription<void>? _keymapUpdateSubscription;
  StreamSubscription<WindowEvent>? _accessibilitySubscription;
  StreamSubscription<AKeyEvent>? _hidKeyPressedSubscription;
  AppLifecycleListener? _lifecycleListener;

  /// Whether BikeControl's accessibility service is switched on, null until
  /// first checked. Rechecked whenever the app comes back to the front, since
  /// it is switched on in the system settings.
  final accessibilityEnabled = ValueNotifier<bool?>(null);

  Future<void> refreshAccessibilityEnabled() async {
    final bool enabled;
    try {
      enabled = await accessibilityHandler.hasPermission();
    } on PlatformException {
      return; // Unknown: no gamepad warning rather than a wrong one.
    }
    if (enabled == accessibilityEnabled.value) return;
    accessibilityEnabled.value = enabled;
    // Gamepads need it to work behind the trainer app (see GamepadDevice.setupNeed).
    core.connection.gamepadDevices.forEach(core.connection.signalChange);
  }

  AndroidActions({super.supportedModes = const [SupportedMode.touch, SupportedMode.media]});

  @override
  void init(SupportedApp? supportedApp) {
    super.init(supportedApp);
    unawaited(refreshAccessibilityEnabled());
    _lifecycleListener ??= AppLifecycleListener(onResume: () => unawaited(refreshAccessibilityEnabled()));
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

    _hidKeyPressedSubscription = hidKeyPressed().listen(handleHidKey);
  }

  /// A key the accessibility service caught from a HID device (keyboard,
  /// remote, or a gamepad behind the trainer app).
  @visibleForTesting
  void handleHidKey(AKeyEvent keyPressed) {
    final gamepad = core.connection.gamepadDevices.firstOrNullWhere((d) => d.name == keyPressed.source);
    if (gamepad != null && (keyPressed.keyDown || keyPressed.keyUp)) {
      if (gamepad.handleAccessibilityKey(keyPressed.hidKey, keyDown: keyPressed.keyDown)) return;
      // Not a gamepad button: a HID keyboard or remote that Android also lists
      // as a gamepad. Its keys are handled like any other HID keyboard's.
    }
    final hidDevice = HidDevice(keyPressed.source);
    final button = hidDevice.getOrAddButton(keyPressed.hidKey, () => ControllerButton(keyPressed.hidKey));

    // Not the gamepad of the same name: its buttons are the normalized gamepad
    // ones, these keys get a HID device of their own.
    var availableDevice = core.connection.controllerDevices.firstOrNullWhere(
      (e) => e is! GamepadDevice && e.toString() == hidDevice.toString(),
    );
    if (availableDevice == null) {
      core.connection.addDevices([hidDevice]);
      availableDevice = hidDevice;
    } else {
      availableDevice.supportsLongPress = false;
    }
    if (keyPressed.keyDown) {
      availableDevice.handleButtonsClicked([button]);
    } else if (keyPressed.keyUp) {
      availableDevice.handleButtonsClicked([]);
    }
  }

  @override
  Future<ActionResult> performMediaKey(PhysicalKeyboardKey key, {required ControllerButton button}) async {
    final action = switch (key) {
      PhysicalKeyboardKey.mediaTrackNext => MediaAction.next,
      PhysicalKeyboardKey.mediaPlayPause => MediaAction.playPause,
      PhysicalKeyboardKey.audioVolumeUp => MediaAction.volumeUp,
      PhysicalKeyboardKey.audioVolumeDown => MediaAction.volumeDown,
      _ => throw SingleLineException("No action for key: ${mediaKeyLabel(key)}"),
    };
    await accessibilityHandler.controlMedia(action);
    // Increment command count after successful execution
    await IAPManager.instance.incrementCommandCount();
    return Success("Key pressed: ${mediaKeyLabel(key)}", button: button);
  }

  @override
  Future<ActionResult> performAction(
    ControllerButton button, {
    required bool isKeyDown,
    required bool isKeyUp,
    ButtonTrigger trigger = ButtonTrigger.singleClick,
  }) async {
    final superResult = await super.performAction(button, isKeyDown: isKeyDown, isKeyUp: isKeyUp, trigger: trigger);
    if (superResult is! NotHandled) {
      // Increment command count after successful execution
      return superResult;
    }
    final app = supportedApp;
    if (app == null) {
      return Error(
        AppLocalizations.current.couldNotPerformButtonnamesplitbyuppercaseNoKeymapSet(button.name.splitByUpperCase()),
        type: ErrorType.noKeymapSet,
        button: button,
      );
    }
    final keyPair = app.keymap.getKeyPair(button, trigger: trigger);
    if (keyPair == null) {
      return Error(
        AppLocalizations.current.noActionAssignedForButton(button.name.splitByUpperCase()),
        type: ErrorType.noActionAssigned,
        button: button,
      );
    }

    if (keyPair.isSpecialKey) {
      return performMediaKey(keyPair.physicalKey!, button: keyPair.buttons.firstOrNull ?? button);
    }

    if (keyPair.androidAction == AndroidSystemAction.assistant) {
      try {
        await _launchAssistant();
      } on PlatformException {
        return Error(
          'No assistant app available on this device',
          button: keyPair.buttons.firstOrNull,
        );
      }
    }

    if (keyPair.androidAction != null && keyPair.androidAction != AndroidSystemAction.assistant) {
      if (!core.settings.getLocalEnabled() || !core.logic.showLocalControl || !isKeyDown) {
        return Ignored(
          'Global action ignored',
          button: keyPair.buttons.firstOrNull,
        );
      }
      await accessibilityHandler.performGlobalAction(keyPair.androidAction!.globalAction!);
      await IAPManager.instance.incrementCommandCount();
      return Success(
        "Global action: ${keyPair.androidAction!.title}",
        button: keyPair.buttons.firstOrNull,
      );
    }

    final intentAction = keyPair.fullAndroidIntentAction;
    if (intentAction != null) {
      if (!isKeyDown) {
        return Ignored(
          'Custom intent ignored',
          button: keyPair.buttons.firstOrNull,
        );
      }
      try {
        await AndroidIntent(action: intentAction).sendBroadcast();
      } on PlatformException catch (e) {
        return Error(
          'Could not broadcast intent "$intentAction": ${e.message}',
          button: keyPair.buttons.firstOrNull,
        );
      }
      await IAPManager.instance.incrementCommandCount();
      return Success(
        "Custom intent broadcast: $intentAction",
        button: keyPair.buttons.firstOrNull,
      );
    }

    final point = await resolveTouchPosition(keyPair: keyPair, windowInfo: windowInfo);
    if (point != Offset.zero) {
      try {
        await accessibilityHandler.performTouch(point.dx, point.dy, isKeyDown: isKeyDown, isKeyUp: isKeyUp);
      } on PlatformException catch (e) {
        return Error(
          "Accessibility Service not working. Follow instructions at https://dontkillmyapp.com/",
          button: keyPair.buttons.firstOrNull,
        );
      }
      // Increment command count after successful execution
      await IAPManager.instance.incrementCommandCount();
      return Success(
        "Touch performed at: ${point.dx.toInt()}, ${point.dy.toInt()} -> ${isKeyDown && isKeyUp
            ? "click"
            : isKeyDown
            ? "down"
            : "up"}",
        button: keyPair.buttons.firstOrNull,
      );
    }
    return Error(
      AppLocalizations.current.noActionAssignedForButton(button.name.splitByUpperCase()),
      type: ErrorType.noActionAssigned,
      button: keyPair.buttons.firstOrNull,
    );
  }

  void ignoreHidDevices() {
    accessibilityHandler.ignoreHidDevices();
  }

  Future<void> _launchAssistant() async {
    final intents = [
      AndroidIntent(action: 'android.intent.action.VOICE_COMMAND'),
      AndroidIntent(action: 'android.intent.action.VOICE_ASSIST'),
      AndroidIntent(action: 'android.intent.action.ASSIST'),
    ];
    PlatformException? lastException;

    for (final intent in intents) {
      try {
        await intent.launch();
        return;
      } on PlatformException catch (e) {
        lastException = e;
      }
    }

    throw PlatformException(
      code: 'assistant_unavailable',
      message: lastException?.message ?? AppLocalizations.current.couldNotLaunchAssistant,
    );
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
        // Gamepad buttons are named after the normalized button ("a"); the
        // service sees the Android key ("KEYCODE_BUTTON_A").
        .expand((button) => [button.name, ?GamepadDevice.androidKeyCodes[button.name]])
        .toSet()
        .toList();

    accessibilityHandler.setHandledKeys(handledKeys);
  }

  @override
  void cleanup() {
    _accessibilitySubscription?.cancel();
    _keymapUpdateSubscription?.cancel();
    _hidKeyPressedSubscription?.cancel();
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
  }
}
