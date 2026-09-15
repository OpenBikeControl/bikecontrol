import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:bike_control/main.dart';

import 'health_kit_channel.dart';
import 'sensor_hub.dart';
import 'sensor_quantity.dart';
import 'sensor_reading.dart';
import 'sensor_source.dart';

/// Heart rate from Apple Health — the only way AirPods Pro 3 (or an Apple
/// Watch) can reach BikeControl, since neither advertises `0x180D`.
///
/// Transport and parsing only, like `BleSensorSource`: selection, staleness
/// and fallback stay the hub's business. Lifecycle mirrors a strap —
/// registered ⇔ the native session/query is running.
class HealthKitSensorSource extends SensorSource {
  HealthKitSensorSource({required HealthKitChannel channel}) : _channel = channel;

  static const sourceId = 'healthkit';

  final HealthKitChannel _channel;
  final _reading = ValueNotifier<SensorReading?>(null);
  final _mode = ValueNotifier<HealthKitMode?>(null);
  StreamSubscription<HealthKitEvent>? _subscription;

  @override
  String get id => sourceId;

  /// Apple's product name, like a strap's advertised name — not localised.
  @override
  String get displayName => 'Apple Health';

  @override
  Set<SensorQuantity> get provides => const {SensorQuantity.heartRate};

  /// Passive delivery is batched and lags a strap by a lot; a 5 s window
  /// would flap continuously (see `SensorHub.healthKitTtl`).
  @override
  Duration get ttl => SensorHub.healthKitTtl;

  /// Which native path is live — null until `start` reports it and again
  /// after `stop`. The UI uses `passive` to explain a sparse tile.
  ValueListenable<HealthKitMode?> get mode => _mode;

  @override
  ValueListenable<SensorReading?> readingFor(SensorQuantity quantity) => _reading;

  Future<HealthKitAuthorization> authorize() => _channel.authorize();

  @override
  Future<void> start() async {
    if (_subscription != null) return;
    _subscription = _channel.events.listen(
      _onEvent,
      // Recorded, never fatal: the hub's drop-out path produces the visible
      // state if samples stop, exactly as for a strap that stops notifying.
      onError: (Object e, StackTrace s) => recordError(e, s, context: 'HealthKitSensorSource.events'),
      cancelOnError: false,
    );
    await _channel.start();
  }

  @override
  Future<void> stop() async {
    final subscription = _subscription;
    if (subscription == null) return;
    _subscription = null;
    await subscription.cancel();
    await _channel.stop();
    // Cleared rather than left to be served stale past the TTL — same
    // contract as `Connection._unregisterSensorSource` relies on.
    _reading.value = null;
    _mode.value = null;
  }

  void _onEvent(HealthKitEvent event) {
    switch (event) {
      case HealthKitModeEvent(:final mode):
        _mode.value = mode;
      case HealthKitSample(:final bpm, :final at, :final mode):
        _mode.value = mode;
        _reading.value = SensorReading(bpm, at);
    }
  }
}
