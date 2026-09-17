import 'package:bike_control/services/shift_feedback/shift_feedback_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Phone vibration for shift cues. Only phones/tablets have a haptics engine;
/// on desktop every cue is a no-op so the service can stay platform-agnostic.
///
/// Android deliberately does NOT use [HapticFeedback]: that is
/// `View.performHapticFeedback`, which obeys the system "touch feedback"
/// setting (off by default on many devices) and does nothing unless the app's
/// window is focused — mid-ride BikeControl is usually behind the trainer app
/// or an overlay. The Vibrator service (see `ShiftHapticsChannel.kt`) works
/// regardless, and the foreground service keeps the process eligible under
/// Android 12+'s background-vibration rule.
class PlatformShiftHaptics implements ShiftHaptics {
  const PlatformShiftHaptics();

  static const channel = MethodChannel('de.jonasbark.swiftcontrol/shift_haptics');

  static bool get isSupported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

  @override
  Future<void> play(ShiftCue cue) async {
    if (kIsWeb) return;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        await channel.invokeMethod<void>('vibrate', cue.name);
      case TargetPlatform.iOS:
        await _impact(cue);
      default:
        return;
    }
  }

  Future<void> _impact(ShiftCue cue) async {
    switch (cue) {
      case ShiftCue.up:
        await HapticFeedback.mediumImpact();
      case ShiftCue.down:
        await HapticFeedback.lightImpact();
      case ShiftCue.limit:
        // Two heavy taps read as "stop" without looking at the screen.
        await HapticFeedback.heavyImpact();
        await Future<void>.delayed(const Duration(milliseconds: 90));
        await HapticFeedback.heavyImpact();
    }
  }
}
