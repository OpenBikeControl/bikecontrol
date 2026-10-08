// Phone steering's estimator: integrates the gyroscope about the world's up
// axis (so a tilted mount reads the full angle), learns the gyro's bias while
// the bars are still, and — once the compass has seen a left and a right
// turn — lets the magnetometer take the slow drift out, even with a magnetic
// mount sitting on the sensor.
import 'package:bike_control/bluetooth/devices/gyroscope/steering_estimator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/phone_sim.dart';

void main() {
  /// A fresh estimator on [sim], calibrated after a second of stillness.
  SteeringEstimator calibrated(PhoneSim sim, {bool feedMag = false}) {
    final est = SteeringEstimator();
    sim.drive(est, seconds: 1.0, feedMag: feedMag);
    est.calibrate();
    return est;
  }

  group('gyroscope', () {
    test('a steer left and back to centre reads zero again', () {
      final sim = PhoneSim(gyroBiasRadPerSec: [0.004, -0.003, 0.02]);
      final est = calibrated(sim);

      sim.drive(est, seconds: 0.5, rateDegPerSec: 60);
      sim.drive(est, seconds: 0.3);
      expect(est.angleDeg, closeTo(30, 1.0));

      sim.drive(est, seconds: 0.5, rateDegPerSec: -60);
      sim.drive(est, seconds: 0.3);
      expect(est.angleDeg, closeTo(0, 0.5));
      expect(sim.yawDeg, closeTo(0, 1e-9));
    });

    test('a tilted mount still reads the full steering angle', () {
      final sim = PhoneSim(tiltDeg: 50);
      final est = calibrated(sim);

      sim.drive(est, seconds: 0.5, rateDegPerSec: 60);
      sim.drive(est, seconds: 0.3);
      // Reading only the phone's z axis would give cos(50°)·30° ≈ 19°.
      expect(est.angleDeg, closeTo(30, 1.0));

      sim.drive(est, seconds: 0.5, rateDegPerSec: -60);
      sim.drive(est, seconds: 0.3);
      expect(est.angleDeg, closeTo(0, 0.5));
    });

    test('left is positive, right is negative', () {
      final sim = PhoneSim();
      final est = calibrated(sim);
      expect(sim.drive(est, seconds: 0.5, rateDegPerSec: 40), greaterThan(10));
      sim.drive(est, seconds: 1.0, rateDegPerSec: -40);
      expect(est.angleDeg, lessThan(-10));
    });

    test('a slow sample integrates its whole duration', () {
      // sensors_plus delivers 5 Hz when nobody asks for more; the estimator
      // must not quietly shorten such a step.
      final sim = PhoneSim();
      final est = calibrated(sim);
      sim.drive(est, seconds: 1.0, rateDegPerSec: 30, dt: 0.2);
      sim.drive(est, seconds: 0.5);
      expect(est.angleDeg, closeTo(30, 1.0));
    });

    test('learns the gyro bias while still and holds centre', () {
      final sim = PhoneSim(gyroBiasRadPerSec: [0, 0, 0.02]);
      final est = calibrated(sim);
      sim.drive(est, seconds: 20);
      expect(est.yawBiasRadPerSec, closeTo(0.02, 0.002));
      expect(est.angleDeg.abs(), lessThan(1.0));
    });

    test('a held angle neither recentres nor retrains the bias', () {
      final sim = PhoneSim(gyroBiasRadPerSec: [0, 0, 0.02]);
      final est = calibrated(sim);
      sim.drive(est, seconds: 0.5, rateDegPerSec: 40);
      sim.drive(est, seconds: 0.3);
      final held = est.angleDeg;
      expect(held, closeTo(20, 1.0));

      sim.drive(est, seconds: 10);
      expect(est.angleDeg, closeTo(held, 0.5));
      expect(est.yawBiasRadPerSec, closeTo(0.02, 0.003));
    });

    test('clamps runaway angles', () {
      final sim = PhoneSim();
      final est = calibrated(sim);
      sim.drive(est, seconds: 5, rateDegPerSec: 90);
      expect(est.angleDeg, lessThanOrEqualTo(60));
    });
  });

  group('magnetometer', () {
    test('stays out of it until the bars have turned both ways', () {
      final sim = PhoneSim(tiltDeg: 45, hardIronMicroTesla: [250, -120, 300]);
      final est = calibrated(sim, feedMag: true);
      sim.drive(est, seconds: 5, feedMag: true);
      expect(est.magnetometerLocked, isFalse);

      sim.drive(est, seconds: 0.5, rateDegPerSec: 50, feedMag: true);
      sim.drive(est, seconds: 1.0, rateDegPerSec: -50, feedMag: true);
      sim.drive(est, seconds: 0.5, rateDegPerSec: 50, feedMag: true);
      expect(est.magnetometerLocked, isTrue);
    });

    test('takes the drift out of a held angle despite a magnetic mount', () {
      final sim = PhoneSim(tiltDeg: 45, hardIronMicroTesla: [250, -120, 300]);
      final est = calibrated(sim, feedMag: true);
      sim.drive(est, seconds: 0.5, rateDegPerSec: 50, feedMag: true);
      sim.drive(est, seconds: 1.0, rateDegPerSec: -50, feedMag: true);
      sim.drive(est, seconds: 0.5, rateDegPerSec: 50, feedMag: true);
      expect(est.magnetometerLocked, isTrue);

      // The gyro's bias wanders after calibration: 0.57°/s, 34° a minute.
      sim.gyroBiasRadPerSec = [0, 0, 0.01];
      sim.drive(est, seconds: 0.5, rateDegPerSec: 40, feedMag: true);
      sim.drive(est, seconds: 60, feedMag: true);
      expect(est.angleDeg, closeTo(20, 2.0));

      sim.drive(est, seconds: 0.5, rateDegPerSec: -40, feedMag: true);
      sim.drive(est, seconds: 5, feedMag: true);
      expect(est.angleDeg, closeTo(0, 2.0));
    });

    test('the same ride without the compass drifts away', () {
      final sim = PhoneSim(tiltDeg: 45, hardIronMicroTesla: [250, -120, 300]);
      final est = calibrated(sim);
      sim.drive(est, seconds: 0.5, rateDegPerSec: 50);
      sim.drive(est, seconds: 1.0, rateDegPerSec: -50);
      sim.drive(est, seconds: 0.5, rateDegPerSec: 50);
      sim.gyroBiasRadPerSec = [0, 0, 0.01];
      sim.drive(est, seconds: 0.5, rateDegPerSec: 40);
      sim.drive(est, seconds: 60);
      expect((est.angleDeg - 20).abs(), greaterThan(10));
    });

    test('keeps left positive after it locks', () {
      final sim = PhoneSim(tiltDeg: 30, hardIronMicroTesla: [-80, 40, 500]);
      final est = calibrated(sim, feedMag: true);
      sim.drive(est, seconds: 0.5, rateDegPerSec: -50, feedMag: true);
      sim.drive(est, seconds: 1.0, rateDegPerSec: 50, feedMag: true);
      sim.drive(est, seconds: 0.5, rateDegPerSec: -50, feedMag: true);
      expect(est.magnetometerLocked, isTrue);

      sim.drive(est, seconds: 0.5, rateDegPerSec: 40, feedMag: true);
      sim.drive(est, seconds: 10, feedMag: true);
      expect(est.angleDeg, closeTo(20, 1.5));
      sim.drive(est, seconds: 1.0, rateDegPerSec: -40, feedMag: true);
      sim.drive(est, seconds: 10, feedMag: true);
      expect(est.angleDeg, closeTo(-20, 1.5));
    });

    test('holds through sensor noise and pedalling vibration', () {
      final sim = PhoneSim(tiltDeg: 45, hardIronMicroTesla: [250, -120, 300], gyroBiasRadPerSec: [0.003, 0.002, 0.01]);
      final est = calibrated(sim, feedMag: true);
      sim.gyroNoiseRadPerSec = 0.005;
      sim.accelNoiseMS2 = 1.0;
      sim.magNoiseMicroTesla = 1.5;
      sim.drive(est, seconds: 0.5, rateDegPerSec: 50, feedMag: true);
      sim.drive(est, seconds: 1.0, rateDegPerSec: -50, feedMag: true);
      sim.drive(est, seconds: 0.5, rateDegPerSec: 50, feedMag: true);
      expect(est.magnetometerLocked, isTrue);

      // The gyro's bias wanders on; with the bars shaking nothing is 'still'.
      sim.gyroBiasRadPerSec = [0.003, 0.002, 0.02];
      sim.drive(est, seconds: 0.5, rateDegPerSec: 40, feedMag: true);
      sim.drive(est, seconds: 120, feedMag: true);
      expect(est.angleDeg, closeTo(20, 3.0));
      sim.drive(est, seconds: 0.5, rateDegPerSec: -40, feedMag: true);
      sim.drive(est, seconds: 10, feedMag: true);
      expect(est.angleDeg, closeTo(0, 3.0));
    });

    test('recalibrating forgets the mount it learned', () {
      final sim = PhoneSim(tiltDeg: 45, hardIronMicroTesla: [250, -120, 300]);
      final est = calibrated(sim, feedMag: true);
      sim.drive(est, seconds: 0.5, rateDegPerSec: 50, feedMag: true);
      sim.drive(est, seconds: 1.0, rateDegPerSec: -50, feedMag: true);
      sim.drive(est, seconds: 0.5, rateDegPerSec: 50, feedMag: true);
      expect(est.magnetometerLocked, isTrue);
      est.calibrate();
      expect(est.magnetometerLocked, isFalse);
      expect(est.angleDeg, 0);
    });
  });
}
