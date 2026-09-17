import 'package:flutter/foundation.dart';

import 'sensor_hub.dart';
import 'sensor_quantity.dart';
import 'sensor_reading.dart';

/// A producer of rider metrics that is not the trainer.
///
/// Implementations own transport and parsing only. Selection, staleness and
/// fallback are the hub's business — see `SensorHub`.
abstract class SensorSource {
  /// Stable across restarts; persisted as the rider's per-quantity choice.
  String get id;

  String get displayName;

  Set<SensorQuantity> get provides;

  ValueListenable<SensorReading?> readingFor(SensorQuantity quantity);

  /// How long a reading stays usable. BLE sensors notify at roughly 1 Hz;
  /// HealthKit delivers in batches and needs a far longer window, so this is
  /// per source kind rather than a single global constant.
  Duration get ttl => SensorHub.bleSensorTtl;

  Future<void> start();

  Future<void> stop();
}
