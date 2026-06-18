import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ControllerButton.initials', () {
    test('multi-word camelCase → first letters, directions as arrows', () {
      expect(const ControllerButton('sideButtonLeft').initials, 'SB←');
      expect(const ControllerButton('navigationUp').initials, 'N↑');
      expect(const ControllerButton('shiftDownRight').initials, 'S↓→');
    });

    test('single-word name → single uppercase letter', () {
      expect(const ControllerButton('a').initials, 'A');
      expect(const ControllerButton('paddleLeft').initials, 'P←');
    });
  });
}
