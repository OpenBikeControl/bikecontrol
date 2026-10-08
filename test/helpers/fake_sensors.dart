// A phone's motion sensors, scripted: stands in for sensors_plus' platform so
// tests can feed the app's phone steering exactly the gyroscope,
// accelerometer and magnetometer samples they want, stamped with the time
// they want.
import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:sensors_plus_platform_interface/sensors_plus_platform_interface.dart';

class FakeSensorsPlatform extends SensorsPlatform {
  final _gyroscope = StreamController<GyroscopeEvent>.broadcast();
  final _accelerometer = StreamController<AccelerometerEvent>.broadcast();
  final _magnetometer = StreamController<MagnetometerEvent>.broadcast();

  /// The sampling period each sensor was last asked for, by sensor name.
  final Map<String, Duration> requestedPeriods = {};

  /// Installs a fresh fake as sensors_plus' platform and returns it.
  static FakeSensorsPlatform install() {
    final fake = FakeSensorsPlatform();
    SensorsPlatform.instance = fake;
    return fake;
  }

  bool get gyroscopeListened => _gyroscope.hasListener;
  bool get accelerometerListened => _accelerometer.hasListener;
  bool get magnetometerListened => _magnetometer.hasListener;

  @override
  Stream<GyroscopeEvent> gyroscopeEventStream({Duration samplingPeriod = SensorInterval.normalInterval}) {
    requestedPeriods['gyroscope'] = samplingPeriod;
    return _gyroscope.stream;
  }

  @override
  Stream<AccelerometerEvent> accelerometerEventStream({Duration samplingPeriod = SensorInterval.normalInterval}) {
    requestedPeriods['accelerometer'] = samplingPeriod;
    return _accelerometer.stream;
  }

  @override
  Stream<MagnetometerEvent> magnetometerEventStream({Duration samplingPeriod = SensorInterval.normalInterval}) {
    requestedPeriods['magnetometer'] = samplingPeriod;
    return _magnetometer.stream;
  }

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

  /// A magnetometer reading, microtesla in the phone's frame.
  void magnetic(double x, double y, double z, DateTime at) {
    _magnetometer.add(MagnetometerEvent(x, y, z, at));
  }
}
