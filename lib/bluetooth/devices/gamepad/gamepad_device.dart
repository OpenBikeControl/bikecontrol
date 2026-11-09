import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/services/obc_haptics/obc_haptic_pattern.dart';
import 'package:bike_control/services/obc_haptics/obc_haptics_service.dart';
import 'package:bike_control/services/shift_feedback/shift_feedback_service.dart';
import 'package:bike_control/utils/actions/android.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/requirements/android.dart';
import 'package:bike_control/widgets/ui/warning.dart';
import 'package:dartx/dartx.dart';
import 'package:gamepads/gamepads.dart';
import 'package:gamepads_platform_interface/gamepads_platform_interface.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class GamepadDevice extends BaseDevice implements HapticTarget {
  final String id;

  GamepadDevice(super.name, {required this.id}) : super(availableButtons: [], uniqueId: id, icon: LucideIcons.gamepad2);

  List<ControllerButton> _lastButtonsClicked = [];

  bool _canRumble = false;

  /// Whether the pad has rumble motors, known shortly after [connect].
  bool get canRumble => _canRumble;

  @override
  Future<void> connect() async {
    isConnected = true;
    unawaited(_detectRumble());

    await _cancelEventSubscriptions();
    _normalizedSubscription = Gamepads.normalizedEvents.where((pad) => pad.gamepadId == id).listen((event) {
      _handleEvent(event.button?.name ?? event.axis!.name, isAxis: event.axis != null, value: event.value);
    });

    // Generic controllers (no gamepad mapping, e.g. DirectInput pads on Windows) send raw keys like
    // "button-3" or "axis-1" that normalization drops.
    _rawSubscription = Gamepads.events
        .where((event) => event.gamepadId == id && _rawKeyPattern.hasMatch(event.key))
        .listen((event) => _handleEvent(event.key, isAxis: event.type == KeyType.analog, value: event.value));
  }

  StreamSubscription<NormalizedGamepadEvent>? _normalizedSubscription;
  StreamSubscription<GamepadEvent>? _rawSubscription;

  /// Stops this pad's input: a disconnected or forgotten pad must not keep
  /// firing actions.
  @override
  Future<void> disconnect() async {
    await _cancelEventSubscriptions();
    await super.disconnect();
  }

  Future<void> _cancelEventSubscriptions() async {
    final normalized = _normalizedSubscription;
    final raw = _rawSubscription;
    _normalizedSubscription = null;
    _rawSubscription = null;
    await normalized?.cancel();
    await raw?.cancel();
  }

  static final _rawKeyPattern = RegExp(r'^(button-|axis-|switch\d+-)');

  Future<void> _detectRumble() async {
    try {
      _canRumble = await GamepadsPlatformInterface.instance.hasRumble(id);
    } catch (e) {
      Logger.warn('Gamepad rumble check failed: $e');
    }
    if (_canRumble) core.connection.signalChange(this);
  }

  /// A short buzz for a shift, like the phone's: firmer up than down, and two
  /// strong pulses when there is no next gear.
  Future<void> playShiftCue(ShiftCue cue) async {
    if (!_canRumble) return;
    final platform = GamepadsPlatformInterface.instance;
    switch (cue) {
      case ShiftCue.up:
        await platform.rumble(id, lowFrequency: 0.3, highFrequency: 0.6, duration: const Duration(milliseconds: 80));
      case ShiftCue.down:
        await platform.rumble(id, lowFrequency: 0.15, highFrequency: 0.4, duration: const Duration(milliseconds: 60));
      case ShiftCue.limit:
        const pulse = Duration(milliseconds: 90);
        await platform.rumble(id, lowFrequency: 0.7, highFrequency: 0.7, duration: pulse);
        await Future<void>.delayed(pulse + const Duration(milliseconds: 80));
        await platform.rumble(id, lowFrequency: 0.7, highFrequency: 0.7, duration: pulse);
    }
  }

  /// Haptics an OpenBikeControl app asked for.
  @override
  Future<void> playPulses(List<HapticPulse> pulses) async {
    if (!_canRumble) return;
    final platform = GamepadsPlatformInterface.instance;
    for (final pulse in pulses) {
      await platform.rumble(id, lowFrequency: pulse.intensity, highFrequency: pulse.intensity, duration: pulse.on);
      await Future<void>.delayed(pulse.on + pulse.off);
    }
  }

  @override
  Future<void> stopHaptics() async {
    if (_canRumble) await GamepadsPlatformInterface.instance.stopRumble(id);
  }

  /// Android key names of the gamepad buttons, by normalized button name.
  static const androidKeyCodes = {
    'a': 'KEYCODE_BUTTON_A',
    'b': 'KEYCODE_BUTTON_B',
    'x': 'KEYCODE_BUTTON_X',
    'y': 'KEYCODE_BUTTON_Y',
    'leftBumper': 'KEYCODE_BUTTON_L1',
    'rightBumper': 'KEYCODE_BUTTON_R1',
    'leftTrigger': 'KEYCODE_BUTTON_L2',
    'rightTrigger': 'KEYCODE_BUTTON_R2',
    'back': 'KEYCODE_BUTTON_SELECT',
    'start': 'KEYCODE_BUTTON_START',
    'home': 'KEYCODE_BUTTON_MODE',
    'leftStick': 'KEYCODE_BUTTON_THUMBL',
    'rightStick': 'KEYCODE_BUTTON_THUMBR',
    'dpadUp': 'KEYCODE_DPAD_UP',
    'dpadDown': 'KEYCODE_DPAD_DOWN',
    'dpadLeft': 'KEYCODE_DPAD_LEFT',
    'dpadRight': 'KEYCODE_DPAD_RIGHT',
  };

  static final _androidNormalizer = GamepadNormalizer.forPlatform(GamepadPlatform.android);

  /// Android: a button press the accessibility service caught. Gamepad input
  /// only reaches the activity while BikeControl is in front; behind the
  /// trainer app, the service is the only way in (buttons only, no sticks).
  ///
  /// Returns false for a key that is no gamepad button (volume, media, enter,
  /// letters...): a HID keyboard or remote Android also lists as a gamepad
  /// sends those, and they belong to the HID keyboard path.
  bool handleAccessibilityKey(String key, {required bool keyDown}) {
    final value = keyDown ? 1.0 : 0.0;
    final events = _androidNormalizer
        .normalize(GamepadEvent(gamepadId: id, timestamp: 0, type: KeyType.button, key: key, value: value))
        .where((event) => event.button != null)
        .toList();
    for (final event in events) {
      _handleEvent(event.button!.name, isAxis: false, value: event.value);
    }
    return events.isNotEmpty;
  }

  void _handleEvent(String name, {required bool isAxis, required double value}) {
    if (isAxis && value.abs().round() != 1 && value.abs().round() != 0) {
      // ignore axis events that are not fully pressed to avoid accidental triggers from analog drift or light touches
      return;
    }
    final buttonKey = isAxis ? '${name}_${value.round()}' : name;

    actionStreamInternal.add(
      LogNotification('Gamepad event: $name value $value'),
    );

    if (isAxis) {
      if (value.round().abs() != 0) {
        ControllerButton button = getOrAddButton(
          buttonKey,
          () => ControllerButton(buttonKey, sourceDeviceId: id),
        );
        final buttonsClicked = [button];
        if (_lastButtonsClicked.contentEquals(buttonsClicked) == false) {
          handleButtonsClicked(buttonsClicked);
        }
        _lastButtonsClicked = buttonsClicked;
      } else {
        _lastButtonsClicked = [];
        handleButtonsClicked([]);
      }
    } else {
      ControllerButton button = getOrAddButton(
        buttonKey,
        () => ControllerButton(buttonKey, sourceDeviceId: id),
      );
      final buttonsClicked = value.toInt() == 1 ? [button] : <ControllerButton>[];
      if (_lastButtonsClicked.contentEquals(buttonsClicked) == false) {
        Logger.info("Buttons clicked: ${buttonsClicked.map((b) => b.name).join(', ')}");
        handleButtonsClicked(buttonsClicked);
      }
      _lastButtonsClicked = buttonsClicked;
    }
  }

  /// Android only delivers gamepad input to the app in front; behind the
  /// trainer app, BikeControl only gets the buttons through its accessibility
  /// service. Without it the gamepad works only while BikeControl is open.
  bool get _needsAccessibility {
    final handler = core.actionHandler;
    return handler is AndroidActions && handler.accessibilityEnabled.value == false;
  }

  @override
  DeviceSetupNeed? get setupNeed => _needsAccessibility ? DeviceSetupNeed.setup : null;

  /// One accessibility service covers every gamepad.
  @override
  String get setupPromptKey => 'android-accessibility';

  @override
  Future<void> openSetup(BuildContext context) async {
    final handler = core.actionHandler;
    if (!_needsAccessibility || handler is! AndroidActions) return;
    await AccessibilityRequirement().call(context, () {});
    await handler.refreshAccessibilityEnabled();
  }

  @override
  List<Widget> showMetaInformation(BuildContext context, {required bool showFull}) {
    return [
      if (Platform.isAndroid && _needsAccessibility)
        Warning(
          children: [
            Text(context.i18n.androidAccessibilityHint).xSmall,
          ],
        ),
    ];
  }
}
