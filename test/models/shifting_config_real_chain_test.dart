import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/models/user_settings.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where the rider's real chain sits at the trainer (chainring on the bike,
/// cog on the trainer) is stored on the trainer's shifting config: it is a
/// fact about that bike on that trainer, and the physics need it.
void main() {
  test('defaults to 34/17, the 2.0 the physics always assumed', () {
    final cfg = ShiftingConfig.defaults(trainerKey: 'KICKR');
    expect(cfg.realChainringTeeth, 34);
    expect(cfg.realCogTeeth, 17);
    expect(cfg.realChainRatio, 2.0);
  });

  test('a config stored before the real chain existed reads as the default', () {
    final cfg = ShiftingConfig.fromJson({'name': 'Default', 'trainerKey': 'KICKR', 'isActive': true});
    expect(cfg.realChainRatio, 2.0);
  });

  test('round-trips through JSON and is clamped on the way in', () {
    final cfg = ShiftingConfig.defaults(trainerKey: 'KICKR').copyWith(realChainringTeeth: 39, realCogTeeth: 14);
    final back = ShiftingConfig.fromJson(cfg.toJson());
    expect(back.realChainringTeeth, 39);
    expect(back.realCogTeeth, 14);
    expect(back.realChainRatio, closeTo(2.786, 0.001));

    final wild = ShiftingConfig.fromJson({...cfg.toJson(), 'realChainringTeeth': 5, 'realCogTeeth': 99});
    expect(wild.realChainringTeeth, ShiftingConfig.chainringTeethMin);
    expect(wild.realCogTeeth, ShiftingConfig.realCogTeethMax);
  });

  test('takes part in equality', () {
    final a = ShiftingConfig.defaults(trainerKey: 'KICKR');
    expect(a.copyWith(realCogTeeth: 14), isNot(a));
    expect(a.copyWith(realChainringTeeth: 39), isNot(a));
    expect(a.copyWith(realCogTeeth: 14), a.copyWith(realCogTeeth: 14));
    expect(a.copyWith(realCogTeeth: 14).hashCode, a.copyWith(realCogTeeth: 14).hashCode);
  });

  test('syncs with the shifting configs in user_settings', () {
    final settings = UserSettings(
      userId: 'u1',
      deviceId: 'd1',
      shiftingConfigs: [ShiftingConfig.defaults(trainerKey: 'KICKR').copyWith(realChainringTeeth: 39, realCogTeeth: 14)],
    );
    final restored = UserSettings.fromJson(settings.toJson()).shiftingConfigs!.single;
    expect(restored.realChainringTeeth, 39);
    expect(restored.realCogTeeth, 14);
  });
}
