import 'package:bike_control/services/vs_calibration/vs_calibration_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts on the flat at the current difficulty', () {
    final s = VsCalibrationSession(startPct: 100);
    expect(s.stepIndex, 0);
    expect(s.grade001Pct, 0);
    expect(s.difficultyPct, 100);
    expect(s.isDone, isFalse);
  });

  test('walks flat, gentle climb and steady climb', () {
    expect(VsCalibrationSession.grades001Pct, [0, 300, 600]);
  });

  test('"about right" moves on without touching the difficulty', () {
    final s = VsCalibrationSession(startPct: 100);
    s.rate(CalibrationRating.aboutRight);
    expect(s.stepIndex, 1);
    expect(s.grade001Pct, 300);
    expect(s.difficultyPct, 100);
  });

  test('"too heavy" lowers the difficulty and stays on the grade to feel it again', () {
    final s = VsCalibrationSession(startPct: 100);
    s.rate(CalibrationRating.tooHeavy);
    expect(s.difficultyPct, 100 - VsCalibrationSession.initialStepPct);
    expect(s.stepIndex, 0);
  });

  test('"too light" raises it', () {
    final s = VsCalibrationSession(startPct: 100);
    s.rate(CalibrationRating.tooLight);
    expect(s.difficultyPct, 100 + VsCalibrationSession.initialStepPct);
  });

  test('overshooting halves the step, down to the finest step', () {
    final s = VsCalibrationSession(startPct: 100);
    s.rate(CalibrationRating.tooHeavy); // 80
    s.rate(CalibrationRating.tooLight); // reversal: step 10 → 90
    expect(s.difficultyPct, 90);
    s.rate(CalibrationRating.tooHeavy); // reversal: step 5 → 85
    expect(s.difficultyPct, 85);
    s.rate(CalibrationRating.aboutRight);
    // The step stays fine on the next grade; it never goes below the minimum.
    s.rate(CalibrationRating.tooLight);
    expect(s.difficultyPct, 85 + VsCalibrationSession.minStepPct);
  });

  test('a grade the rider keeps adjusting moves on after a few tries', () {
    final s = VsCalibrationSession(startPct: 100);
    for (var i = 0; i < VsCalibrationSession.maxAdjustmentsPerGrade; i++) {
      expect(s.stepIndex, 0);
      s.rate(CalibrationRating.tooHeavy);
    }
    expect(s.stepIndex, 1);
  });

  test('never leaves the supported range, and moves on at the limit', () {
    final s = VsCalibrationSession(startPct: 30, minPct: 25, maxPct: 200);
    s.rate(CalibrationRating.tooHeavy);
    expect(s.difficultyPct, 25);
    s.rate(CalibrationRating.tooHeavy);
    expect(s.difficultyPct, 25);
    expect(s.stepIndex, 1, reason: 'nothing lighter left to offer on this grade');
  });

  test('is done after the last grade is rated about right', () {
    final s = VsCalibrationSession(startPct: 100);
    s.rate(CalibrationRating.aboutRight);
    s.rate(CalibrationRating.aboutRight);
    expect(s.isDone, isFalse);
    s.rate(CalibrationRating.aboutRight);
    expect(s.isDone, isTrue);
    // A late tap after the end changes nothing.
    s.rate(CalibrationRating.tooHeavy);
    expect(s.difficultyPct, 100);
  });

  test('values land on the 5 % grid the manual stepper uses', () {
    final s = VsCalibrationSession(startPct: 97);
    s.rate(CalibrationRating.tooHeavy);
    expect(s.difficultyPct % 5, 0);
  });
}
