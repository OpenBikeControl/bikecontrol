import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/models/user_settings.dart';
import 'package:bike_control/utils/erg_power_stepping.dart';
import 'package:flutter_test/flutter_test.dart';

/// The ERG start power source and the ERG +/- step are stored on the
/// trainer's shifting config, next to the other trainer settings.
void main() {
  test('defaults to the current power, a 5 W step and Power Lock auto-release', () {
    final cfg = ShiftingConfig.defaults(trainerKey: 'KICKR');
    expect(cfg.ergStartSource, ErgStartSource.currentPower);
    expect(cfg.ergStepW, 5);
    expect(cfg.powerLockAutoRelease, isTrue);
  });

  test('a config stored before the ERG settings existed reads as the defaults', () {
    final cfg = ShiftingConfig.fromJson({'name': 'Default', 'trainerKey': 'KICKR', 'isActive': true});
    expect(cfg.ergStartSource, ErgStartSource.currentPower);
    expect(cfg.ergStepW, ErgPowerStepping.defaultStepW);
    expect(cfg.powerLockAutoRelease, isTrue);
  });

  test('a 7.4 config moves to the new default unless it chose the current power', () {
    final base = {'name': 'Default', 'trainerKey': 'KICKR', 'isActive': true};
    // 7.4 wrote its default "lastTarget" into every saved config.
    expect(ShiftingConfig.fromJson({...base, 'ergStartSource': 'lastTarget'}).ergStartSource, ErgStartSource.currentPower);
    expect(ShiftingConfig.fromJson({...base, 'ergStartSource': 'currentPower'}).ergStartSource, ErgStartSource.currentPower);
    // A choice saved under the new key is kept, whatever the old key says.
    expect(
      ShiftingConfig.fromJson({...base, 'ergStart': 'lastTarget', 'ergStartSource': 'currentPower'}).ergStartSource,
      ErgStartSource.lastTarget,
    );
  });

  test('round-trips through JSON', () {
    final cfg = ShiftingConfig.defaults(
      trainerKey: 'KICKR',
    ).copyWith(ergStartSource: ErgStartSource.lastTarget, ergStepW: 25, powerLockAutoRelease: false);
    final back = ShiftingConfig.fromJson(cfg.toJson());
    expect(back.ergStartSource, ErgStartSource.lastTarget);
    expect(back.ergStepW, 25);
    expect(back.powerLockAutoRelease, isFalse);
  });

  test('an unknown step or source falls back to the defaults', () {
    final json = ShiftingConfig.defaults(trainerKey: 'KICKR').toJson();
    final wild = ShiftingConfig.fromJson({...json, 'ergStepW': 7, 'ergStart': 'nonsense'});
    expect(wild.ergStepW, ErgPowerStepping.defaultStepW);
    expect(wild.ergStartSource, ErgStartSource.currentPower);
  });

  test('takes part in equality', () {
    final a = ShiftingConfig.defaults(trainerKey: 'KICKR');
    expect(a.copyWith(ergStepW: 10), isNot(a));
    expect(a.copyWith(ergStartSource: ErgStartSource.lastTarget), isNot(a));
    expect(a.copyWith(powerLockAutoRelease: false), isNot(a));
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
