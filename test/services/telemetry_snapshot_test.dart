import 'package:bike_control/services/telemetry_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TelemetrySnapshot.toJson', () {
    test('omits every null optional field', () {
      final json = const TelemetrySnapshot().toJson();

      expect(json, isEmpty);
    });

    test('serializes full snapshot including diagnostic fields', () {
      final json = const TelemetrySnapshot(
        bluetoothName: 'KICKR CORE 1234 (HW: 2)',
        hardwareManufacturer: 'Wahoo',
        firmwareVersion: '4.3.2',
        trainerSupportsVirtualShifting: true,
        trainerControlMode: 'SIM',
        virtualShiftingMode: 'target_power',
        gradeSmoothing: true,
        gearRatios: [1.5, 2.0, 2.5],
        appVersion: '5.1.0+42',
        appPlatform: 'ios',
        trainerApp: 'Zwift',
      ).toJson();

      expect(json, {
        'bluetooth_name': 'KICKR CORE 1234 (HW: 2)',
        'hardware_manufacturer': 'Wahoo',
        'firmware_version': '4.3.2',
        'trainer_supports_virtual_shifting': true,
        'trainer_control_mode': 'SIM',
        'virtual_shifting_mode': 'target_power',
        'grade_smoothing': true,
        'gear_ratios': [1.5, 2.0, 2.5],
        'app_version': '5.1.0+42',
        'app_platform': 'ios',
        'trainer_app': 'Zwift',
      });
    });

    test('drops empty gear_ratios list', () {
      final json = const TelemetrySnapshot(gearRatios: []).toJson();

      expect(json.containsKey('gear_ratios'), isFalse);
    });

    test('truncates trainer_app to 100 characters', () {
      final longName = 'a' * 150;
      final json = TelemetrySnapshot(trainerApp: longName).toJson();

      expect((json['trainer_app'] as String).length, 100);
    });

    test('serializes freetext field when present', () {
      final json = const TelemetrySnapshot(
        freetext: 'Services & characteristics:\n00001826-...:\n  - 00002ad2-...',
      ).toJson();

      expect(json['freetext'], contains('00001826'));
    });

    test('omits freetext when empty or null', () {
      expect(const TelemetrySnapshot().toJson(), isNot(contains('freetext')));
      expect(
        const TelemetrySnapshot(freetext: '   ').toJson(),
        isNot(contains('freetext')),
      );
    });

    test('drops empty FTMS feature lists', () {
      final json = const TelemetrySnapshot(
        trainerFtmsMachineFeatures: [],
        trainerFtmsTargetSettingFlags: [],
      ).toJson();

      expect(json.containsKey('trainer_ftms_machine_features'), isFalse);
      expect(json.containsKey('trainer_ftms_target_setting_flags'), isFalse);
    });
  });
}
