import 'dart:math' as math;

/// The speed a rider's power would carry them at on a road: the drive force
/// from the pedals against rolling resistance, gravity on the grade and air
/// drag, stepped forward in time. Cadence and gears play no part; on a
/// smart trainer they decide how the power is made, not how fast the ride is.
class PowerSpeedModel {
  static const double gravity = 9.81;
  static const double airDensity = 1.226;

  /// Effective drag area (CdA) of rider and bike, m².
  static const double dragArea = 0.71;
  static const double rollingResistance = 0.00538;
  static const double drivetrainLoss = 0.025;

  /// Longest gap still counted as riding; a longer one is a pause.
  static const double _maxGapSeconds = 2.0;

  /// Below this speed the drive force is capped as if the bike were rolling
  /// at it, so pushing off from standstill stays finite.
  static const double _minDriveSpeed = 1.0;

  double _speed = 0; // m/s

  double get speedKph => _speed * 3.6;

  void reset() => _speed = 0;

  /// Advances the bike by [seconds] at [powerW] on [gradePct] with rider and
  /// bike weighing [massKg] together, and returns the new speed in km/h.
  double step({required double powerW, required double gradePct, required double massKg, required double seconds}) {
    final mass = math.max(massKg, 1.0);
    final theta = math.atan(gradePct / 100);
    final rolling = rollingResistance * mass * gravity * math.cos(theta);
    final climbing = mass * gravity * math.sin(theta);
    final power = math.max(powerW, 0.0) * (1 - drivetrainLoss);
    var remaining = math.min(seconds, _maxGapSeconds);
    while (remaining > 0) {
      final dt = math.min(remaining, 1.0);
      final drive = power / math.max(_speed, _minDriveSpeed);
      final drag = 0.5 * airDensity * dragArea * _speed * _speed;
      _speed = math.max(0.0, _speed + (drive - rolling - climbing - drag) / mass * dt);
      remaining -= dt;
    }
    return speedKph;
  }
}
