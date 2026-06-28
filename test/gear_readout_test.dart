import 'package:bike_control/utils/gear_readout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatGearReadout', () {
    test('shows rear gear / total when front shift is off', () {
      expect(
        formatGearReadout(currentGear: 14, maxGear: 25, frontShiftEnabled: false, largeRing: false),
        '14/25',
      );
    });

    test('largeRing is ignored when front shift is off', () {
      expect(
        formatGearReadout(currentGear: 14, maxGear: 25, frontShiftEnabled: false, largeRing: true),
        '14/25',
      );
    });

    test('small ring shows position 1 × rear gear when front shift is on', () {
      expect(
        formatGearReadout(currentGear: 14, maxGear: 25, frontShiftEnabled: true, largeRing: false),
        '1×14',
      );
    });

    test('large ring shows position 2 × rear gear when front shift is on', () {
      expect(
        formatGearReadout(currentGear: 14, maxGear: 25, frontShiftEnabled: true, largeRing: true),
        '2×14',
      );
    });

    test('drops the total when front shift is on (position notation only)', () {
      final out = formatGearReadout(currentGear: 7, maxGear: 30, frontShiftEnabled: true, largeRing: true);
      expect(out, '2×7');
      expect(out.contains('/'), isFalse);
    });
  });
}
