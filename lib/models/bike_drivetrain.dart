import 'package:bike_control/models/shifting_config.dart';
import 'package:flutter/foundation.dart' show listEquals;

/// The rider's real crank and cassette, which the "Like my bike" gear preset
/// turns into virtual gears.
///
/// The gear ratios are absolute (chainring / cog), the same units as the stock
/// curve: FitnessBikeDefinition derives the virtual speed from cadence × wheel
/// × ratio and compares it with the real chain at the trainer
/// ([ShiftingConfig.realChainRatio]), so the teeth go in unconverted.
class BikeDrivetrain {
  static const int cogTeethMin = 9;
  static const int cogTeethMax = 52;

  /// One ring (1×) or two (2×), largest first.
  final List<int> chainrings;

  /// Smallest first, no duplicates.
  final List<int> cogs;

  const BikeDrivetrain._(this.chainrings, this.cogs);

  /// A drivetrain from [rings] and [cogs] in any order, or null when it is not
  /// one BikeControl can ride: 1–2 different rings of 20–60 teeth, and 1–30
  /// different cogs of 9–52 teeth (one gear per cog).
  static BikeDrivetrain? tryCreate(List<int> rings, List<int> cogs) {
    if (rings.isEmpty || rings.length > 2) return null;
    if (rings.length == 2 && rings[0] == rings[1]) return null;
    if (rings.any((t) => t < ShiftingConfig.chainringTeethMin || t > ShiftingConfig.chainringTeethMax)) return null;
    final sortedCogs = cogs.toSet().toList()..sort();
    if (sortedCogs.length != cogs.length) return null;
    if (sortedCogs.length < ShiftingConfig.maxGearMin || sortedCogs.length > ShiftingConfig.maxGearMax) return null;
    if (sortedCogs.any((t) => t < cogTeethMin || t > cogTeethMax)) return null;
    final sortedRings = List<int>.of(rings)..sort((a, b) => b.compareTo(a));
    return BikeDrivetrain._(List.unmodifiable(sortedRings), List.unmodifiable(sortedCogs));
  }

  /// The cogs in "11-12-13…" or "11, 12, 13" form, sorted and without
  /// duplicates; null when the text holds anything but numbers.
  static List<int>? parseCogs(String input) {
    final parts = input.split(RegExp(r'[^0-9]+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    if (input.replaceAll(RegExp(r'[0-9\s,;/\-–—]'), '').isNotEmpty) return null;
    return (parts.map(int.parse).toSet().toList()..sort());
  }

  bool get isDouble => chainrings.length == 2;

  /// The ring [ratios] are computed on: the small ring of a 2×, which
  /// FitnessBikeDefinition multiplies by large / small on the big ring.
  int get baseRing => chainrings.last;

  /// One ratio per cog, easiest (largest cog) first.
  List<double> get ratios => [for (final cog in cogs.reversed) baseRing / cog];

  /// Writes the gears into [config]: one gear per cog, and for a 2× the
  /// virtual front derailleur on these two rings. A 1× switches it off and
  /// leaves its rings as they were.
  ShiftingConfig applyTo(ShiftingConfig config) => config.copyWith(
        maxGear: cogs.length,
        gearRatios: ratios,
        frontShiftEnabled: isDouble,
        smallChainringTeeth: isDouble ? chainrings.last : null,
        largeChainringTeeth: isDouble ? chainrings.first : null,
        bikeDrivetrain: this,
      );

  /// Whether [current] is still the curve this drivetrain made.
  bool matches(List<double> current, {double tol = 0.001}) {
    final own = ratios;
    if (own.length != current.length) return false;
    for (var i = 0; i < own.length; i++) {
      if ((own[i] - current[i]).abs() > tol) return false;
    }
    return true;
  }

  /// "50/34" or "42".
  String get chainringLabel => chainrings.join('/');

  /// "11-34".
  String get cassetteRangeLabel => cogs.length == 1 ? '${cogs.first}' : '${cogs.first}-${cogs.last}';

  Map<String, dynamic> toJson() => {'chainrings': chainrings, 'cogs': cogs};

  static BikeDrivetrain? fromJson(Object? json) {
    if (json is! Map) return null;
    final rings = json['chainrings'];
    final cogs = json['cogs'];
    if (rings is! List || cogs is! List) return null;
    if (rings.any((e) => e is! num) || cogs.any((e) => e is! num)) return null;
    return tryCreate([for (final r in rings) (r as num).toInt()], [for (final c in cogs) (c as num).toInt()]);
  }

  @override
  bool operator ==(Object other) =>
      other is BikeDrivetrain && listEquals(chainrings, other.chainrings) && listEquals(cogs, other.cogs);

  @override
  int get hashCode => Object.hash(Object.hashAll(chainrings), Object.hashAll(cogs));

  @override
  String toString() => 'BikeDrivetrain($chainringLabel, ${cogs.join('-')})';
}
