import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

/// How a grade felt in the gear the rider would pick for it.
enum CalibrationRating { tooHeavy, aboutRight, tooLight }

/// The virtual shifting calibrator's state machine: three grades, each rated
/// by feel, converging on a difficulty for this trainer.
///
/// A "too heavy" or "too light" adjusts the difficulty and keeps the rider on
/// the same grade to feel the change; "about right" moves on. Every direction
/// change halves the step (a plain bisection, so a rider who overshoots lands
/// in between rather than bouncing), and a grade the rider keeps adjusting
/// moves on after [maxAdjustmentsPerGrade] tries so the run always ends.
///
/// Pure: applying [difficultyPct] to the trainer and the grade to ride is the
/// page's job.
class VsCalibrationSession {
  VsCalibrationSession({
    required int startPct,
    this.minPct = FitnessBikeDefinition.minDifficultyPct,
    this.maxPct = FitnessBikeDefinition.maxDifficultyPct,
  }) : _difficultyPct = startPct.clamp(minPct, maxPct);

  /// Flat road, a gentle climb, a steady climb (0.01 % units). The flat comes
  /// first: it is where an over-heavy hard gear shows most.
  static const List<int> grades001Pct = [0, 300, 600];

  static const int initialStepPct = 20;
  static const int minStepPct = 5;
  static const int maxAdjustmentsPerGrade = 4;

  final int minPct;
  final int maxPct;

  int _difficultyPct;
  int _stepIndex = 0;
  int _stepPct = initialStepPct;
  int _adjustmentsHere = 0;

  /// Direction of the last adjustment: -1 lighter, 1 heavier, 0 none yet.
  int _lastDirection = 0;

  int get difficultyPct => _difficultyPct;
  int get stepIndex => _stepIndex;
  bool get isDone => _stepIndex >= grades001Pct.length;
  int get grade001Pct => grades001Pct[_stepIndex.clamp(0, grades001Pct.length - 1)];

  void rate(CalibrationRating rating) {
    if (isDone) return;
    if (rating == CalibrationRating.aboutRight) {
      _advance();
      return;
    }
    final direction = rating == CalibrationRating.tooHeavy ? -1 : 1;
    if (_lastDirection != 0 && direction != _lastDirection) {
      _stepPct = (_stepPct ~/ 2).clamp(minStepPct, initialStepPct);
    }
    _lastDirection = direction;
    final next = _snap(_difficultyPct + direction * _stepPct).clamp(minPct, maxPct);
    final moved = next != _difficultyPct;
    _difficultyPct = next;
    _adjustmentsHere++;
    // At a limit there is nothing more to give on this grade.
    if (!moved || _adjustmentsHere >= maxAdjustmentsPerGrade) {
      _advance();
    }
  }

  void _advance() {
    _stepIndex++;
    _adjustmentsHere = 0;
  }

  /// Rounds to the 5 % grid the manual stepper moves on.
  static int _snap(int pct) => (pct / minStepPct).round() * minStepPct;
}
