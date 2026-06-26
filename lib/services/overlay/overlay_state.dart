import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

enum OverlayField {
  power,
  cadence,
  ergTarget,
  gearRatio,
  // When enabled, the overlay renders − / + buttons either side of the big
  // primary value (gear in SIM, target watts in ERG). Default off.
  controls;

  static OverlayField? fromName(String name) {
    for (final f in values) {
      if (f.name == name) return f;
    }
    return null;
  }
}

/// Snapshot of everything the overlay needs to render. Immutable; comparable
/// via `==` so debouncers can drop unchanged ticks.
class TrainerOverlayState {
  final int gear;
  final int maxGear;
  final double gearRatio;
  final TrainerMode mode;
  final int? powerW;
  final int? cadenceRpm;
  final int? ergTargetW;
  final Set<OverlayField> fields;
  final bool frontShiftEnabled;
  final bool frontRingLarge;

  const TrainerOverlayState({
    required this.gear,
    required this.maxGear,
    required this.gearRatio,
    required this.mode,
    required this.powerW,
    required this.cadenceRpm,
    required this.ergTargetW,
    required this.fields,
    this.frontShiftEnabled = false,
    this.frontRingLarge = false,
  });

  Map<String, dynamic> toJson() => {
        'gear': gear,
        'maxGear': maxGear,
        'gearRatio': gearRatio,
        'mode': mode.name,
        'powerW': powerW,
        'cadenceRpm': cadenceRpm,
        'ergTargetW': ergTargetW,
        'fields': fields.map((f) => f.name).toList(),
        'frontShiftEnabled': frontShiftEnabled,
        'frontRingLarge': frontRingLarge,
      };

  /// Permissive parse — silently fills missing/wrong-typed fields with sane
  /// defaults so a malformed cross-isolate message can never crash the
  /// overlay (worst case: stale/empty card).
  factory TrainerOverlayState.fromJson(Map<String, dynamic> json) {
    final modeName = json['mode'];
    final mode = TrainerMode.values.firstWhere(
      (m) => m.name == modeName,
      orElse: () => TrainerMode.simMode,
    );
    final rawFields = json['fields'];
    final fields = rawFields is List
        ? rawFields
            .whereType<String>()
            .map(OverlayField.fromName)
            .whereType<OverlayField>()
            .toSet()
        : <OverlayField>{};
    return TrainerOverlayState(
      gear: (json['gear'] as num?)?.toInt() ?? 0,
      maxGear: (json['maxGear'] as num?)?.toInt() ?? 0,
      gearRatio: (json['gearRatio'] as num?)?.toDouble() ?? 1.0,
      mode: mode,
      powerW: (json['powerW'] as num?)?.toInt(),
      cadenceRpm: (json['cadenceRpm'] as num?)?.toInt(),
      ergTargetW: (json['ergTargetW'] as num?)?.toInt(),
      fields: fields,
      frontShiftEnabled: (json['frontShiftEnabled'] as bool?) ?? false,
      frontRingLarge: (json['frontRingLarge'] as bool?) ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TrainerOverlayState &&
        other.gear == gear &&
        other.maxGear == maxGear &&
        other.gearRatio == gearRatio &&
        other.mode == mode &&
        other.powerW == powerW &&
        other.cadenceRpm == cadenceRpm &&
        other.ergTargetW == ergTargetW &&
        other.frontShiftEnabled == frontShiftEnabled &&
        other.frontRingLarge == frontRingLarge &&
        _setEquals(other.fields, fields);
  }

  @override
  int get hashCode => Object.hash(
        gear, maxGear, gearRatio, mode, powerW, cadenceRpm, ergTargetW,
        Object.hashAllUnordered(fields), frontShiftEnabled, frontRingLarge,
      );

  static bool _setEquals(Set<OverlayField> a, Set<OverlayField> b) {
    if (a.length != b.length) return false;
    for (final v in a) {
      if (!b.contains(v)) return false;
    }
    return true;
  }
}

/// Serialize overlay state to the map shape consumed by the iOS Live Activity
/// (via the live_activities plugin's App Group UserDefaults) AND by the PiP
/// channel. Omits null optional metrics: the Live Activity path routes through
/// NSUserDefaults which crashes on null values, and Swift's optional `Int?`
/// fields decode missing keys as nil either way.
Map<String, dynamic> overlayStateToActivityMap(TrainerOverlayState s) {
  final m = <String, dynamic>{
    'gear': s.gear,
    'maxGear': s.maxGear,
    'mode': s.mode == TrainerMode.ergMode ? 'erg' : 'sim',
    'showPower': s.fields.contains(OverlayField.power),
    'showCadence': s.fields.contains(OverlayField.cadence),
    'showErgTarget': s.fields.contains(OverlayField.ergTarget),
    'showGearRatio': s.fields.contains(OverlayField.gearRatio),
    'showControls': s.fields.contains(OverlayField.controls),
    'gearRatio': s.gearRatio,
    'frontShiftEnabled': s.frontShiftEnabled,
    'frontRingLarge': s.frontRingLarge,
  };
  if (s.powerW != null) m['powerW'] = s.powerW;
  if (s.cadenceRpm != null) m['cadenceRpm'] = s.cadenceRpm;
  if (s.ergTargetW != null) m['ergTargetW'] = s.ergTargetW;
  return m;
}
