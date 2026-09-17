/// One sample from a [SensorSource].
///
/// The timestamp is part of the value, not metadata: the hub's staleness
/// policy is the only thing standing between a dead sensor and a frozen
/// number on the rider's screen.
class SensorReading {
  const SensorReading(this.value, this.timestamp);

  final int value;
  final DateTime timestamp;
}
