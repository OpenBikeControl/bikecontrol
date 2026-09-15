import 'dart:io';

import 'package:bike_control/services/shift_feedback/shift_feedback_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Phone vibration via the platform haptics engine. Only phones/tablets have
/// one; on desktop every cue is a no-op so the service can stay
/// platform-agnostic.
class PlatformShiftHaptics implements ShiftHaptics {
  const PlatformShiftHaptics();

  static bool get isSupported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  @override
  Future<void> play(ShiftCue cue) async {
    if (!isSupported) return;
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
