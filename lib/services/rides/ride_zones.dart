/// Coggan's seven power zones, by percent of FTP.
enum PowerZone {
  activeRecovery(55),
  endurance(75),
  tempo(90),
  threshold(105),
  vo2max(120),
  anaerobic(150),
  neuromuscular(null);

  const PowerZone(this.upToPercent);

  /// The zone's top edge (inclusive), in whole percent; null for the last.
  final int? upToPercent;
}

/// Five heart rate zones, by percent of max heart rate, from 50 %.
enum HeartRateZone {
  veryLight(60),
  light(70),
  moderate(80),
  hard(90),
  maximum(null);

  const HeartRateZone(this.upToPercent);

  /// The zone's top edge (inclusive), in whole percent; null for the last.
  final int? upToPercent;
}

/// Below this percent of max heart rate a second is in no zone.
const heartRateZoneFloorPercent = 50;

/// Seconds in each [PowerZone], from seconds ridden at each watt (see
/// `RideChart.powerSeconds`). A value sits in the zone whose edge its
/// rounded percent of [ftpWatts] does not pass: at FTP 200, 110 W (55 %)
/// is Active Recovery and 111 W (55.5 → 56 %) Endurance.
List<int> powerZoneSeconds(Map<int, int> secondsAtWatts, {required int ftpWatts}) =>
    _zoneSeconds(secondsAtWatts, ftpWatts, [for (final z in PowerZone.values) z.upToPercent]);

/// Seconds in each [HeartRateZone], from seconds ridden at each bpm (see
/// `RideChart.heartRateSeconds`); time under 50 % of max is left out.
List<int> heartRateZoneSeconds(Map<int, int> secondsAtBpm, {required int maxHeartRateBpm}) => _zoneSeconds(
  secondsAtBpm,
  maxHeartRateBpm,
  [for (final z in HeartRateZone.values) z.upToPercent],
  floorPercent: heartRateZoneFloorPercent,
);

List<int> _zoneSeconds(Map<int, int> secondsAt, int reference, List<int?> edges, {int? floorPercent}) {
  final out = List<int>.filled(edges.length, 0);
  if (reference <= 0) return out;
  for (final MapEntry(key: value, value: seconds) in secondsAt.entries) {
    final percent = (value * 100 / reference).round();
    if (floorPercent != null && percent < floorPercent) continue;
    var zone = edges.indexWhere((edge) => edge == null || percent <= edge);
    if (zone < 0) zone = edges.length - 1;
    out[zone] += seconds;
  }
  return out;
}
