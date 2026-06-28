import 'dart:async';

import 'package:bike_control/services/screen_recording/screen_recording_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory backend so the service's toggle/state logic is testable with no OS.
class FakeScreenRecorderBackend implements ScreenRecorderBackend {
  bool available = true;
  bool permission = true;
  bool startResult = true;
  String? stopPath = '/tmp/fake.mp4';
  int startCalls = 0;
  int stopCalls = 0;

  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<bool> ensurePermission() async => permission;
  /// When set, start() awaits this before returning, so a test can hold the
  /// service in the `starting` state.
  Completer<void>? startGate;

  @override
  Future<bool> start() async {
    startCalls++;
    if (startGate != null) await startGate!.future;
    return startResult;
  }

  @override
  Future<String?> stop() async {
    stopCalls++;
    return stopPath;
  }
}

void main() {
  late FakeScreenRecorderBackend backend;
  late ScreenRecordingService service;

  setUp(() {
    backend = FakeScreenRecorderBackend();
    service = ScreenRecordingService(backend: backend);
  });

  test('starts idle and reports availability from the backend', () async {
    expect(service.state.value, ScreenRecordingState.idle);
    expect(await service.isAvailable, isTrue);
    backend.available = false;
    expect(await service.isAvailable, isFalse);
  });

  test('toggle from idle starts recording', () async {
    final result = await service.toggle();
    expect(result.ok, isTrue);
    expect(result.startedRecording, isTrue);
    expect(service.state.value, ScreenRecordingState.recording);
    expect(service.isRecording, isTrue);
    expect(backend.startCalls, 1);
  });

  test('toggle while recording stops and returns the saved path', () async {
    await service.toggle(); // start
    final result = await service.toggle(); // stop
    expect(result.ok, isTrue);
    expect(result.startedRecording, isFalse);
    expect(result.savedPath, '/tmp/fake.mp4');
    expect(service.state.value, ScreenRecordingState.idle);
    expect(service.isRecording, isFalse);
    expect(backend.stopCalls, 1);
  });

  test('toggle returns failure and stays idle when start fails', () async {
    backend.startResult = false;
    final result = await service.toggle();
    expect(result.ok, isFalse);
    expect(service.state.value, ScreenRecordingState.idle);
  });

  test('toggle returns failure when permission denied, without starting', () async {
    backend.permission = false;
    final result = await service.toggle();
    expect(result.ok, isFalse);
    expect(result.startedRecording, isFalse);
    expect(backend.startCalls, 0);
    expect(service.state.value, ScreenRecordingState.idle);
  });

  test('toggle on unsupported backend reports unsupported', () async {
    backend.available = false;
    final result = await service.toggle();
    expect(result.ok, isFalse);
    expect(result.startedRecording, isFalse);
    expect(service.state.value, ScreenRecordingState.unsupported);
  });

  test('toggle completes without throwing when backend start() throws', () async {
    final throwingBackend = _ThrowingScreenRecorderBackend();
    final throwingService = ScreenRecordingService(backend: throwingBackend);
    final result = await throwingService.toggle();
    expect(result.ok, isFalse);
    expect(throwingService.state.value, ScreenRecordingState.error);
  });

  test('ignores a re-entrant toggle while a start is in flight', () async {
    backend.startGate = Completer<void>();

    final first = service.toggle(); // enters 'starting', then blocks in start()
    // Let it advance through isAvailable/ensurePermission into the gated start().
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(service.state.value, ScreenRecordingState.starting);

    final second = await service.toggle(); // must be ignored, not a 2nd start
    expect(second.ok, isFalse);
    expect(backend.startCalls, 1, reason: 'the in-flight guard prevents a second start');

    backend.startGate!.complete();
    await first;
    expect(service.state.value, ScreenRecordingState.recording);
    expect(backend.startCalls, 1);
  });
}

/// Backend whose start() always throws, to verify the never-throws contract.
class _ThrowingScreenRecorderBackend implements ScreenRecorderBackend {
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<bool> ensurePermission() async => true;
  @override
  Future<bool> start() async => throw Exception('simulated backend crash');
  @override
  Future<String?> stop() async => null;
}
