import 'dart:math';

/// Pure-Dart steering estimator for phone-on-handlebar steering.
///
/// Design goals:
/// - Avoid long-term drift on platforms like iOS by continuously estimating
///   and subtracting gyro bias.
/// - Keep it testable (no Flutter/sensors dependencies).
///
/// NOTE: This is not a full AHRS. It uses bias-corrected integration and
/// a "stillness" detector to learn gyro bias and optionally auto-recenter.
class SteeringEstimator {
  SteeringEstimator({
    this.biasLearningRate = 0.02,
    this.gyroStillThresholdRadPerSec = 0.03,
    this.accelStillThresholdMS2 = 0.6,
    this.minStillTimeForBiasSec = 0.35,
    this.biasLearningDeadbandDeg = 3.0,
    this.minStillTimeForRecenterSec = double.infinity,
    this.recenterHalfLifeSec = 0.7,
    this.recenterDeadbandDeg = 2.0,
    this.maxAngleAbsDeg = 60,
    this.lowPassAlpha = 0.9,

    // Responsiveness / smoothing tuning.
    // When steering changes quickly we reduce smoothing, but keep more
    // smoothing when stable to avoid jitter.
    this.lowPassAlphaStable = 0.9,
    this.lowPassAlphaMoving = 0.55,
    this.motionAngleRateDegPerSecForMinAlpha = 90.0,

    // Cap dt to avoid "freezing" the estimator on occasional long frames.
    this.maxDtSec = 0.05,
  });

  // Tunables
  final double biasLearningRate;
  final double gyroStillThresholdRadPerSec;
  final double accelStillThresholdMS2;
  final double minStillTimeForBiasSec;
  final double biasLearningDeadbandDeg;
  final double minStillTimeForRecenterSec;
  final double recenterHalfLifeSec;
  final double recenterDeadbandDeg;
  final double maxAngleAbsDeg;

  /// Backwards-compatible, kept as-is.
  ///
  /// If you set `lowPassAlpha = 0.0`, filtering is disabled.
  final double lowPassAlpha;

  /// Smoothing used when the angle is stable.
  ///
  /// Default mirrors the original behavior (`0.9`).
  final double lowPassAlphaStable;

  /// Smoothing used when the angle is changing quickly.
  ///
  /// Lower alpha => faster response.
  final double lowPassAlphaMoving;

  /// Angle rate (deg/s) at which we reach `lowPassAlphaMoving`.
  final double motionAngleRateDegPerSecForMinAlpha;

  /// Maximum timestep used for integration/bias learning.
  final double maxDtSec;

  // State
  double _accelX = 0, _accelY = 0, _accelZ = 0;
  bool _hasAccel = false;

  double _biasZ = 0.0; // rad/s
  double _yawDeg = 0.0;
  double _filteredYawDeg = 0.0;

  double _stillTimeSec = 0.0;

  /// Resets the estimator state.
  void reset() {
    _biasZ = 0.0;
    _yawDeg = 0.0;
    _filteredYawDeg = 0.0;
    _stillTimeSec = 0.0;
    _hasAccel = false;
    _accelX = _accelY = _accelZ = 0;
  }

  /// One-time calibration: assume device is held still and centered.
  ///
  /// This resets yaw and also seeds the bias to the current z gyro rate.
  void calibrate({double? seedBiasZRadPerSec}) {
    _yawDeg = 0.0;
    _filteredYawDeg = 0.0;
    _stillTimeSec = 0.0;
    if (seedBiasZRadPerSec != null) {
      _biasZ = seedBiasZRadPerSec;
    }
  }

  void updateAccel({required double x, required double y, required double z}) {
    _accelX = x;
    _accelY = y;
    _accelZ = z;
    _hasAccel = true;
  }

  /// Update with gyro z-rate (rad/s) and dt (seconds).
  ///
  /// Returns the current filtered steering angle in degrees.
  double updateGyro({required double wz, required double dt}) {
    if (dt <= 0) {
      return angleDeg;
    }

    // If dt spikes (app paused/jank), cap it instead of bailing out.
    // This keeps the estimator responsive and avoids "stuck" output.
    final usedDt = dt > maxDtSec ? maxDtSec : dt;

    final still = _isStill(wz);
    if (still) {
      _stillTimeSec += usedDt;

      // Learn gyro bias only when we're still AND near our calibrated center.
      // Otherwise, if the user holds a steady steering angle, wz≈0 and we'd
      // incorrectly move bias towards 0 and cause the angle to be wrong when
      // they return to center.
      final nearCenter = _yawDeg.abs() <= biasLearningDeadbandDeg;
      if (nearCenter && _stillTimeSec >= minStillTimeForBiasSec) {
        // Exponential moving average towards the observed rate.
        _biasZ = (1.0 - biasLearningRate) * _biasZ + biasLearningRate * wz;
      }

      // IMPORTANT: only auto-recenter when we're already close to center.
      // Users may hold a constant steering angle for several seconds.
      final canRecenter = _stillTimeSec >= minStillTimeForRecenterSec && _yawDeg.abs() <= recenterDeadbandDeg;
      if (canRecenter) {
        _applyRecenter(usedDt);
      }
    } else {
      _stillTimeSec = 0.0;
    }

    final correctedWz = wz - _biasZ;
    _yawDeg += correctedWz * usedDt * (180.0 / pi);

    // Clamp to avoid runaway if something goes wrong.
    _yawDeg = _yawDeg.clamp(-maxAngleAbsDeg, maxAngleAbsDeg).toDouble();

    // Low-pass filter for noise smoothing.
    //
    // Make it adaptive: when the angle is changing fast, we reduce smoothing
    // (more responsive). When stable, we keep stronger smoothing.
    //
    // If user forces lowPassAlpha=0.0 (existing tests do), we keep behavior
    // equivalent (no filtering).
    if (lowPassAlpha <= 0.0) {
      _filteredYawDeg = _yawDeg;
    } else {
      final stableAlpha = ((lowPassAlphaStable.isFinite ? lowPassAlphaStable : lowPassAlpha)).clamp(0.0, 0.999);
      final movingAlpha = lowPassAlphaMoving.clamp(0.0, stableAlpha);

      // Use a rate estimate derived from the filtered-vs-raw divergence.
      final rateDegPerSec = ((_yawDeg - _filteredYawDeg).abs()) / usedDt;
      final t = (rateDegPerSec / motionAngleRateDegPerSecForMinAlpha).clamp(0.0, 1.0);

      final alpha = stableAlpha + (movingAlpha - stableAlpha) * t;
      _filteredYawDeg = alpha * _filteredYawDeg + (1 - alpha) * _yawDeg;
    }

    return angleDeg;
  }

  double get angleDeg => _filteredYawDeg;

  double get biasZRadPerSec => _biasZ;

  double get stillTimeSec => _stillTimeSec;

  bool _isStill(double wz) {
    // If we don't have accel yet, be conservative: don't learn bias.
    if (!_hasAccel) return false;

    final gyroOk = wz.abs() < gyroStillThresholdRadPerSec;

    // Check accel magnitude close to gravity (device not being bumped).
    final aMag = sqrt(_accelX * _accelX + _accelY * _accelY + _accelZ * _accelZ);
    const g = 9.80665;
    final accelOk = (aMag - g).abs() < accelStillThresholdMS2;

    return gyroOk && accelOk;
  }

  void _applyRecenter(double dt) {
    // Exponential decay towards 0 with given half-life.
    // decay = 0.5^(dt/halfLife)
    if (recenterHalfLifeSec <= 0) return;
    final decay = pow(0.5, dt / recenterHalfLifeSec).toDouble();
    _yawDeg *= decay;
  }
}
