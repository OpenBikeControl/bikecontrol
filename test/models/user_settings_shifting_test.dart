import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/models/user_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

void main() {
  test('UserSettings round-trips shiftingConfigs via the top-level column', () {
    final settings = UserSettings(
      userId: 'u1',
      deviceId: 'd1',
      keymaps: {'Zwift': []},
      shiftingConfigs: const [
        ShiftingConfig(
          name: 'Race',
          trainerKey: 'KICKR',
          isActive: true,
          mode: VirtualShiftingMode.trackResistance,
          bikeWeightKg: 8.2,
          riderWeightKg: 68.5,
          gradeSmoothing: false,
        ),
      ],
    );

    final json = settings.toJson();
    expect(json['shifting_configs'], isA<List>());
    expect(json['keymaps'], isNot(contains('_shifting_configs')));

    final restored = UserSettings.fromJson(json);
    expect(restored.shiftingConfigs, isNotNull);
    expect(restored.shiftingConfigs!.single.name, 'Race');
    expect(restored.shiftingConfigs!.single.bikeWeightKg, 8.2);
  });

  test('UserSettings.fromJson tolerates missing shifting_configs column', () {
    final restored = UserSettings.fromJson({
      'user_id': 'u1',
      'device_id': 'd1',
      'version': 1,
    });
    expect(restored.shiftingConfigs, isNull);
  });
}
