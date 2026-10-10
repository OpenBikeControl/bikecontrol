import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/models/user_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

/// The virtual-shifting difficulty is stored on the trainer's shifting config,
/// so it is per trainer, follows config switches and syncs with the rest.
void main() {
  test('defaults to the engine default', () {
    final cfg = ShiftingConfig.defaults(trainerKey: 'KICKR');
    expect(cfg.difficultyPct, FitnessBikeDefinition.defaultDifficultyPct);
  });

  test('a config stored before difficulty existed reads as the default', () {
    final cfg = ShiftingConfig.fromJson({'name': 'Default', 'trainerKey': 'KICKR', 'isActive': true});
    expect(cfg.difficultyPct, 100);
  });

  test('round-trips through JSON and is clamped on the way in', () {
    final cfg = ShiftingConfig.defaults(trainerKey: 'KICKR').copyWith(difficultyPct: 70);
    expect(ShiftingConfig.fromJson(cfg.toJson()).difficultyPct, 70);
    expect(
      ShiftingConfig.fromJson({...cfg.toJson(), 'difficultyPct': 5}).difficultyPct,
      FitnessBikeDefinition.minDifficultyPct,
    );
    expect(
      ShiftingConfig.fromJson({...cfg.toJson(), 'difficultyPct': 900}).difficultyPct,
      FitnessBikeDefinition.maxDifficultyPct,
    );
  });

  test('takes part in equality, so a changed difficulty is a changed config', () {
    final a = ShiftingConfig.defaults(trainerKey: 'KICKR');
    expect(a.copyWith(difficultyPct: 80), isNot(a));
    expect(a.copyWith(difficultyPct: 80), a.copyWith(difficultyPct: 80));
    expect(a.copyWith(difficultyPct: 80).hashCode, a.copyWith(difficultyPct: 80).hashCode);
  });

  test('syncs with the shifting configs in user_settings', () {
    final settings = UserSettings(
      userId: 'u1',
      deviceId: 'd1',
      shiftingConfigs: [ShiftingConfig.defaults(trainerKey: 'KICKR').copyWith(difficultyPct: 65)],
    );
    final restored = UserSettings.fromJson(settings.toJson());
    expect(restored.shiftingConfigs!.single.difficultyPct, 65);
  });
}
