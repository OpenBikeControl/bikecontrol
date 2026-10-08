import 'dart:math';

/// Pure-Dart steering estimator for a phone on the handlebar.
///
/// The handlebar turns about the world's up axis, not about the phone's z
/// axis — a mount tilts the phone towards the rider. So the gyroscope's
/// rotation rate is projected onto the up axis the accelerometer reports, and
/// that is what gets integrated. The gyro's bias is learned while the bars are
/// still and near centre, and seeded from the whole still window when the
/// rider calibrates.
///
/// Optionally the magnetometer takes the integration's slow drift out. Raw
/// phone magnetometers carry a large constant offset from the phone's own and
/// the mount's magnets, which makes the plain compass heading useless (both
/// turn directions can read as the same). Instead, while the bars turn, the
/// horizontal field is fitted against the gyro angle as a circle — centre
/// (the offset) plus a rotating Earth vector. Once the fit holds, the angle on
/// that circle is a drift-free yaw, and a slow PI loop pulls the integrated
/// angle and the gyro bias towards it.
///
/// No Flutter or sensor dependencies: the device feeds it samples.
class SteeringEstimator {
  SteeringEstimator({
    this.biasLearningRate = 0.02,
    this.gyroStillThresholdRadPerSec = 0.04,
    this.accelStillThresholdMS2 = 0.8,
    this.minStillTimeForBiasSec = 0.35,
    this.biasLearningDeadbandDeg = 3.0,
    this.maxAngleAbsDeg = 60,
    this.maxDtSec = 0.5,
    this.gravityAlpha = 0.05,
    this.outputTimeConstantSec = 0.06,
    this.magProportionalGainPerSec = 0.5,
    this.magIntegralGainPerSec2 = 0.05,
    this.magSampleSpacingDeg = 1.0,
    this.magMemorySamples = 400,
    this.magMinSamples = 40,
    this.magMaxResultant = 0.985,
    this.magMinFieldMicroTesla = 3.0,
    this.magMaxInnovationDeg = 30.0,
  });

  /// Exponential moving-average rate for the gyro bias while still at centre.
  final double biasLearningRate;

  /// Bias-corrected rotation rate below which the phone counts as still.
  final double gyroStillThresholdRadPerSec;

  /// Deviation of the acceleration's magnitude from gravity that still counts
  /// as still.
  final double accelStillThresholdMS2;

  /// Stillness needed before the bias learner runs.
  final double minStillTimeForBiasSec;

  /// The bias is only learned this close to centre: a held angle reads a zero
  /// rate too, and must not pull the bias.
  final double biasLearningDeadbandDeg;

  /// Clamp on the integrated angle.
  final double maxAngleAbsDeg;

  /// Longer steps (the app was paused) integrate as this long.
  final double maxDtSec;

  /// Per-sample low-pass of the accelerometer into the gravity estimate.
  final double gravityAlpha;

  /// Low-pass on the reported angle, seconds.
  final double outputTimeConstantSec;

  /// Compass correction: proportional pull on the angle, 1/s.
  final double magProportionalGainPerSec;

  /// Compass correction: how fast the loop learns the remaining bias, 1/s².
  final double magIntegralGainPerSec2;

  /// A compass sample only enters the fit once the bars moved this far since
  /// the last one, so holding still never floods the fit's memory.
  final double magSampleSpacingDeg;

  /// Fit memory, in such samples (exponential half-life).
  final int magMemorySamples;

  /// Samples the fit needs before it can lock.
  final int magMinSamples;

  /// Mean resultant length of the sampled angles above which the sweep seen
  /// is too narrow to separate the offset from the Earth's field.
  final double magMaxResultant;

  /// Horizontal field the fit must find, microtesla; below this it is noise.
  final double magMinFieldMicroTesla;

  /// Clamp on each compass-vs-gyro disagreement applied per step.
  final double magMaxInnovationDeg;

  // Gravity (sensors_plus convention: the reaction, pointing up at rest).
  double _gx = 0, _gy = 0, _gz = 0;
  bool _hasGravity = false;
  double _lastAccelMagnitude = 0;

  // The up axis the yaw rate is projected onto: live gravity until the rider
  // calibrates, frozen then.
  double _ax = 0, _ay = 0, _az = 1;
  bool _calibrated = false;

  // Gyro bias, rad/s, 3 axes.
  double _bx = 0, _by = 0, _bz = 0;

  // Raw gyro summed over the current still window, to seed the bias.
  double _stillSumX = 0, _stillSumY = 0, _stillSumZ = 0;
  int _stillCount = 0;
  double _stillTimeSec = 0;

  double _yawDeg = 0;
  double _outDeg = 0;

  // Magnetometer: horizontal basis (u, v) ⊥ the frozen up axis.
  double _ux = 1, _uy = 0, _uz = 0, _vx = 0, _vy = 1, _vz = 0;
  // Normal equations of the circle fit, unknowns (cx, cy, ex, ey).
  final List<double> _n = List.filled(16, 0);
  final List<double> _r = List.filled(4, 0);
  double _sumW = 0, _sumWCos = 0, _sumWSin = 0, _sumMM = 0;
  int _magAdded = 0;
  double? _lastAddedYawDeg;
  double _cx = 0, _cy = 0, _ex = 0, _ey = 0;
  bool _magLocked = false;
  double? _magYawDeg;
  double _magBiasDegPerSec = 0;

  /// Reported angle, degrees, positive ⇒ left.
  double get angleDeg => _outDeg;

  /// The integrated angle before the output filter.
  double get rawAngleDeg => _yawDeg;

  /// How long the phone has been still, seconds.
  double get stillTimeSec => _stillTimeSec;

  /// Learned bias about the up axis, rad/s.
  double get yawBiasRadPerSec => _bx * _ax + _by * _ay + _bz * _az + _magBiasDegPerSec * pi / 180;

  /// True once the compass has learned the mount and corrects drift.
  bool get magnetometerLocked => _magLocked;

  /// Resets everything, bias included.
  void reset() {
    _hasGravity = false;
    _gx = _gy = _gz = 0;
    _lastAccelMagnitude = 0;
    _ax = 0;
    _ay = 0;
    _az = 1;
    _calibrated = false;
    _bx = _by = _bz = 0;
    _resetStillWindow();
    _stillTimeSec = 0;
    _yawDeg = 0;
    _outDeg = 0;
    _resetMag();
  }

  /// Marks the bars as straight now: zeroes the angle, seeds the bias from
  /// the still window, freezes the up axis and forgets the compass model.
  void calibrate() {
    if (_stillCount > 0) {
      _bx = _stillSumX / _stillCount;
      _by = _stillSumY / _stillCount;
      _bz = _stillSumZ / _stillCount;
    }
    _resetStillWindow();
    _stillTimeSec = 0;
    _yawDeg = 0;
    _outDeg = 0;
    if (_hasGravity) {
      final m = sqrt(_gx * _gx + _gy * _gy + _gz * _gz);
      if (m > 0) {
        _ax = _gx / m;
        _ay = _gy / m;
        _az = _gz / m;
      }
    }
    _calibrated = true;
    _resetMag();
    _buildMagBasis();
  }

  void updateAccel({required double x, required double y, required double z}) {
    _lastAccelMagnitude = sqrt(x * x + y * y + z * z);
    if (!_hasGravity) {
      _gx = x;
      _gy = y;
      _gz = z;
      _hasGravity = true;
    } else {
      _gx += gravityAlpha * (x - _gx);
      _gy += gravityAlpha * (y - _gy);
      _gz += gravityAlpha * (z - _gz);
    }
    if (!_calibrated) {
      final m = sqrt(_gx * _gx + _gy * _gy + _gz * _gz);
      if (m > 0) {
        _ax = _gx / m;
        _ay = _gy / m;
        _az = _gz / m;
      }
    }
  }

  /// Gyroscope sample, rad/s, and the time since the previous one. Returns
  /// the reported angle.
  double updateGyro({required double x, required double y, required double z, required double dt}) {
    if (dt <= 0 || !_hasGravity) return _outDeg;
    final usedDt = dt > maxDtSec ? maxDtSec : dt;

    final cx = x - _bx, cy = y - _by, cz = z - _bz;
    if (_isStill(cx, cy, cz)) {
      _stillTimeSec += usedDt;
      _stillSumX += x;
      _stillSumY += y;
      _stillSumZ += z;
      _stillCount++;
      final nearCentre = _yawDeg.abs() <= biasLearningDeadbandDeg;
      if (nearCentre && _stillTimeSec >= minStillTimeForBiasSec) {
        _bx += biasLearningRate * (x - _bx);
        _by += biasLearningRate * (y - _by);
        _bz += biasLearningRate * (z - _bz);
      }
    } else {
      _stillTimeSec = 0;
      _resetStillWindow();
    }

    final rateDegPerSec = (cx * _ax + cy * _ay + cz * _az) * (180 / pi) - _magBiasDegPerSec;
    _yawDeg += rateDegPerSec * usedDt;

    final magYaw = _magYawDeg;
    if (_magLocked && magYaw != null) {
      var innovation = _wrapDeg(magYaw - _yawDeg);
      innovation = innovation.clamp(-magMaxInnovationDeg, magMaxInnovationDeg);
      _yawDeg += magProportionalGainPerSec * innovation * usedDt;
      _magBiasDegPerSec -= magIntegralGainPerSec2 * innovation * usedDt;
    }

    _yawDeg = _yawDeg.clamp(-maxAngleAbsDeg, maxAngleAbsDeg);

    final a = outputTimeConstantSec <= 0 ? 0.0 : exp(-usedDt / outputTimeConstantSec);
    _outDeg = a * _outDeg + (1 - a) * _yawDeg;
    return _outDeg;
  }

  /// Magnetometer sample, microtesla in the phone's frame.
  void updateMag({required double x, required double y, required double z}) {
    if (!_calibrated) return;
    final hx = x * _ux + y * _uy + z * _uz;
    final hy = x * _vx + y * _vy + z * _vz;

    final last = _lastAddedYawDeg;
    if (last == null || (_yawDeg - last).abs() >= magSampleSpacingDeg) {
      _addMagSample(hx, hy, _yawDeg * pi / 180);
      _lastAddedYawDeg = _yawDeg;
      if (_magAdded % 10 == 0) _solveMag();
    }

    if (_magLocked) {
      final dx = hx - _cx, dy = hy - _cy;
      // The Earth's field turns the other way than the phone.
      _magYawDeg = -atan2(_ex * dy - _ey * dx, _ex * dx + _ey * dy) * (180 / pi);
    }
  }

  bool _isStill(double wx, double wy, double wz) {
    final gyroOk = sqrt(wx * wx + wy * wy + wz * wz) < gyroStillThresholdRadPerSec;
    const g = 9.80665;
    final accelOk = (_lastAccelMagnitude - g).abs() < accelStillThresholdMS2;
    return gyroOk && accelOk;
  }

  void _resetStillWindow() {
    _stillSumX = _stillSumY = _stillSumZ = 0;
    _stillCount = 0;
  }

  static double _wrapDeg(double d) {
    var w = d % 360;
    if (w > 180) w -= 360;
    return w;
  }

  // ---- magnetometer fit -------------------------------------------------

  void _resetMag() {
    for (var i = 0; i < 16; i++) {
      _n[i] = 0;
    }
    for (var i = 0; i < 4; i++) {
      _r[i] = 0;
    }
    _sumW = _sumWCos = _sumWSin = _sumMM = 0;
    _magAdded = 0;
    _lastAddedYawDeg = null;
    _magLocked = false;
    _magYawDeg = null;
    _magBiasDegPerSec = 0;
  }

  /// Two unit vectors spanning the plane perpendicular to the up axis.
  void _buildMagBasis() {
    // Start from whichever phone axis is least aligned with up.
    double sx, sy, sz;
    if (_ax.abs() < 0.9) {
      sx = 1;
      sy = 0;
      sz = 0;
    } else {
      sx = 0;
      sy = 1;
      sz = 0;
    }
    final d = sx * _ax + sy * _ay + sz * _az;
    var ux = sx - d * _ax, uy = sy - d * _ay, uz = sz - d * _az;
    final m = sqrt(ux * ux + uy * uy + uz * uz);
    ux /= m;
    uy /= m;
    uz /= m;
    _ux = ux;
    _uy = uy;
    _uz = uz;
    // v = up × u
    _vx = _ay * uz - _az * uy;
    _vy = _az * ux - _ax * uz;
    _vz = _ax * uy - _ay * ux;
  }

  /// Model: h(θ) = c + Rot(−θ)·e, i.e.
  ///   hx = cx + ex·cosθ + ey·sinθ
  ///   hy = cy − ex·sinθ + ey·cosθ
  /// Linear in (cx, cy, ex, ey); accumulated as weighted normal equations.
  void _addMagSample(double hx, double hy, double theta) {
    final lambda = pow(0.5, 1 / magMemorySamples).toDouble();
    for (var i = 0; i < 16; i++) {
      _n[i] *= lambda;
    }
    for (var i = 0; i < 4; i++) {
      _r[i] *= lambda;
    }
    _sumW *= lambda;
    _sumWCos *= lambda;
    _sumWSin *= lambda;
    _sumMM *= lambda;

    final c = cos(theta), s = sin(theta);
    final a = [1.0, 0.0, c, s];
    final b = [0.0, 1.0, -s, c];
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 4; j++) {
        _n[i * 4 + j] += a[i] * a[j] + b[i] * b[j];
      }
      _r[i] += a[i] * hx + b[i] * hy;
    }
    _sumW += 1;
    _sumWCos += c;
    _sumWSin += s;
    _sumMM += hx * hx + hy * hy;
    _magAdded++;
  }

  void _solveMag() {
    if (_sumW < magMinSamples) {
      _magLocked = false;
      return;
    }
    final resultant = sqrt(_sumWCos * _sumWCos + _sumWSin * _sumWSin) / _sumW;
    if (resultant > magMaxResultant) {
      _magLocked = false;
      return;
    }
    final p = _solve4(_n, _r);
    if (p == null) {
      _magLocked = false;
      return;
    }
    final field = sqrt(p[2] * p[2] + p[3] * p[3]);
    if (field < magMinFieldMicroTesla) {
      _magLocked = false;
      return;
    }
    // Residual sum of squares: Σ|h|² − 2 pᵀr + pᵀNp.
    var pr = 0.0, pnp = 0.0;
    for (var i = 0; i < 4; i++) {
      pr += p[i] * _r[i];
      var row = 0.0;
      for (var j = 0; j < 4; j++) {
        row += _n[i * 4 + j] * p[j];
      }
      pnp += p[i] * row;
    }
    final rss = _sumMM - 2 * pr + pnp;
    final rms = sqrt(max(0.0, rss) / _sumW);
    if (rms > 0.5 * field) {
      _magLocked = false;
      return;
    }
    _cx = p[0];
    _cy = p[1];
    _ex = p[2];
    _ey = p[3];
    _magLocked = true;
  }

  /// Gaussian elimination with partial pivoting for a 4×4 system.
  static List<double>? _solve4(List<double> n, List<double> r) {
    final m = List<double>.generate(20, (i) => i % 5 == 4 ? r[i ~/ 5] : n[(i ~/ 5) * 4 + i % 5]);
    for (var col = 0; col < 4; col++) {
      var pivot = col;
      for (var row = col + 1; row < 4; row++) {
        if (m[row * 5 + col].abs() > m[pivot * 5 + col].abs()) pivot = row;
      }
      if (m[pivot * 5 + col].abs() < 1e-9) return null;
      if (pivot != col) {
        for (var k = 0; k < 5; k++) {
          final t = m[col * 5 + k];
          m[col * 5 + k] = m[pivot * 5 + k];
          m[pivot * 5 + k] = t;
        }
      }
      for (var row = col + 1; row < 4; row++) {
        final f = m[row * 5 + col] / m[col * 5 + col];
        for (var k = col; k < 5; k++) {
          m[row * 5 + k] -= f * m[col * 5 + k];
        }
      }
    }
    final p = List<double>.filled(4, 0);
    for (var row = 3; row >= 0; row--) {
      var s = m[row * 5 + 4];
      for (var k = row + 1; k < 4; k++) {
        s -= m[row * 5 + k] * p[k];
      }
      p[row] = s / m[row * 5 + row];
    }
    return p;
  }
}
