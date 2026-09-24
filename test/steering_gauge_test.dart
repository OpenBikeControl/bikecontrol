import 'package:bike_control/widgets/controller/steering_gauge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('steerSideFor', () {
    test('positive angle past threshold ⇒ left (matches _applyPWMSteering)', () {
      expect(steerSideFor(8, 5), SteerSide.left);
    });
    test('negative angle past threshold ⇒ right', () {
      expect(steerSideFor(-8, 5), SteerSide.right);
    });
    test('within threshold ⇒ none', () {
      expect(steerSideFor(4, 5), SteerSide.none);
      expect(steerSideFor(-5, 5), SteerSide.none); // boundary is inclusive-neutral
      expect(steerSideFor(5, 5), SteerSide.none); // positive boundary inclusive-neutral
    });
  });

  group('steeringReadout', () {
    test('a bar a hair right of centre reads 0°, not -0°', () {
      expect(steeringReadout(-0.0, 10), '0°  ·  ±10°');
      expect(steeringReadout(-0.4, 10), '0°  ·  ±10°');
    });
    test('whole degrees either way', () {
      expect(steeringReadout(24.6, 10), '25°  ·  ±10°');
      expect(steeringReadout(-24.6, 10), '-25°  ·  ±10°');
    });
  });
}
