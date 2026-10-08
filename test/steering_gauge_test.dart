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

  group('steeringAngleText', () {
    test('a bar a hair right of centre reads 0°, not -0°', () {
      expect(steeringAngleText(-0.0), '0°');
      expect(steeringAngleText(-0.4), '0°');
    });
    test('whole degrees, the direction told by the gauge, not a sign', () {
      expect(steeringAngleText(24.6), '25°');
      expect(steeringAngleText(-24.6), '25°');
    });
  });

  test('the dead zone reads both ways', () {
    expect(steeringDeadZoneText(5), '±5°');
  });
}
