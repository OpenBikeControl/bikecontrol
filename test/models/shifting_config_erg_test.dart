import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/models/user_settings.dart';
import 'package:bike_control/utils/erg_power_stepping.dart';
import 'package:flutter_test/flutter_test.dart';

/// The ERG start power source and the ERG +/- step are stored on the
/// trainer's shifting config, next to the other trainer settings.
void main() {
  test('defaults to the last target and a 5 W step', () {
    final cfg = ShiftingConfig.defaults(trainerKey: 'KICKR');
    expect(cfg.ergStartSource, ErgStartSource.lastTarget);
    expect(cfg.ergStepW, 5);
  });

  test('a config stored before the ERG settings existed reads as the defaults', () {
    final cfg = ShiftingConfig.fromJson({'name': 'Default', 'trainerKey': 'KICKR', 'isActive': true});
    expect(cfg.ergStartSource, ErgStartSource.lastTarget);
    expect(cfg.ergStepW, ErgPowerStepping.defaultStepW);
  });

  test('round-trips through JSON', () {
    final cfg = ShiftingConfig.defaults(
      trainerKey: 'KICKR',
    ).copyWith(ergStartSource: ErgStartSource.currentPower, ergStepW: 25);
    final back = ShiftingConfig.fromJson(cfg.toJson());
    expect(back.ergStartSource, ErgStartSource.currentPower);
    expect(back.ergStepW, 25);
  });

  test('an unknown step or source falls back to the defaults', () {
    final json = ShiftingConfig.defaults(trainerKey: 'KICKR').toJson();
    final wild = ShiftingConfig.fromJson({...json, 'ergStepW': 7, 'ergStartSource': 'nonsense'});
    expect(wild.ergStepW, ErgPowerStepping.defaultStepW);
    expect(wild.ergStartSource, ErgStartSource.lastTarget);
  });

  test('takes part in equality', () {
    final a = ShiftingConfig.defaults(trainerKey: 'KICKR');
    expect(a.copyWith(ergStepW: 10), isNot(a));
    expect(a.copyWith(ergStartSource: ErgStartSource.currentPower), isNot(a));
    expect(a.copyWith(ergStepW: 10), a.copyWith(ergStepW: 10));
    expect(a.copyWith(ergStepW: 10).hashCode, a.copyWith(ergStepW: 10).hashCode);
  });

  test('syncs with the shifting configs in user_settings', () {
    final settings = UserSettings(
      userId: 'u1',
      deviceId: 'd1',
      shiftingConfigs: [
        ShiftingConfig.defaults(
          trainerKey: 'KICKR',
        ).copyWith(ergStartSource: ErgStartSource.currentPower, ergStepW: 1),
      ],
    );
    final restored = UserSettings.fromJson(settings.toJson()).shiftingConfigs!.single;
    expect(restored.ergStartSource, ErgStartSource.currentPower);
    expect(restored.ergStepW, 1);
  });
}
