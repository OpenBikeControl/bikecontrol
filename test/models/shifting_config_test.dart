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
      expect(cfg.maxGear, ShiftingConfig.maxGearDefault);
      expect(cfg.gearRatios, isNull);
    });

    test('default() honours an explicit maxGear override', () {
      final cfg = ShiftingConfig.defaults(trainerKey: 'KICKR', maxGear: 30);
      expect(cfg.maxGear, 30);
    });

    test('default() clamps an out-of-range maxGear', () {
      expect(ShiftingConfig.defaults(trainerKey: 'KICKR', maxGear: 99).maxGear, 30);
      expect(ShiftingConfig.defaults(trainerKey: 'KICKR', maxGear: 0).maxGear, 1);
    });

    test('fromJson round-trips maxGear + clamps out-of-range stored values', () {
      final stored = {
        'name': 'x',
        'trainerKey': 'KICKR',
        'isActive': true,
        'mode': 'targetPower',
        'bikeWeightKg': 10.0,
        'riderWeightKg': 75.0,
        'gradeSmoothing': true,
        'maxGear': 99,
      };
      expect(ShiftingConfig.fromJson(stored).maxGear, 30);

      final ok = {...stored, 'maxGear': 28};
      expect(ShiftingConfig.fromJson(ok).maxGear, 28);
    });

    test('fromJson defaults maxGear to 24 when missing', () {
      final restored = ShiftingConfig.fromJson({
        'name': 'Minimal',
        'trainerKey': 'KICKR',
        'isActive': false,
        'mode': 'targetPower',
        'bikeWeightKg': 10.0,
        'riderWeightKg': 75.0,
        'gradeSmoothing': true,
      });
      expect(restored.maxGear, 24);
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
        gearRatios: List.generate(24, (i) => 0.75 + i * 0.2),
      );
      final restored = ShiftingConfig.fromJson(cfg.toJson());
      expect(restored, cfg);
    });

    test('fromJson accepts any 1..30 entry gearRatios list', () {
      final restored24 = ShiftingConfig.fromJson({
        'name': '24g',
        'trainerKey': 'KICKR',
        'isActive': true,
        'mode': 'targetPower',
        'bikeWeightKg': 10.0,
        'riderWeightKg': 75.0,
        'gradeSmoothing': true,
        'gearRatios': List<double>.filled(24, 1.0),
      });
      expect(restored24.gearRatios?.length, 24);

      final restored30 = ShiftingConfig.fromJson({
        'name': '30g',
        'trainerKey': 'KICKR',
        'isActive': true,
        'mode': 'targetPower',
        'bikeWeightKg': 10.0,
        'riderWeightKg': 75.0,
        'gradeSmoothing': true,
        'gearRatios': List<double>.filled(30, 1.0),
      });
      expect(restored30.gearRatios?.length, 30);

      final restored3 = ShiftingConfig.fromJson({
        'name': '3g',
        'trainerKey': 'KICKR',
        'isActive': true,
        'mode': 'targetPower',
        'bikeWeightKg': 10.0,
        'riderWeightKg': 75.0,
        'gradeSmoothing': true,
        'gearRatios': [0.75, 1.0, 1.5],
      });
      expect(restored3.gearRatios?.length, 3);
    });

    test('fromJson drops empty and out-of-bounds gearRatios lists', () {
      ShiftingConfig call(List raw) => ShiftingConfig.fromJson({
        'name': 'x',
        'trainerKey': 'KICKR',
        'isActive': true,
        'mode': 'targetPower',
        'bikeWeightKg': 10.0,
        'riderWeightKg': 75.0,
        'gradeSmoothing': true,
        'gearRatios': raw,
      });
      expect(call([]).gearRatios, isNull);
      expect(call(List<double>.filled(31, 1.0)).gearRatios, isNull);
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

    test('copyWith clearGearRatios drops the gear list', () {
      final withRatios = ShiftingConfig.defaults(
        trainerKey: 'KICKR',
      ).copyWith(gearRatios: List.generate(24, (_) => 1.0));
      expect(withRatios.gearRatios, isNotNull);
      expect(withRatios.copyWith(clearGearRatios: true).gearRatios, isNull);
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
