import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

void main() {
  group('OverlayField', () {
    test('parses from name with fallback', () {
      expect(OverlayField.fromName('power'), OverlayField.power);
      expect(OverlayField.fromName('bogus'), isNull);
    });
  });

  group('TrainerOverlayState', () {
    test('round-trips through json', () {
      const s = TrainerOverlayState(
        gear: 12,
        maxGear: 24,
        gearRatio: 2.43,
        mode: TrainerMode.simMode,
        powerW: 178,
        cadenceRpm: 86,
        ergTargetW: null,
        fields: {OverlayField.power, OverlayField.cadence},
      );
      final round = TrainerOverlayState.fromJson(s.toJson());
      expect(round, s);
    });

    test('equality respects field set', () {
      const a = TrainerOverlayState(
        gear: 1, maxGear: 2, gearRatio: 1.0,
        mode: TrainerMode.simMode,
        powerW: null, cadenceRpm: null, ergTargetW: null,
        fields: {OverlayField.power},
      );
      const b = TrainerOverlayState(
        gear: 1, maxGear: 2, gearRatio: 1.0,
        mode: TrainerMode.simMode,
        powerW: null, cadenceRpm: null, ergTargetW: null,
        fields: {OverlayField.cadence},
      );
      expect(a == b, isFalse);
    });
  });
}
