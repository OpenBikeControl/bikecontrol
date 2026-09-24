//INFO: This is a stub - contact me if you need the full implementation.
//
// The full implementation parses and encodes the Bluetooth SIG Cycling Speed
// and Cadence Measurement characteristic and derives cadence / speed from two
// consecutive samples. This stub keeps the public shape only.

/// A parsed Cycling Speed and Cadence (CSC) Measurement notification.
class CscMeasurement {
  final int? cumWheelRevs;
  final int? lastWheelEventTime1024s;
  final int? cumCrankRevs;
  final int? lastCrankEventTime1024s;

  const CscMeasurement({
    this.cumWheelRevs,
    this.lastWheelEventTime1024s,
    this.cumCrankRevs,
    this.lastCrankEventTime1024s,
  });

  static CscMeasurement? parse(List<int> bytes) => null;
}

/// Cadence in RPM derived from two consecutive CSC samples.
int? cscCadenceRpm(CscMeasurement prev, CscMeasurement cur) => null;

/// Bike speed in m/s derived from two consecutive CSC samples.
double? cscSpeedMps(
  CscMeasurement prev,
  CscMeasurement cur, {
  required double wheelCircumferenceMeters,
}) =>
    null;

/// Advances a cumulative crank-revolution counter and its paired event-time
/// clock by [rpm] revolutions over one fixed quantum.
({int crankRevs, int eventTime1024}) advanceCrankCounter({
  required int crankRevs,
  required int eventTime1024,
  required int rpm,
}) =>
    (crankRevs: crankRevs, eventTime1024: eventTime1024);

/// Encodes a crank-only CSC Measurement frame.
List<int> buildCscMeasurement(int crankRevs, int eventTime1024) => const [];
