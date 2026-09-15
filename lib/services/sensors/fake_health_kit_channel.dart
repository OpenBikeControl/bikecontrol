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

  final _events = StreamController<HealthKitEvent>.broadcast();

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<HealthKitAuthorization> authorize() async {
    authorizeCalls++;
    return authorization;
  }

  @override
  Future<void> start() async => startCalls++;

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Stream<HealthKitEvent> get events => _events.stream;

  void emitSample(int bpm, {required DateTime at, HealthKitMode mode = HealthKitMode.session}) =>
      _events.add(HealthKitSample(bpm: bpm, at: at, mode: mode));

  void emitMode(HealthKitMode mode) => _events.add(HealthKitModeEvent(mode));

  void emitError(Object error) => _events.addError(error);
}
