import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

enum OverlayField {
  power,
  cadence,
  ergTarget,
  gearRatio;

  static OverlayField? fromName(String name) {
    for (final f in values) {
      if (f.name == name) return f;
    }
    return null;
  }
}

/// Snapshot of everything the overlay needs to render. Immutable; comparable
/// via `==` so debouncers can drop unchanged ticks.
class OverlayState {
  final int gear;
  final int maxGear;
  final double gearRatio;
  final TrainerMode mode;
  final int? powerW;
  final int? cadenceRpm;
  final int? ergTargetW;
  final Set<OverlayField> fields;

  const OverlayState({
    required this.gear,
    required this.maxGear,
    required this.gearRatio,
    required this.mode,
    required this.powerW,
    required this.cadenceRpm,
    required this.ergTargetW,
    required this.fields,
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
      };

  factory OverlayState.fromJson(Map<String, dynamic> json) {
    final modeName = json['mode'] as String;
    final mode = TrainerMode.values.firstWhere(
      (m) => m.name == modeName,
      orElse: () => TrainerMode.simMode,
    );
    final fields = (json['fields'] as List)
        .map((e) => OverlayField.fromName(e as String))
        .whereType<OverlayField>()
        .toSet();
    return OverlayState(
      gear: json['gear'] as int,
      maxGear: json['maxGear'] as int,
      gearRatio: (json['gearRatio'] as num).toDouble(),
      mode: mode,
      powerW: json['powerW'] as int?,
      cadenceRpm: json['cadenceRpm'] as int?,
      ergTargetW: json['ergTargetW'] as int?,
      fields: fields,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OverlayState &&
        other.gear == gear &&
        other.maxGear == maxGear &&
        other.gearRatio == gearRatio &&
        other.mode == mode &&
        other.powerW == powerW &&
        other.cadenceRpm == cadenceRpm &&
        other.ergTargetW == ergTargetW &&
        _setEquals(other.fields, fields);
  }

  @override
  int get hashCode => Object.hash(
        gear, maxGear, gearRatio, mode, powerW, cadenceRpm, ergTargetW,
        Object.hashAllUnordered(fields),
      );

  static bool _setEquals(Set<OverlayField> a, Set<OverlayField> b) {
    if (a.length != b.length) return false;
    for (final v in a) {
      if (!b.contains(v)) return false;
    }
    return true;
  }
}
