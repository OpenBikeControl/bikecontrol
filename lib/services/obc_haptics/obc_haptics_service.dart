import 'dart:async';
import 'dart:typed_data';

import 'package:bike_control/services/obc_haptics/obc_haptic_pattern.dart';

/// Something that can vibrate: this phone, a Zwift Play / Ride, a gamepad.
abstract class HapticTarget {
  Future<void> playPulses(List<HapticPulse> pulses);

  Future<void> stopHaptics();
}

typedef ObcHapticsErrorHandler = void Function(String context, Object error, StackTrace stack);

/// Plays haptic feedback commands that an OpenBikeControl app sends to
/// BikeControl (over BLE or the network) on every device here that can
/// vibrate: this phone, and the connected controllers when controller
/// vibration is on.
class ObcHapticsService {
  ObcHapticsService({
    required HapticTarget? Function() phone,
    required Iterable<HapticTarget> Function() controllers,
    required bool Function() controllerVibrationEnabled,
    required ObcHapticsErrorHandler onError,
  }) : _phone = phone,
       _controllers = controllers,
       _controllerVibrationEnabled = controllerVibrationEnabled,
       _onError = onError;

  final HapticTarget? Function() _phone;
  final Iterable<HapticTarget> Function() _controllers;
  final bool Function() _controllerVibrationEnabled;
  final ObcHapticsErrorHandler _onError;

  Future<void> handle(Uint8List data) async {
    final command = ObcHapticCommand.parse(data);
    if (command == null) return;

    final targets = [
      ?_phone(),
      if (_controllerVibrationEnabled()) ..._controllers(),
    ];
    await Future.wait(targets.map((t) => _run(command, t)));
  }

  Future<void> _run(ObcHapticCommand command, HapticTarget target) async {
    try {
      if (command.isStop) {
        await target.stopHaptics();
      } else {
        await target.playPulses(command.pulses);
      }
    } catch (e, s) {
      _onError('ObcHaptics.play', e, s);
    }
  }
}
