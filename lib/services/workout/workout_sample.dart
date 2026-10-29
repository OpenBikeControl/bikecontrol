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

  /// The virtual rear gear BikeControl had the trainer in; null without
  /// virtual shifting.
  final int? gear;

  /// The grade the trainer app had the trainer on, in %; null where it sent
  /// none (ERG, or a trainer BikeControl doesn't simulate for).
  final double? gradePct;

  const WorkoutSample({
    required this.timestamp,
    this.powerW,
    this.cadenceRpm,
    this.speedKph,
    this.heartRateBpm,
    this.heartRateFromHealth = false,
    this.gear,
    this.gradePct,
  });
}
