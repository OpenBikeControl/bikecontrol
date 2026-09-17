/// One 1 Hz record of trainer telemetry. Fields are nullable because the
/// trainer may not report all metrics (e.g. no HR strap paired).
class WorkoutSample {
  final DateTime timestamp;
  final int? powerW;
  final int? cadenceRpm;
  final double? speedKph;
  final int? heartRateBpm;

  /// Whether [heartRateBpm] was read from Apple Health. Such samples must not
  /// be written back to Health with the ride — they are already there.
  final bool heartRateFromHealth;

  const WorkoutSample({
    required this.timestamp,
    this.powerW,
    this.cadenceRpm,
    this.speedKph,
    this.heartRateBpm,
    this.heartRateFromHealth = false,
  });
}
