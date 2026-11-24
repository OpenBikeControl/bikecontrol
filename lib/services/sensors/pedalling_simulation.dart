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
///
/// It also rides a hilly route: [grade] is what an incline device (Elite
/// Rizer, KICKR Climb) follows while no trainer app sends a grade.
class PedallingSimulation {
  PedallingSimulation(this.hub);

  static const sourceId = 'debug-pedalling-simulation';
  static const _quantities = [SensorQuantity.power, SensorQuantity.cadence, SensorQuantity.heartRate];

  final SensorHub hub;
  final ValueNotifier<bool> isRunning = ValueNotifier(false);

  /// The simulated route's gradient (0.01% signed), null while stopped.
  final ValueNotifier<int?> grade = ValueNotifier(null);

  final _source = FakeSensorSource(
    id: sourceId,
    displayName: 'Pedalling simulation',
    provides: _quantities.toSet(),
    // A debug tool: it has to drive the bridge on a trial install too, where
    // the hub otherwise hides external power and cadence (a Pro feature).
    requiresPro: false,
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
    grade.value = null;
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
    grade.value = simulatedGrade001(t);
  }

  /// The route at second [t]: a 3-minute climb-and-descent from about -4% to
  /// +10% with shorter rollers on top, in 0.5% steps like a real route's
  /// segments, so an incline device moves now and then rather than every
  /// second.
  @visibleForTesting
  static int simulatedGrade001(int t) {
    final pct = 3 + 5 * math.sin(2 * math.pi * t / 180) + 2 * math.sin(2 * math.pi * t / 50);
    return ((pct * 2).round() * 50).clamp(-1000, 2000);
  }
}
