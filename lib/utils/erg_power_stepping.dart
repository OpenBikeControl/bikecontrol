import 'dart:math' as math;

import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

/// Manual ERG-target stepping shared by every +/- control: the physical
/// shifter buttons (proxy_device), the on-screen buttons (Ride's virtual
/// shifting card), and the overlay controls (desktop/android/ios overlay
/// controllers). One home for the step size and the manual range so the
/// controls can't drift apart again (physical buttons once stepped 10 W while
/// the screen stepped 5 W).
extension ErgPowerStepping on FitnessBikeDefinition {
  /// Watts added/removed per +/- press.
  static const int stepW = 5;

  /// Ceiling for MANUALLY set targets. The definition itself accepts up to
  /// 2000 W (FTMS setTargetPower from a game may exceed 500 W legitimately);
  /// this only caps what the +/- controls do.
  static const int maxManualW = 500;

  /// Steps the manual ERG target by ±[stepW] and returns the new target, or
  /// null when nothing was changed:
  ///
  /// - the current target is unknown (`ergTargetPower.value == null`, e.g.
  ///   hub-commanded ERG where the game owns the target and never reports it) —
  ///   stepping from a made-up baseline would slam the trainer;
  /// - the step would leave the manual range. A target ABOVE [maxManualW]
  ///   (set by the game) is never yanked down: up is a no-op there, down steps
  ///   relative like anywhere else.
  int? stepManualErgPower({required bool up}) {
    final current = ergTargetPower.value;
    if (current == null) return null;
    final int next;
    if (up) {
      if (current >= maxManualW) return null;
      next = math.min(current + stepW, maxManualW);
    } else {
      if (current <= 0) return null;
      next = math.max(current - stepW, 0);
    }
    setManualErgPower(next);
    return next;
  }
}
