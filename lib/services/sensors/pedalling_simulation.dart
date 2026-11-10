import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'fake_sensor_source.dart';
import 'sensor_hub.dart';
import 'sensor_quantity.dart';

/// Debug-only: pretends the rider is pedalling, so trainer apps and virtual
/// shifting can be tested without riding.
///
/// Feeds power, cadence and heart rate through the [SensorHub] like an
/// external sensor would, so they reach the bridge (and through it the trainer
/// app) and the virtual shifting physics. Selecting it is not persisted, and
/// stopping restores whatever was selected before.
class PedallingSimulation {
  PedallingSimulation(this.hub);

  static const sourceId = 'debug-pedalling-simulation';
  static const _quantities = [SensorQuantity.power, SensorQuantity.cadence, SensorQuantity.heartRate];

  final SensorHub hub;
  final ValueNotifier<bool> isRunning = ValueNotifier(false);

  final _source = FakeSensorSource(
    id: sourceId,
    displayName: 'Pedalling simulation',
    provides: _quantities.toSet(),
  );
  final _random = math.Random();
  final Map<SensorQuantity, String?> _previousSelection = {};
  Timer? _timer;
  int _seconds = 0;

  void toggle() => isRunning.value ? stop() : start();

  void start() {
    if (isRunning.value) return;
    hub.register(_source);
    _seconds = 0;
    _emit();
    for (final quantity in _quantities) {
      _previousSelection[quantity] = hub.selectionFor(quantity);
      hub.select(quantity, sourceId);
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _emit());
    isRunning.value = true;
  }

  void stop() {
    if (!isRunning.value) return;
    _timer?.cancel();
    _timer = null;
    for (final quantity in _quantities) {
      hub.select(quantity, _previousSelection.remove(quantity));
    }
    hub.unregister(sourceId);
    isRunning.value = false;
  }

  /// One sample: power swings between about 140 and 260 W over a minute,
  /// cadence between about 80 and 96 rpm, with a little jitter on both.
  void _emit() {
    final t = _seconds++;
    int wave(double mid, double amplitude, double periodSeconds, int jitter) =>
        (mid + amplitude * math.sin(2 * math.pi * t / periodSeconds) + _random.nextInt(jitter * 2 + 1) - jitter)
            .round();
    _source.emit(SensorQuantity.power, wave(200, 60, 60, 10));
    _source.emit(SensorQuantity.cadence, wave(88, 8, 45, 2));
    _source.emit(SensorQuantity.heartRate, wave(135, 15, 120, 1));
  }
}
