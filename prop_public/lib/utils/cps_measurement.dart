//INFO: This is a stub - contact me if you need the full implementation.
//
// The full implementation parses and encodes the Bluetooth SIG Cycling Power
// Measurement characteristic and derives cadence from two consecutive
// samples. This stub keeps the public shape only.

/// A parsed Cycling Power Measurement notification.
class CpsMeasurement {
  final int powerWatts;
  final int? cumCrankRevs;
  final int? lastCrankEventTime1024s;
  final int? cumWheelRevs;
  final int? lastWheelEventTime2048s;

  const CpsMeasurement({
    required this.powerWatts,
    this.cumCrankRevs,
    this.lastCrankEventTime1024s,
    this.cumWheelRevs,
    this.lastWheelEventTime2048s,
  });

  static CpsMeasurement? parse(List<int> bytes) => null;
}

/// Cadence in RPM derived from two consecutive Cycling Power samples.
int? cpsCadenceRpm(CpsMeasurement prev, CpsMeasurement cur) => null;

/// Encodes a Cycling Power Measurement frame.
List<int> buildCyclingPowerMeasurement(
  int watts, {
  int? crankRevs,
  int? eventTime1024,
}) =>
    const [];
