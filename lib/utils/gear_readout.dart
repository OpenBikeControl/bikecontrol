/// Formats the compact gear readout shown in the proxy card, desktop overlay,
/// PiP, and live-gear surfaces.
///
/// Without front shift it's the familiar rear `gear/total` (e.g. `14/25`).
/// With the virtual front derailleur on, it switches to head-unit-style
/// position notation `front×rear` — small ring is position 1, large ring is
/// position 2 (e.g. `2×14`), matching how Garmin/Wahoo show Di2/AXS gearing.
/// [withTotal] false drops the total (`14`), for surfaces that label it.
String formatGearReadout({
  required int currentGear,
  required int maxGear,
  required bool frontShiftEnabled,
  required bool largeRing,
  bool withTotal = true,
}) {
  if (!frontShiftEnabled) return withTotal ? '$currentGear/$maxGear' : '$currentGear';
  return '${largeRing ? 2 : 1}×$currentGear';
}

/// A gear ratio the way Ride and the overlay show it: "×2.4" — two decimals,
/// a trailing zero dropped.
String formatGearRatio(double ratio) {
  var text = ratio.toStringAsFixed(2);
  if (text.endsWith('0')) text = text.substring(0, text.length - 1);
  return '×$text';
}
