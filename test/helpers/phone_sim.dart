// A phone on a handlebar mount, simulated: produces the accelerometer,
// gyroscope and magnetometer samples sensors_plus would deliver for a given
// mount tilt, steering angle, gyro bias and magnetic offset of the mount.
//
// Frames: world x = east, y = north, z = up. Phone axes as sensors_plus
// reports them: x right, y top of screen, z out of the screen. A flat,
// face-up phone with its top pointing north is the untilted mount; [tiltDeg]
// pitches its top up towards the rider. Steering turns the bars about the
// world's up axis, positive = left (counter-clockwise seen from above).
import 'dart:math';

import 'package:bike_control/bluetooth/devices/gyroscope/steering_estimator.dart';

typedef Vec3 = List<double>;

class PhoneSim {
  PhoneSim({
    double tiltDeg = 0,
    this.gyroBiasRadPerSec = const [0, 0, 0],
    this.hardIronMicroTesla = const [0, 0, 0],
    this.earthFieldMicroTesla = const [0, 20, -45],
    int seed = 1,
  }) : _tilt = tiltDeg * pi / 180,
       _random = Random(seed);

  final double _tilt;
  final Random _random;

  /// Sensor noise, 1σ: gyro rad/s, accelerometer m/s² (pedalling shakes the
  /// mount), magnetometer µT. All zero = ideal sensors.
  double gyroNoiseRadPerSec = 0;
  double accelNoiseMS2 = 0;
  double magNoiseMicroTesla = 0;

  double _gauss(double sigma) {
    if (sigma == 0) return 0;
    final u1 = 1 - _random.nextDouble(), u2 = _random.nextDouble();
    return sigma * sqrt(-2 * log(u1)) * cos(2 * pi * u2);
  }

  Vec3 _noisy(Vec3 v, double sigma) => [v[0] + _gauss(sigma), v[1] + _gauss(sigma), v[2] + _gauss(sigma)];

  /// Added to every gyroscope sample, in the phone's frame. Mutable so a test
  /// can let the bias wander mid-ride.
  Vec3 gyroBiasRadPerSec;

  /// The mount's own magnetic field, fixed in the phone's frame.
  final Vec3 hardIronMicroTesla;

  /// The Earth's field in the world frame (north and down, like in Europe).
  final Vec3 earthFieldMicroTesla;

  /// Where the bars point right now, degrees, positive = left.
  double yawDeg = 0;

  static const g = 9.80665;

  /// World → phone for the current yaw: Mᵀ·Rz(−yaw).
  Vec3 _toPhone(Vec3 w) {
    final yaw = yawDeg * pi / 180;
    final c = cos(yaw), s = sin(yaw);
    // Rz(−yaw)·w
    final r = [c * w[0] + s * w[1], -s * w[0] + c * w[1], w[2]];
    // Mᵀ = Rx(−tilt)
    final ct = cos(_tilt), st = sin(_tilt);
    return [r[0], ct * r[1] + st * r[2], -st * r[1] + ct * r[2]];
  }

  Vec3 accel() => _noisy(_toPhone([0, 0, g]), accelNoiseMS2);

  Vec3 gyro(double yawRateDegPerSec) {
    final w = _toPhone([0, 0, yawRateDegPerSec * pi / 180]);
    return _noisy([w[0] + gyroBiasRadPerSec[0], w[1] + gyroBiasRadPerSec[1], w[2] + gyroBiasRadPerSec[2]], gyroNoiseRadPerSec);
  }

  Vec3 mag() {
    final e = _toPhone(earthFieldMicroTesla);
    return _noisy([e[0] + hardIronMicroTesla[0], e[1] + hardIronMicroTesla[1], e[2] + hardIronMicroTesla[2]], magNoiseMicroTesla);
  }

  /// Turns the bars at [rateDegPerSec] for [seconds], feeding the estimator
  /// every [dt]. Returns the estimator's angle at the end.
  double drive(
    SteeringEstimator est, {
    required double seconds,
    double rateDegPerSec = 0,
    double dt = 0.02,
    bool feedMag = false,
  }) {
    final steps = (seconds / dt).round();
    var angle = est.angleDeg;
    for (var i = 0; i < steps; i++) {
      yawDeg += rateDegPerSec * dt;
      final a = accel();
      est.updateAccel(x: a[0], y: a[1], z: a[2]);
      if (feedMag) {
        final m = mag();
        est.updateMag(x: m[0], y: m[1], z: m[2]);
      }
      final w = gyro(rateDegPerSec);
      angle = est.updateGyro(x: w[0], y: w[1], z: w[2], dt: dt);
    }
    return angle;
  }
}
