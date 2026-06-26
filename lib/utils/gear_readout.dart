/// Formats the compact gear readout shown in the proxy card, desktop overlay,
/// PiP, and live-gear surfaces.
///
/// Without front shift it's the familiar rear `gear/total` (e.g. `14/25`).
/// With the virtual front derailleur on, it switches to head-unit-style
/// position notation `front×rear` — small ring is position 1, large ring is
/// position 2 (e.g. `2×14`), matching how Garmin/Wahoo show Di2/AXS gearing.
String formatGearReadout({
  required int currentGear,
  required int maxGear,
  required bool frontShiftEnabled,
  required bool largeRing,
}) {
  if (!frontShiftEnabled) return '$currentGear/$maxGear';
  return '${largeRing ? 2 : 1}×$currentGear';
}
