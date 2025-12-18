import 'package:bike_control/bluetooth/devices/gyroscope/steering_estimator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('learns gyro bias while still and prevents drift', () {
    final est = SteeringEstimator(
      biasLearningRate: 0.05,
      gyroStillThresholdRadPerSec: 0.2,
      accelStillThresholdMS2: 2.0,
      minStillTimeForBiasSec: 0.0,
      minStillTimeForRecenterSec: 999.0,
      lowPassAlpha: 0.0, // make assertions easier
      maxAngleAbsDeg: 180,
    );

    // Provide accel close to gravity so estimator considers us still.
    est.updateAccel(x: 0, y: 0, z: 9.80665);

    const bias = 0.02; // rad/s
    const dt = 0.01;

    // 10 seconds of data with pure bias.
    for (var i = 0; i < 1000; i++) {
      est.updateGyro(wz: bias, dt: dt);
    }

    // Bias should converge close to the true bias.
    expect(est.biasZRadPerSec, closeTo(bias, 0.002));

    // Angle should remain near 0 because correctedWz ~= 0.
    expect(est.angleDeg.abs(), lessThan(1.0));
  });

  test('recenters slowly after being still for long enough', () {
    final est = SteeringEstimator(
      biasLearningRate: 0.0,
      gyroStillThresholdRadPerSec: 1.0,
      accelStillThresholdMS2: 2.0,
      minStillTimeForBiasSec: 999.0,
      minStillTimeForRecenterSec: 0.2,
      recenterHalfLifeSec: 0.2,
      lowPassAlpha: 0.0,
      maxAngleAbsDeg: 180,
    );

    est.updateAccel(x: 0, y: 0, z: 9.80665);

    // Create a non-zero yaw by integrating a brief pulse.
    for (var i = 0; i < 10; i++) {
      est.updateGyro(wz: 1.0, dt: 0.01);
    }
    final initial = est.angleDeg.abs();
    expect(initial, greaterThan(0.1));

    // Now still: wz near 0, should trigger recentering.
    for (var i = 0; i < 100; i++) {
      est.updateGyro(wz: 0.0, dt: 0.01);
    }

    expect(est.angleDeg.abs(), lessThan(initial));
  });

  test("doesn't recenter while user holds a constant steering angle", () {
    final est = SteeringEstimator(
      biasLearningRate: 0.0,
      gyroStillThresholdRadPerSec: 1.0,
      accelStillThresholdMS2: 2.0,
      minStillTimeForBiasSec: 999.0,
      // Even if recenter were enabled, it must not recenter away a held angle.
      minStillTimeForRecenterSec: 0.2,
      recenterHalfLifeSec: 0.1,
      recenterDeadbandDeg: 2.0,
      lowPassAlpha: 0.0,
      maxAngleAbsDeg: 180,
    );

    est.updateAccel(x: 0, y: 0, z: 9.80665);

    // Create a held steering angle (~20 deg).
    // 0.6 rad/s for 0.6s => ~20.6 deg
    for (var i = 0; i < 60; i++) {
      est.updateGyro(wz: 0.6, dt: 0.01);
    }

    final held = est.angleDeg;
    expect(held.abs(), greaterThan(10.0));

    // Now "hold" that angle: no rotation (wz ~ 0), but device is still.
    // Previous implementation would recenter here; we must not.
    for (var i = 0; i < 400; i++) {
      est.updateGyro(wz: 0.0, dt: 0.01);
    }

    expect(est.angleDeg, closeTo(held, 0.5));
  });

  test("doesn't learn bias while held at a non-zero angle", () {
    final est = SteeringEstimator(
      biasLearningRate: 0.2,
      gyroStillThresholdRadPerSec: 0.2,
      accelStillThresholdMS2: 2.0,
      minStillTimeForBiasSec: 0.0,
      biasLearningDeadbandDeg: 3.0,
      minStillTimeForRecenterSec: double.infinity,
      lowPassAlpha: 0.0,
      maxAngleAbsDeg: 180,
    );

    est.updateAccel(x: 0, y: 0, z: 9.80665);

    // Simulate a true gyro bias.
    const trueBias = 0.02; // rad/s
    const dt = 0.01;

    // First, let it learn bias near center.
    for (var i = 0; i < 300; i++) {
      est.updateGyro(wz: trueBias, dt: dt);
    }
    expect(est.biasZRadPerSec, closeTo(trueBias, 0.004));

    // Now user turns to a steady held angle (~20 deg).
    for (var i = 0; i < 60; i++) {
      est.updateGyro(wz: 0.6 + trueBias, dt: dt);
    }
    final heldAngle = est.angleDeg;
    expect(heldAngle.abs(), greaterThan(10.0));

    // User holds that angle still for several seconds.
    // Gyro reads only bias during the hold.
    final biasBeforeHold = est.biasZRadPerSec;
    for (var i = 0; i < 600; i++) {
      est.updateGyro(wz: trueBias, dt: dt);
    }

    // Bias should not have drifted significantly.
    expect(est.biasZRadPerSec, closeTo(biasBeforeHold, 0.003));
  });
}
