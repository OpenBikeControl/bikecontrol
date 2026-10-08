// Phone steering, driven by scripted sensors: it asks the phone for fast
// samples, times the integration by the samples' own timestamps (so a run
// turns the bars by the same angle every time), calibrates on a second of
// stillness, and keeps the gyroscope running when the compass is switched on.

import 'package:bike_control/bluetooth/devices/gyroscope/gyroscope_steering.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_sensors.dart';
import 'widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  setUp(() {
    core.settings.setPhoneSteeringMagnetometer(false);
  });

  /// Calibrates on 1 s of stillness, then turns the bars at 0.5 rad/s for
  /// 0.5 s, 50 samples a second. Returns the gauge's angle afterwards.
  Future<double> steer(FakeSensorsPlatform sensors) async {
    var now = DateTime.utc(2026, 1, 1);
    final steering = GyroscopeSteering();
    await steering.connect();
    Future<void> sample(void Function(DateTime at) feed) async {
      now = now.add(const Duration(milliseconds: 20));
      feed(now);
      // Let the broadcast streams deliver.
      await Future<void>.delayed(Duration.zero);
    }

    for (var i = 0; i < 50; i++) {
      await sample(sensors.still);
    }
    expect(steering.steeringCalibrated.value, isTrue, reason: 'a second of stillness calibrates');
    for (var i = 0; i < 25; i++) {
      await sample((at) => sensors.turning(0.5, at));
    }
    final angle = steering.steeringAngle.value;
    await steering.disconnect();
    return angle;
  }

  test('the steering angle follows the samples, not the wall clock', () async {
    final first = await steer(FakeSensorsPlatform.install());
    // A real pause between the runs changes nothing.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final second = await steer(FakeSensorsPlatform.install());

    expect(first, greaterThan(5), reason: '0.5 rad/s for 0.5 s turns the bars ~14° left');
    expect(second, first);
  });

  test('asks the phone for game-rate samples, not the 5 Hz default', () async {
    final sensors = FakeSensorsPlatform.install();
    final steering = GyroscopeSteering();
    await steering.connect();
    for (final period in sensors.requestedPeriods.values) {
      expect(period, lessThanOrEqualTo(const Duration(milliseconds: 20)));
    }
    expect(sensors.requestedPeriods.keys, containsAll(['gyroscope', 'accelerometer']));
    await steering.disconnect();
  });

  test('the compass joins the gyroscope instead of replacing it', () async {
    final sensors = FakeSensorsPlatform.install();
    final steering = GyroscopeSteering();
    await steering.setUseMagnetometer(true);
    await steering.connect();
    expect(sensors.gyroscopeListened, isTrue);
    expect(sensors.accelerometerListened, isTrue);
    expect(sensors.magnetometerListened, isTrue);
    expect(sensors.requestedPeriods['magnetometer'], lessThanOrEqualTo(const Duration(milliseconds: 20)));

    await steering.setUseMagnetometer(false);
    expect(sensors.magnetometerListened, isFalse);
    expect(sensors.gyroscopeListened, isTrue);
    await steering.disconnect();
  });

  test('the compass switch is remembered across launches', () async {
    FakeSensorsPlatform.install();
    final steering = GyroscopeSteering();
    expect(steering.useMagnetometer, isFalse);
    await steering.setUseMagnetometer(true);
    expect(core.settings.getPhoneSteeringMagnetometer(), isTrue);
    expect(GyroscopeSteering().useMagnetometer, isTrue);
  });

  group('live data', () {
    test('recalibrate() flips isCalibratedNotifier back to false', () {
      final device = GyroscopeSteering();
      device.isCalibratedNotifier.value = true; // pretend a prior calibration
      device.recalibrate();
      expect(device.isCalibratedNotifier.value, isFalse);
    });

    test('steeringAngle starts at 0', () {
      final device = GyroscopeSteering();
      expect(device.steeringAngle.value, 0.0);
    });

    test('recalibrate() resets steeringAngle to 0', () {
      final device = GyroscopeSteering();
      device.steeringAngle.value = 42.0; // simulate a live angle
      device.recalibrate();
      expect(device.steeringAngle.value, 0.0);
    });

    test('recalibrate() releases steering output', () async {
      final device = GyroscopeSteering();
      final released = expectLater(
        device.actionStream
            .where((event) => event is LogNotification)
            .cast<LogNotification>()
            .map((event) => event.message),
        emits('Buttons released'),
      );

      device.recalibrate();

      await released;
    });
  });
}
