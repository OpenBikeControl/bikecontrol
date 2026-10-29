import 'dart:math' as math;

import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

/// Where entering ERG takes the target from.
enum ErgStartSource {
  /// The last ERG target of this session.
  lastTarget,

  /// The power the trainer reads right now, rounded to the ERG step.
  currentPower,
}

/// The ERG preferences of one definition, as seeded from its shifting config.
class _ErgPreferences {
  int stepW = ErgPowerStepping.defaultStepW;
  ErgStartSource startSource = ErgPowerStepping.defaultStartSource;
}

/// Manual ERG handling shared by every control: the physical shifter buttons
/// (proxy_device), the on-screen buttons (Ride's virtual shifting card), and
/// the overlay controls (desktop/android/ios overlay controllers). One home for
/// the step size, the manual range and the start power so the controls can't
/// drift apart again (physical buttons once stepped 10 W while the screen
/// stepped 5 W).
///
/// The step and the start source come from the trainer's shifting config and
/// are attached to the definition with [setErgPreferences]; a definition that
/// was never seeded uses the defaults.
extension ErgPowerStepping on FitnessBikeDefinition {
  /// Watts added/removed per +/- press unless configured otherwise.
  static const int defaultStepW = 5;

  /// The steps a rider can pick.
  static const List<int> stepChoicesW = [1, 5, 10, 25];

  static const ErgStartSource defaultStartSource = ErgStartSource.lastTarget;

  /// Where ERG starts when neither the last target nor the current power is
  /// known.
  static const int fallbackStartW = 150;

  /// Ceiling for MANUALLY set targets. The definition itself accepts up to
  /// 2000 W (FTMS setTargetPower from a game may exceed 500 W legitimately);
  /// this only caps what the +/- controls do.
  static const int maxManualW = 500;

  static final Expando<_ErgPreferences> _preferences = Expando<_ErgPreferences>('ergPreferences');

  _ErgPreferences get _prefs => _preferences[this] ??= _ErgPreferences();

  /// Attaches the rider's ERG preferences to this definition. A step that is
  /// not one of [stepChoicesW] is ignored.
  void setErgPreferences({int? stepW, ErgStartSource? startSource}) {
    if (stepW != null && stepChoicesW.contains(stepW)) _prefs.stepW = stepW;
    if (startSource != null) _prefs.startSource = startSource;
  }

  /// Watts added/removed per +/- press.
  int get ergStepW => _preferences[this]?.stepW ?? defaultStepW;

  ErgStartSource get ergStartSource => _preferences[this]?.startSource ?? defaultStartSource;

  /// The target entering ERG starts at: the chosen [ergStartSource], else the
  /// other source, else [fallbackStartW]. A current power of 0 or unknown
  /// counts as unavailable; it is rounded to [ergStepW] and capped at
  /// [maxManualW].
  int ergStartPower() {
    final last = lastErgTarget;
    final lastTarget = (last != null && last > 0) ? last : null;
    final power = powerW.value;
    int? currentPower;
    if (power != null && power > 0) {
      final step = ergStepW;
      final rounded = math.min((power / step).round() * step, maxManualW);
      if (rounded > 0) currentPower = rounded;
    }
    return switch (ergStartSource) {
          ErgStartSource.lastTarget => lastTarget ?? currentPower,
          ErgStartSource.currentPower => currentPower ?? lastTarget,
        } ??
        fallbackStartW;
  }

  /// Enters manual ERG at [ergStartPower] and returns that target.
  int enterManualErg() {
    final watts = ergStartPower();
    setManualErgPower(watts);
    return watts;
  }

  /// Steps the manual ERG target by ±[ergStepW] and returns the new target, or
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
    final step = ergStepW;
    final int next;
    if (up) {
      if (current >= maxManualW) return null;
      next = math.min(current + step, maxManualW);
    } else {
      if (current <= 0) return null;
      next = math.max(current - step, 0);
    }
    setManualErgPower(next);
    return next;
  }
}
