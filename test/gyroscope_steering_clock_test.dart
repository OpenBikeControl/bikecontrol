// Phone steering integrates the gyroscope's rate over the time between
// samples. That time comes from the device's clock seam, so samples fed on a
// fake clock turn the bars by exactly the same angle on every run — what the
// feature video relies on.
import 'dart:async';

import 'package:bike_control/bluetooth/devices/gyroscope/gyroscope_steering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_sensors.dart';
import 'widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  /// Calibrates on 1 s of stillness, then turns the bars at 0.5 rad/s for
  /// 0.5 s, 50 samples a second. Returns the gauge's angle afterwards.
  Future<double> steer(FakeSensorsPlatform sensors) async {
    var now = DateTime.utc(2026, 1, 1);
    final steering = GyroscopeSteering()..nowFn = () => now;
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
}
