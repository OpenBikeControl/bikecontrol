/// One 1 Hz record of trainer telemetry. Fields are nullable because the
/// trainer may not report all metrics (e.g. no HR strap paired).
class WorkoutSample {
  final DateTime timestamp;
  final int? powerW;
  final int? cadenceRpm;
  final double? speedKph;
  final int? heartRateBpm;

  const WorkoutSample({
    required this.timestamp,
    this.powerW,
    this.cadenceRpm,
    this.speedKph,
    this.heartRateBpm,
  });
}
