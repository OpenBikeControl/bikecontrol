import 'package:flutter/foundation.dart';

import '../sensors/sensor_quantity.dart';
import '../sensors/sensor_reading.dart';
import '../sensors/sensor_source.dart';
import '../workout/trainer_metrics.dart';

/// Ride metrics from external sensors, for a ride without a bridged trainer:
/// a power meter or a cadence sensor makes a source, heart rate rides along
/// but never starts a ride on its own. Readings older than the sensor's TTL
/// read as null, so a sensor that went quiet looks like a standstill.
///
/// Reads the sources directly rather than through the hub's resolution:
/// recording a ride is not gated on anything.
TrainerMetrics? metricsFromSensors(
  Iterable<SensorSource> sources, {
  String? Function(SensorQuantity quantity)? selected,
  DateTime Function()? now,
}) {
  final clock = now ?? DateTime.now;
  SensorSource? pick(SensorQuantity q) {
    final candidates = sources.where((s) => s.provides.contains(q)).toList();
    if (candidates.isEmpty) return null;
    final chosen = selected?.call(q);
    return candidates.where((s) => s.id == chosen).firstOrNull ?? candidates.first;
  }

  final power = pick(SensorQuantity.power);
  final cadence = pick(SensorQuantity.cadence);
  if (power == null && cadence == null) return null;
  final heartRate = pick(SensorQuantity.heartRate);

  ValueListenable<int?> fresh(SensorSource? source, SensorQuantity q) =>
      source == null ? ValueNotifier<int?>(null) : _FreshReading(source.readingFor(q), source.ttl, clock);

  return TrainerMetrics(
    powerW: fresh(power, SensorQuantity.power),
    cadenceRpm: fresh(cadence, SensorQuantity.cadence),
    speedKph: ValueNotifier<double?>(null),
    heartRateBpm: fresh(heartRate, SensorQuantity.heartRate),
    sourceName: (power ?? cadence)!.displayName,
  );
}

class _FreshReading implements ValueListenable<int?> {
  _FreshReading(this._reading, this._ttl, this._now);

  final ValueListenable<SensorReading?> _reading;
  final Duration _ttl;
  final DateTime Function() _now;

  @override
  int? get value {
    final r = _reading.value;
    if (r == null || _now().difference(r.timestamp) > _ttl) return null;
    return r.value;
  }

  @override
  void addListener(VoidCallback listener) => _reading.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _reading.removeListener(listener);
}
