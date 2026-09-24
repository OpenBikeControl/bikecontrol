// A phone's motion sensors, scripted: stands in for sensors_plus' platform so
// tests can feed the app's phone steering exactly the gyroscope and
// accelerometer samples they want, on the fake clock.
import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:sensors_plus_platform_interface/sensors_plus_platform_interface.dart';

class FakeSensorsPlatform extends SensorsPlatform {
  final _gyroscope = StreamController<GyroscopeEvent>.broadcast();
  final _accelerometer = StreamController<AccelerometerEvent>.broadcast();
  final _magnetometer = StreamController<MagnetometerEvent>.broadcast();

  /// Installs a fresh fake as sensors_plus' platform and returns it.
  static FakeSensorsPlatform install() {
    final fake = FakeSensorsPlatform();
    SensorsPlatform.instance = fake;
    return fake;
  }

  @override
  Stream<GyroscopeEvent> gyroscopeEventStream({Duration samplingPeriod = SensorInterval.normalInterval}) =>
      _gyroscope.stream;

  @override
  Stream<AccelerometerEvent> accelerometerEventStream({Duration samplingPeriod = SensorInterval.normalInterval}) =>
      _accelerometer.stream;

  @override
  Stream<MagnetometerEvent> magnetometerEventStream({Duration samplingPeriod = SensorInterval.normalInterval}) =>
      _magnetometer.stream;

  /// A handlebar-mounted phone at rest: gravity on z, nothing else.
  void still(DateTime at) {
    _accelerometer.add(AccelerometerEvent(0, 0, 9.80665, at));
    _gyroscope.add(GyroscopeEvent(0, 0, 0, at));
  }

  /// The bars turning at [yawRadPerSec] around the phone's z axis (positive
  /// turns them left).
  void turning(double yawRadPerSec, DateTime at) {
    _accelerometer.add(AccelerometerEvent(0, 0, 9.80665, at));
    _gyroscope.add(GyroscopeEvent(0, 0, yawRadPerSec, at));
  }
}
