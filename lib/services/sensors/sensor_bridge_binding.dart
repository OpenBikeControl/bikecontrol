import 'package:flutter/foundation.dart';

import 'sensor_hub.dart';
import 'sensor_quantity.dart';

/// Forwards the hub's resolved values to whatever is serving them.
///
/// `null` is meaningful and must be forwarded: it is how the bridge is told to
/// go back to the trainer's own reading after a sensor drops out.
///
/// All three quantities go through the identical listen-and-forward shape —
/// see [_bind] — so heart rate, cadence and power stay in lockstep rather
/// than heart rate accidentally growing special-cased behaviour the other two
/// lack.
class SensorBridgeBinding {
  SensorBridgeBinding({
    required this.hub,
    required this.onHeartRate,
    required this.onCadence,
    required this.onPower,
  });

  final SensorHub hub;
  final void Function(int?) onHeartRate;
  final void Function(int?) onCadence;
  final void Function(int?) onPower;

  final Map<SensorQuantity, ValueListenable<int?>> _resolved = {};
  final Map<SensorQuantity, VoidCallback> _listeners = {};

  void start() {
    _bind(SensorQuantity.heartRate, onHeartRate);
    _bind(SensorQuantity.cadence, onCadence);
    _bind(SensorQuantity.power, onPower);
  }

  void _bind(SensorQuantity quantity, void Function(int?) onValue) {
    final resolved = hub.resolved(quantity);
    void listener() => onValue(resolved.value);
    resolved.addListener(listener);
    _resolved[quantity] = resolved;
    _listeners[quantity] = listener;
    listener();
  }

  void dispose() {
    for (final entry in _listeners.entries) {
      _resolved[entry.key]?.removeListener(entry.value);
    }
    _resolved.clear();
    _listeners.clear();
  }
}
