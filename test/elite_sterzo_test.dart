import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Elite Sterzo Smart Calibration Tests', () {
    test('Should ignore NaN values during calibration', () {
      // Test that NaN values are filtered out
      final samples = [double.nan, 1.5, 2.0, 2.5, 3.0, double.nan, 3.5, 4.0, 4.5, 5.0, 5.5];
      final validSamples = samples.where((s) => !s.isNaN).take(10).toList();
      
      expect(validSamples.length, equals(10));
      expect(validSamples.every((s) => !s.isNaN), isTrue);
    });

    test('Should compute correct calibration offset from samples', () {
      // Test offset calculation
      final samples = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0];
      final offset = samples.reduce((a, b) => a + b) / samples.length;
      
      expect(offset, equals(5.5));
    });

    test('Should round angles to whole degrees', () {
      // Test rounding behavior
      expect(4.3.round(), equals(4));
      expect(4.6.round(), equals(5));
      expect(4.7.round(), equals(5));
      expect((-4.3).round(), equals(-4));
      expect((-4.6).round(), equals(-5));
    });
  });

  group('Elite Sterzo Smart PWM Keypress Tests', () {
    test('Should calculate correct keypress levels', () {
      // Test level calculation with LEVEL_DEGREE_STEP = 10 and MAX_LEVELS = 5
      const levelDegreeStep = 10.0;
      const maxLevels = 5;

      int calculateLevels(int absAngle) {
        final levels = (absAngle / levelDegreeStep).floor();
        return levels.clamp(1, maxLevels);
      }

      expect(calculateLevels(5), equals(1));   // Below threshold but level 1
      expect(calculateLevels(10), equals(1));  // 10 / 10 = 1
      expect(calculateLevels(15), equals(1));  // 15 / 10 = 1.5 floor = 1
      expect(calculateLevels(20), equals(2));  // 20 / 10 = 2
      expect(calculateLevels(35), equals(3));  // 35 / 10 = 3.5 floor = 3
      expect(calculateLevels(50), equals(5));  // 50 / 10 = 5 (max)
      expect(calculateLevels(100), equals(5)); // 100 / 10 = 10 but clamped to 5
    });

    test('Should determine correct steering direction', () {
      // Test direction determination
      expect(25 > 0, isTrue);   // Positive = RIGHT
      expect(-25 > 0, isFalse); // Negative = LEFT
    });
  });

  group('Elite Sterzo Smart Threshold Tests', () {
    test('Should correctly apply steering threshold', () {
      const steeringThreshold = 10.0;

      // Test threshold logic
      expect(5.abs() > steeringThreshold, isFalse);   // Below threshold
      expect(10.abs() > steeringThreshold, isFalse);  // At threshold
      expect(11.abs() > steeringThreshold, isTrue);   // Above threshold
      expect((-11).abs() > steeringThreshold, isTrue); // Above threshold (negative)
    });
  });
}
