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
      expect(const ControllerButton('paddle').initials, 'P');
    });

    test('generic gamepad keys keep their number', () {
      expect(const ControllerButton('button-7').initials, 'B7');
      expect(const ControllerButton('button-12').initials, 'B12');
      expect(const ControllerButton('axis-1_1').initials, 'A1+');
      expect(const ControllerButton('axis-1_-1').initials, 'A1−');
    });
  });
}
