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

  final String name;
  final String trainerKey;
  final bool isActive;
  final VirtualShiftingMode mode;
  final double bikeWeightKg;
  final double riderWeightKg;
  final bool gradeSmoothing;
  final List<double>? gearRatios;

  const ShiftingConfig({
    required this.name,
    required this.trainerKey,
    required this.isActive,
    required this.mode,
    required this.bikeWeightKg,
    required this.riderWeightKg,
    required this.gradeSmoothing,
    this.gearRatios,
  });

  factory ShiftingConfig.defaults({required String trainerKey, String name = 'Default', bool isActive = true}) {
    return ShiftingConfig(
      name: name,
      trainerKey: trainerKey,
      isActive: isActive,
      mode: modeDefault,
      bikeWeightKg: bikeWeightDefaultKg,
      riderWeightKg: riderWeightDefaultKg,
      gradeSmoothing: true,
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
      gearRatios: (parsedRatios != null && parsedRatios.length == FitnessBikeDefinition.maxGear) ? parsedRatios : null,
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
    List<double>? gearRatios,
    bool clearGearRatios = false,
  }) {
    return ShiftingConfig(
      name: name ?? this.name,
      trainerKey: trainerKey ?? this.trainerKey,
      isActive: isActive ?? this.isActive,
      mode: mode ?? this.mode,
      bikeWeightKg: bikeWeightKg ?? this.bikeWeightKg,
      riderWeightKg: riderWeightKg ?? this.riderWeightKg,
      gradeSmoothing: gradeSmoothing ?? this.gradeSmoothing,
      gearRatios: clearGearRatios ? null : (gearRatios ?? this.gearRatios),
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
        gearRatios == null ? null : Object.hashAll(gearRatios!),
      );

}
