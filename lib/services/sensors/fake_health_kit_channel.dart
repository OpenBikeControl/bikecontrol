import 'dart:async';

import 'health_kit_channel.dart';

/// Scripted [HealthKitChannel] for unit and widget tests. Lives in `lib/`
/// (like `FakeSensorSource`) because widget tests inject it into
/// `core.connection.healthKitSource`.
class FakeHealthKitChannel implements HealthKitChannel {
  bool available = true;
  HealthKitAuthorization authorization = HealthKitAuthorization.granted;
  int authorizeCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;

  /// When set, [authorize] awaits this before returning [authorization] —
  /// lets a test observe state strictly BETWEEN the call starting and the
  /// native verdict actually arriving, distinguishing "authorize was called"
  /// from "authorize completed". Without this, [authorize] resolves
  /// synchronously (no real `await` boundary), which would let a broken
  /// "start the future, select, then await it" ordering pass a test that
  /// only checks call order rather than genuine completion order.
  Completer<void>? authorizeGate;

  /// When set, the next [authorize] call increments [authorizeCalls] and
  /// then throws this instead of returning — scripts a native authorize
  /// failure, e.g. `PlatformException(code: 'authorize', ...)` when the app
  /// cannot show a sheet at launch. Left as-is after throwing, mirroring
  /// [startError].
  Object? authorizeError;

  /// When set, the next [start] call increments [startCalls] and then
  /// throws this instead of returning — scripts the native-start-failure
  /// path (`HealthKitSensorSource.start` must swallow it and stay
  /// retryable). Left as-is after throwing, so callers explicitly clear it
  /// to script a subsequent successful start.
  Object? startError;

  final _events = StreamController<HealthKitEvent>.broadcast();

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<HealthKitAuthorization> authorize() async {
    authorizeCalls++;
    final gate = authorizeGate;
    if (gate != null) await gate.future;
    final error = authorizeError;
    if (error != null) throw error;
    return authorization;
  }

  @override
  Future<void> start() async {
    startCalls++;
    final error = startError;
    if (error != null) throw error;
  }

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Stream<HealthKitEvent> get events => _events.stream;

  void emitSample(int bpm, {required DateTime at, HealthKitMode mode = HealthKitMode.session}) =>
      _events.add(HealthKitSample(bpm: bpm, at: at, mode: mode));

  void emitMode(HealthKitMode mode) => _events.add(HealthKitModeEvent(mode));

  void emitError(Object error) => _events.addError(error);
}
