import 'package:flutter/foundation.dart' show listEquals;
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

class ShiftingConfig {
  static const double bikeWeightDefaultKg = 10.0;
  static const double bikeWeightMinKg = 1.0;
  static const double bikeWeightMaxKg = 50.0;
  static const double riderWeightDefaultKg = 75.0;
  static const double riderWeightMinKg = 20.0;
  static const double riderWeightMaxKg = 200.0;
  static const VirtualShiftingMode modeDefault = VirtualShiftingMode.targetPower;
  static const int maxGearMin = 1;
  static const int maxGearMax = 30;
  static const int maxGearDefault = 24;
  static const int _gearRatiosMaxLength = 30;

  final String name;
  final String trainerKey;
  final bool isActive;
  final VirtualShiftingMode mode;
  final double bikeWeightKg;
  final double riderWeightKg;
  final bool gradeSmoothing;
  final int maxGear;
  final List<double>? gearRatios;

  const ShiftingConfig({
    required this.name,
    required this.trainerKey,
    required this.isActive,
    required this.mode,
    required this.bikeWeightKg,
    required this.riderWeightKg,
    required this.gradeSmoothing,
    this.maxGear = maxGearDefault,
    this.gearRatios,
  });

  factory ShiftingConfig.defaults({
    required String trainerKey,
    String name = 'Default',
    bool isActive = true,
    int maxGear = maxGearDefault,
  }) {
    return ShiftingConfig(
      name: name,
      trainerKey: trainerKey,
      isActive: isActive,
      mode: modeDefault,
      bikeWeightKg: bikeWeightDefaultKg,
      riderWeightKg: riderWeightDefaultKg,
      gradeSmoothing: true,
      maxGear: maxGear.clamp(maxGearMin, maxGearMax),
    );
  }

  factory ShiftingConfig.fromJson(Map<String, dynamic> json) {
    final rawMode = json['mode'] as String?;
    final parsedMode = VirtualShiftingMode.values.firstWhere(
      (e) => e.name == rawMode,
      orElse: () => modeDefault,
    );
    final bike = (json['bikeWeightKg'] as num?)?.toDouble() ?? bikeWeightDefaultKg;
    final rider = (json['riderWeightKg'] as num?)?.toDouble() ?? riderWeightDefaultKg;
    final rawMaxGear = (json['maxGear'] as num?)?.toInt() ?? maxGearDefault;
    final rawRatios = json['gearRatios'] as List?;
    final parsedRatios = rawRatios?.whereType<num>().map((e) => e.toDouble()).toList();
    return ShiftingConfig(
      name: (json['name'] as String?) ?? 'Default',
      trainerKey: (json['trainerKey'] as String?) ?? '__unknown__',
      isActive: (json['isActive'] as bool?) ?? false,
      mode: parsedMode,
      bikeWeightKg: bike.clamp(bikeWeightMinKg, bikeWeightMaxKg),
      riderWeightKg: rider.clamp(riderWeightMinKg, riderWeightMaxKg),
      gradeSmoothing: (json['gradeSmoothing'] as bool?) ?? true,
      maxGear: rawMaxGear.clamp(maxGearMin, maxGearMax),
      gearRatios: (parsedRatios != null &&
              parsedRatios.isNotEmpty &&
              parsedRatios.length <= _gearRatiosMaxLength)
          ? parsedRatios
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'trainerKey': trainerKey,
        'isActive': isActive,
        'mode': mode.name,
        'bikeWeightKg': bikeWeightKg,
        'riderWeightKg': riderWeightKg,
        'gradeSmoothing': gradeSmoothing,
        'maxGear': maxGear,
        if (gearRatios != null) 'gearRatios': gearRatios,
      };

  ShiftingConfig copyWith({
    String? name,
    String? trainerKey,
    bool? isActive,
    VirtualShiftingMode? mode,
    double? bikeWeightKg,
    double? riderWeightKg,
    bool? gradeSmoothing,
    int? maxGear,
    List<double>? gearRatios,
    bool clearGearRatios = false,
  }) {
    final resolvedMaxGear = maxGear ?? this.maxGear;
    final resolvedRatios = clearGearRatios ? null : (gearRatios ?? this.gearRatios);
    // If the gear count changed and we're left with custom ratios whose
    // length no longer matches, drop them so listeners fall back to the
    // freshly-sized defaults rather than silently overwriting custom ratios
    // in the view layer.
    final ratiosMatchMaxGear = resolvedRatios == null || resolvedRatios.length == resolvedMaxGear;
    return ShiftingConfig(
      name: name ?? this.name,
      trainerKey: trainerKey ?? this.trainerKey,
      isActive: isActive ?? this.isActive,
      mode: mode ?? this.mode,
      bikeWeightKg: bikeWeightKg ?? this.bikeWeightKg,
      riderWeightKg: riderWeightKg ?? this.riderWeightKg,
      gradeSmoothing: gradeSmoothing ?? this.gradeSmoothing,
      maxGear: resolvedMaxGear,
      gearRatios: ratiosMatchMaxGear ? resolvedRatios : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShiftingConfig &&
          name == other.name &&
          trainerKey == other.trainerKey &&
          isActive == other.isActive &&
          mode == other.mode &&
          bikeWeightKg == other.bikeWeightKg &&
          riderWeightKg == other.riderWeightKg &&
          gradeSmoothing == other.gradeSmoothing &&
          maxGear == other.maxGear &&
          listEquals(gearRatios, other.gearRatios));

  @override
  int get hashCode => Object.hash(
        name,
        trainerKey,
        isActive,
        mode,
        bikeWeightKg,
        riderWeightKg,
        gradeSmoothing,
        maxGear,
        gearRatios == null ? null : Object.hashAll(gearRatios!),
      );
}
