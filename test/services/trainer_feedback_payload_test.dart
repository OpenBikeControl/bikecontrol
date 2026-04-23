import 'package:bike_control/services/trainer_feedback_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrainerFeedbackPayload.toJson', () {
    test('requires only user_feedback — omits every null optional field', () {
      final json = const TrainerFeedbackPayload(userFeedback: 'hello').toJson();

      expect(json, {'user_feedback': 'hello'});
    });

    test('trims user_feedback', () {
      final json = const TrainerFeedbackPayload(userFeedback: '  hello  ').toJson();

      expect(json['user_feedback'], 'hello');
    });

    test('maps rating enum to API string', () {
      expect(
        const TrainerFeedbackPayload(
          userFeedback: 'x',
          userRating: TrainerFeedbackRating.works,
        ).toJson()['user_rating'],
        'works',
      );
      expect(
        const TrainerFeedbackPayload(
          userFeedback: 'x',
          userRating: TrainerFeedbackRating.needsAdjustment,
        ).toJson()['user_rating'],
        'needs adjustment',
      );
      expect(
        const TrainerFeedbackPayload(
          userFeedback: 'x',
          userRating: TrainerFeedbackRating.doesNotWork,
        ).toJson()['user_rating'],
        'does not work at all',
      );
    });

    test('serializes full payload including diagnostic fields', () {
      final json = const TrainerFeedbackPayload(
        userFeedback: 'Works great',
        userRating: TrainerFeedbackRating.works,
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
        'user_feedback': 'Works great',
        'user_rating': 'works',
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
      final json = const TrainerFeedbackPayload(
        userFeedback: 'x',
        gearRatios: [],
      ).toJson();

      expect(json.containsKey('gear_ratios'), isFalse);
    });

    test('truncates trainer_app to 100 characters', () {
      final longName = 'a' * 150;
      final json = TrainerFeedbackPayload(
        userFeedback: 'x',
        trainerApp: longName,
      ).toJson();

      expect((json['trainer_app'] as String).length, 100);
    });

    test('serializes freetext field when present', () {
      final json = const TrainerFeedbackPayload(
        userFeedback: 'works great',
        freetext: 'Services & characteristics:\n00001826-...:\n  - 00002ad2-...',
      ).toJson();
      expect(json['freetext'], contains('00001826'));
    });

    test('omits freetext when empty or null', () {
      expect(const TrainerFeedbackPayload(userFeedback: 'x').toJson(), isNot(contains('freetext')));
      expect(
        const TrainerFeedbackPayload(userFeedback: 'x', freetext: '   ').toJson(),
        isNot(contains('freetext')),
      );
    });
  });
}
