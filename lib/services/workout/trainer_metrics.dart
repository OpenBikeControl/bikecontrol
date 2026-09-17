import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/composite_ble_definition.dart';
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

  /// Whether [heartRateBpm] currently comes from Apple Health (the sensor hub
  /// overrides the trainer's own value). Null means "never".
  final bool Function()? isHeartRateFromHealth;

  const TrainerMetrics({
    required this.powerW,
    required this.cadenceRpm,
    required this.speedKph,
    required this.heartRateBpm,
    this.isHeartRateFromHealth,
  });

  /// Returns null when [definition] is not a supported bike definition.
  ///
  /// Accepts a [CompositeBleDefinition] and extracts the first supported child,
  /// so callers can pass [DirconEmulator.activeDefinition] directly.
  static TrainerMetrics? fromDefinition(Object? definition, {bool Function()? isHeartRateFromHealth}) {
    if (definition is CompositeBleDefinition) {
      final fbd = definition.firstOfType<FitnessBikeDefinition>();
      if (fbd != null) return fromDefinition(fbd, isHeartRateFromHealth: isHeartRateFromHealth);
      final proxy = definition.firstOfType<ProxyBikeDefinition>();
      if (proxy != null) return fromDefinition(proxy, isHeartRateFromHealth: isHeartRateFromHealth);
      return null;
    }
    if (definition is FitnessBikeDefinition) {
      return TrainerMetrics(
        powerW: definition.powerW,
        cadenceRpm: definition.cadenceRpm,
        speedKph: definition.speedKph,
        heartRateBpm: definition.heartRateBpm,
        isHeartRateFromHealth: isHeartRateFromHealth,
      );
    }
    if (definition is ProxyBikeDefinition) {
      return TrainerMetrics(
        powerW: definition.powerW,
        cadenceRpm: definition.cadenceRpm,
        speedKph: definition.speedKph,
        heartRateBpm: definition.heartRateBpm,
        isHeartRateFromHealth: isHeartRateFromHealth,
      );
    }
    return null;
  }
}
