import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ControllerButton.initials', () {
    test('multi-word camelCase → uppercase first letters', () {
      expect(const ControllerButton('sideButtonLeft').initials, 'SBL');
      expect(const ControllerButton('navigationUp').initials, 'NU');
      expect(const ControllerButton('shiftDownRight').initials, 'SDR');
    });

    test('single-word name → single uppercase letter', () {
      expect(const ControllerButton('a').initials, 'A');
      expect(const ControllerButton('paddleLeft').initials, 'PL');
    });
  });
}
