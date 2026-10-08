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

  group('formatGearReadout without the total', () {
    test('is the bare gear when front shift is off', () {
      expect(
        formatGearReadout(currentGear: 12, maxGear: 24, frontShiftEnabled: false, largeRing: false, withTotal: false),
        '12',
      );
    });

    test('keeps the ring position when front shift is on', () {
      expect(
        formatGearReadout(currentGear: 12, maxGear: 24, frontShiftEnabled: true, largeRing: true, withTotal: false),
        '2×12',
      );
    });
  });

  group('formatGearRatio', () {
    test('two decimals, a trailing zero dropped', () {
      expect(formatGearRatio(2.4), '×2.4');
      expect(formatGearRatio(2.43), '×2.43');
      expect(formatGearRatio(3.0), '×3.0');
    });
  });
}
