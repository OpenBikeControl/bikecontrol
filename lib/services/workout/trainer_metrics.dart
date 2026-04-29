import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/definitions/proxy_bike_definition.dart';

/// Bundles the four `ValueListenable`s that drive workout recording, regardless
/// of whether the source is an FTMS passthrough (`FitnessBikeDefinition`) or a
/// Zwift-protocol-only trainer (`ProxyBikeDefinition`).
class TrainerMetrics {
  final ValueListenable<int?> powerW;
  final ValueListenable<int?> cadenceRpm;
  final ValueListenable<double?> speedKph;
  final ValueListenable<int?> heartRateBpm;

  const TrainerMetrics({
    required this.powerW,
    required this.cadenceRpm,
    required this.speedKph,
    required this.heartRateBpm,
  });

  /// Returns null when [definition] is not a supported bike definition.
  static TrainerMetrics? fromDefinition(Object? definition) {
    if (definition is FitnessBikeDefinition) {
      return TrainerMetrics(
        powerW: definition.powerW,
        cadenceRpm: definition.cadenceRpm,
        speedKph: definition.speedKph,
        heartRateBpm: definition.heartRateBpm,
      );
    }
    if (definition is ProxyBikeDefinition) {
      return TrainerMetrics(
        powerW: definition.powerW,
        cadenceRpm: definition.cadenceRpm,
        speedKph: definition.speedKph,
        heartRateBpm: definition.heartRateBpm,
      );
    }
    return null;
  }
}
