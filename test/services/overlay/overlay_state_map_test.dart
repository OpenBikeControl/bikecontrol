import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

void main() {
  group('overlayStateToActivityMap', () {
    test('maps sim mode and omits null optional metrics', () {
      final s = TrainerOverlayState(
        gear: 7,
        maxGear: 12,
        gearRatio: 2.04,
        mode: TrainerMode.simMode,
        powerW: null,
        cadenceRpm: null,
        ergTargetW: null,
        fields: {OverlayField.gearRatio},
      );
      final m = overlayStateToActivityMap(s);
      expect(m['gear'], 7);
      expect(m['maxGear'], 12);
      expect(m['mode'], 'sim');
      expect(m['gearRatio'], 2.04);
      expect(m['showGearRatio'], true);
      expect(m['showPower'], false);
      expect(m.containsKey('powerW'), false);
      expect(m.containsKey('cadenceRpm'), false);
      expect(m.containsKey('ergTargetW'), false);
    });

    test('maps erg mode and includes present optional metrics', () {
      final s = TrainerOverlayState(
        gear: 1,
        maxGear: 24,
        gearRatio: 1.0,
        mode: TrainerMode.ergMode,
        powerW: 210,
        cadenceRpm: 88,
        ergTargetW: 250,
        fields: {OverlayField.power, OverlayField.cadence, OverlayField.ergTarget},
      );
      final m = overlayStateToActivityMap(s);
      expect(m['mode'], 'erg');
      expect(m['powerW'], 210);
      expect(m['cadenceRpm'], 88);
      expect(m['ergTargetW'], 250);
      expect(m['showErgTarget'], true);
    });
  });
}
