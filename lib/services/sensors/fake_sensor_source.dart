import 'package:flutter/foundation.dart';

import 'sensor_quantity.dart';
import 'sensor_reading.dart';
import 'sensor_source.dart';

/// Scripted source for tests and the in-app emulation framework.
class FakeSensorSource extends SensorSource {
  FakeSensorSource({
    required this.id,
    required this.displayName,
    required this.provides,
  });

  @override
  final String id;

  @override
  final String displayName;

  @override
  final Set<SensorQuantity> provides;

  final Map<SensorQuantity, ValueNotifier<SensorReading?>> _readings = {};

  bool started = false;

  @override
  ValueListenable<SensorReading?> readingFor(SensorQuantity quantity) =>
      _notifierFor(quantity);

  ValueNotifier<SensorReading?> _notifierFor(SensorQuantity quantity) =>
      _readings.putIfAbsent(quantity, () => ValueNotifier<SensorReading?>(null));

  /// Publishes [value] for [quantity]. Ignored when the source does not claim
  /// to provide that quantity — mirrors real hardware, which cannot invent a
  /// characteristic it never advertised.
  void emit(SensorQuantity quantity, int value, {DateTime? at}) {
    if (!provides.contains(quantity)) return;
    _notifierFor(quantity).value = SensorReading(value, at ?? DateTime.now());
  }

  @override
  Future<void> start() async => started = true;

  @override
  Future<void> stop() async {
    started = false;
    for (final notifier in _readings.values) {
      notifier.value = null;
    }
  }
}
