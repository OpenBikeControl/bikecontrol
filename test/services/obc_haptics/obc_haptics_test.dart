import 'dart:typed_data';

import 'package:bike_control/services/obc_haptics/obc_haptic_pattern.dart';
import 'package:bike_control/services/obc_haptics/obc_haptics_service.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _cmd(int pattern, [int duration = 0, int intensity = 0]) =>
    Uint8List.fromList([0x03, pattern, duration, intensity]);

class _RecordingTarget implements HapticTarget {
  final played = <List<HapticPulse>>[];
  int stops = 0;

  @override
  Future<void> playPulses(List<HapticPulse> pulses) async => played.add(pulses);

  @override
  Future<void> stopHaptics() async => stops++;
}

class _FailingTarget implements HapticTarget {
  @override
  Future<void> playPulses(List<HapticPulse> pulses) => Future.error(StateError('ble gone'));

  @override
  Future<void> stopHaptics() async {}
}

void main() {
  group('ObcHapticCommand.parse', () {
    test('rejects anything that is not a 4-byte haptic message', () {
      expect(ObcHapticCommand.parse(Uint8List.fromList([0x03, 0x01, 0x00])), isNull);
      expect(ObcHapticCommand.parse(Uint8List.fromList([0x04, 0x01, 0x00, 0x00])), isNull);
      expect(ObcHapticCommand.parse(Uint8List(0)), isNull);
    });

    test('pattern 0x00 is a stop', () {
      expect(ObcHapticCommand.parse(_cmd(0x00))!.isStop, isTrue);
    });

    test('intensity 0x00 with a pattern means default, not off', () {
      final pulses = ObcHapticCommand.parse(_cmd(0x01))!.pulses;
      expect(pulses, hasLength(1));
      expect(pulses.single.intensity, ObcHapticCommand.defaultIntensity);
    });

    test('pulse counts follow the spec patterns', () {
      int count(int p) => ObcHapticCommand.parse(_cmd(p))!.pulses.length;
      expect(count(0x01), 1); // short
      expect(count(0x02), 2); // double
      expect(count(0x03), 3); // triple
      expect(count(0x04), 1); // long
      expect(count(0x05), 3); // success crescendo
      expect(count(0x06), 2); // warning
      expect(count(0x07), 3); // error
    });

    test('long lasts longer than short', () {
      final short = ObcHapticCommand.parse(_cmd(0x01))!.pulses.single.on;
      final long = ObcHapticCommand.parse(_cmd(0x04))!.pulses.single.on;
      expect(long, greaterThan(short));
    });

    test('success ramps up in intensity', () {
      final i = ObcHapticCommand.parse(_cmd(0x05, 0, 0xFF))!.pulses.map((p) => p.intensity).toList();
      expect(i[0], lessThan(i[1]));
      expect(i[1], lessThan(i[2]));
      expect(i[2], closeTo(1.0, 0.001));
    });

    test('duration byte sets the total length in 10 ms units', () {
      final single = ObcHapticCommand.parse(_cmd(0x01, 0x0A))!.pulses.single;
      expect(single.on, const Duration(milliseconds: 100));

      final double = ObcHapticCommand.parse(_cmd(0x02, 0x14))!.pulses;
      final total = double.fold(Duration.zero, (sum, p) => sum + p.on + p.off);
      expect(total, const Duration(milliseconds: 200));
    });

    test('duration is capped at 1 s', () {
      final single = ObcHapticCommand.parse(_cmd(0x04, 0xFF))!.pulses.single;
      expect(single.on, const Duration(milliseconds: 1000));
    });

    test('intensity byte scales to 0..1', () {
      expect(ObcHapticCommand.parse(_cmd(0x01, 0, 0x80))!.pulses.single.intensity, closeTo(128 / 255, 0.001));
    });

    test('reserved patterns are ignored', () {
      expect(ObcHapticCommand.parse(_cmd(0x08)), isNull);
    });

    test('last pulse has no trailing gap', () {
      expect(ObcHapticCommand.parse(_cmd(0x03))!.pulses.last.off, Duration.zero);
    });
  });

  group('ObcHapticsService', () {
    late _RecordingTarget phone;
    late _RecordingTarget controller;
    late bool controllerVibration;
    late List<String> errors;
    late ObcHapticsService service;

    setUp(() {
      phone = _RecordingTarget();
      controller = _RecordingTarget();
      controllerVibration = true;
      errors = [];
      service = ObcHapticsService(
        phone: () => phone,
        controllers: () => [controller],
        controllerVibrationEnabled: () => controllerVibration,
        onError: (context, e, s) => errors.add(context),
      );
    });

    test('plays on the phone and every vibrating controller', () async {
      await service.handle(_cmd(0x02));
      expect(phone.played, hasLength(1));
      expect(controller.played, hasLength(1));
      expect(controller.played.single, hasLength(2));
    });

    test('controller vibration setting off leaves controllers silent', () async {
      controllerVibration = false;
      await service.handle(_cmd(0x01));
      expect(phone.played, hasLength(1));
      expect(controller.played, isEmpty);
    });

    test('no phone haptics (desktop) still buzzes controllers', () async {
      service = ObcHapticsService(
        phone: () => null,
        controllers: () => [controller],
        controllerVibrationEnabled: () => true,
        onError: (context, e, s) => errors.add(context),
      );
      await service.handle(_cmd(0x01));
      expect(controller.played, hasLength(1));
    });

    test('stop is forwarded', () async {
      await service.handle(_cmd(0x00));
      expect(phone.stops, 1);
      expect(controller.stops, 1);
      expect(phone.played, isEmpty);
    });

    test('malformed input does nothing', () async {
      await service.handle(Uint8List.fromList([0x03]));
      expect(phone.played, isEmpty);
      expect(controller.played, isEmpty);
    });

    test('a failing target is reported and does not block the others', () async {
      service = ObcHapticsService(
        phone: () => phone,
        controllers: () => [_FailingTarget(), controller],
        controllerVibrationEnabled: () => true,
        onError: (context, e, s) => errors.add(context),
      );
      await service.handle(_cmd(0x01));
      expect(controller.played, hasLength(1));
      expect(phone.played, hasLength(1));
      expect(errors, ['ObcHaptics.play']);
    });
  });
}
