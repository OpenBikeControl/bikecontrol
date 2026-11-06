import 'package:bike_control/services/obc_haptics/obc_haptic_pattern.dart';
import 'package:bike_control/services/obc_haptics/obc_haptics_service.dart';
import 'package:bike_control/services/shift_feedback/shift_haptics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// This phone's vibration motor. Android plays the pulses as one waveform on
/// the Vibrator service (works while BikeControl is in the background, see
/// [PlatformShiftHaptics]); iOS has no duration control, so each pulse is one
/// impact whose weight follows the intensity.
class PhoneHapticTarget implements HapticTarget {
  const PhoneHapticTarget();

  /// Null where there is no vibration motor (desktop, web).
  static PhoneHapticTarget? get forPlatform => PlatformShiftHaptics.isSupported ? const PhoneHapticTarget() : null;

  static const _channel = PlatformShiftHaptics.channel;

  @override
  Future<void> playPulses(List<HapticPulse> pulses) async {
    if (pulses.isEmpty) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _channel.invokeMethod<void>('waveform', {
        'timings': [
          0,
          for (final p in pulses) ...[p.on.inMilliseconds, p.off.inMilliseconds],
        ],
        'amplitudes': [
          0,
          for (final p in pulses) ...[(p.intensity * 255).round().clamp(1, 255), 0],
        ],
      });
      return;
    }
    for (final pulse in pulses) {
      if (pulse.intensity > 0.66) {
        await HapticFeedback.heavyImpact();
      } else if (pulse.intensity > 0.33) {
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.lightImpact();
      }
      await Future<void>.delayed(pulse.on + pulse.off);
    }
  }

  @override
  Future<void> stopHaptics() async {
    if (defaultTargetPlatform == TargetPlatform.android) await _channel.invokeMethod<void>('cancel');
  }
}
