import 'package:bike_control/models/shifting_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

void main() {
  group('ShiftingConfig', () {
    test('default() populates sensible values', () {
      final cfg = ShiftingConfig.defaults(trainerKey: 'KICKR');
      expect(cfg.name, 'Default');
      expect(cfg.trainerKey, 'KICKR');
      expect(cfg.isActive, true);
      expect(cfg.mode, VirtualShiftingMode.targetPower);
      expect(cfg.bikeWeightKg, 10.0);
      expect(cfg.riderWeightKg, 75.0);
      expect(cfg.gradeSmoothing, true);
      expect(cfg.gearRatios, isNull);
    });

    test('toJson/fromJson round-trips', () {
      final cfg = ShiftingConfig(
        name: 'Race',
        trainerKey: 'KICKR',
        isActive: true,
        mode: VirtualShiftingMode.trackResistance,
        bikeWeightKg: 8.2,
        riderWeightKg: 68.5,
        gradeSmoothing: false,
        gearRatios: List.generate(FitnessBikeDefinition.maxGear, (i) => 0.75 + i * 0.2),
      );
      final restored = ShiftingConfig.fromJson(cfg.toJson());
      expect(restored, cfg);
    });

    test('fromJson drops wrong-length gearRatios lists', () {
      final restored = ShiftingConfig.fromJson({
        'name': 'Partial',
        'trainerKey': 'KICKR',
        'isActive': true,
        'mode': 'targetPower',
        'bikeWeightKg': 10.0,
        'riderWeightKg': 75.0,
        'gradeSmoothing': true,
        'gearRatios': [0.75, 1.0, 1.5],
      });
      expect(restored.gearRatios, isNull);
    });

    test('fromJson tolerates missing optional fields', () {
      final restored = ShiftingConfig.fromJson({
        'name': 'Minimal',
        'trainerKey': 'KICKR',
        'isActive': false,
        'mode': 'targetPower',
        'bikeWeightKg': 10.0,
        'riderWeightKg': 75.0,
        'gradeSmoothing': true,
      });
      expect(restored.gearRatios, isNull);
    });

    test('copyWith overrides specific fields', () {
      final base = ShiftingConfig.defaults(trainerKey: 'KICKR');
      final renamed = base.copyWith(name: 'Race');
      expect(renamed.name, 'Race');
      expect(renamed.trainerKey, base.trainerKey);
      expect(renamed.mode, base.mode);
    });

    test('values are clamped into legal ranges via fromJson', () {
      final cfg = ShiftingConfig.fromJson({
        'name': 'OutOfRange',
        'trainerKey': 'KICKR',
        'isActive': true,
        'mode': 'targetPower',
        'bikeWeightKg': 999.0,
        'riderWeightKg': 5.0,
        'gradeSmoothing': true,
      });
      expect(cfg.bikeWeightKg, lessThanOrEqualTo(ShiftingConfig.bikeWeightMaxKg));
      expect(cfg.riderWeightKg, greaterThanOrEqualTo(ShiftingConfig.riderWeightMinKg));
    });
  });
}
