import 'package:bike_control/services/health/health_workout_channel.dart';
import 'package:bike_control/services/health/health_workout_payload.dart';
import 'package:bike_control/services/sensors/health_kit_channel.dart';
import 'package:bike_control/services/workout/workout_recorder.dart';
import 'package:bike_control/services/workout/workout_sample.dart';
import 'package:bike_control/services/workout/workout_summary.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const method = MethodChannel('bike_control/health_kit/workouts');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late MethodChannelHealthWorkout channel;

  HealthWorkoutPayload payload() {
    final start = DateTime.utc(2026, 9, 16, 18);
    final samples = [
      for (var i = 1; i <= 300; i++)
        WorkoutSample(timestamp: start.add(Duration(seconds: i)), powerW: 150, cadenceRpm: 85, speedKph: 30),
    ];
    final result = WorkoutResult(
      samples: samples,
      startedAt: start,
      endedAt: start.add(const Duration(seconds: 300)),
      activeDuration: const Duration(seconds: 300),
      pauses: const [],
      summary: WorkoutSummary.fromSamples(samples, startedAt: start, activeDuration: const Duration(seconds: 300)),
    );
    return HealthWorkoutPayload.fromResult(result, syncId: 'sync-1')!;
  }

  setUp(() {
    calls = [];
    channel = MethodChannelHealthWorkout.appleHealth();
    messenger.setMockMethodCallHandler(method, (call) async {
      calls.add(call);
      return switch (call.method) {
        'isAvailable' => true,
        'authorize' => 'granted',
        'saveWorkout' => 'workout-uuid',
        _ => null,
      };
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(method, null));

  test('method names and return mapping', () async {
    expect(await channel.availability(), HealthAvailability.available);
    expect(await channel.authorize(), HealthKitAuthorization.granted);
    expect(await channel.saveWorkout(payload()), 'workout-uuid');
    await channel.openHealthSettings();
    expect(calls.map((c) => c.method), ['isAvailable', 'authorize', 'saveWorkout', 'openHealthSettings']);
  });

  test('authorize maps denied and anything unexpected', () async {
    messenger.setMockMethodCallHandler(method, (call) async => 'denied');
    expect(await channel.authorize(), HealthKitAuthorization.denied);
    messenger.setMockMethodCallHandler(method, (call) async => 42);
    expect(await channel.authorize(), HealthKitAuthorization.unknown);
  });

  test('saveWorkout sends the whole ride in ONE call, as the payload map', () async {
    final p = payload();
    await channel.saveWorkout(p);
    expect(calls, hasLength(1));
    final args = calls.single.arguments as Map;
    expect(args['syncId'], 'sync-1');
    expect(args, p.toMap());
    // Survives the standard codec round trip untouched.
    const codec = StandardMethodCodec();
    final decoded = codec.decodeMethodCall(codec.encodeMethodCall(calls.single));
    expect(decoded.arguments, p.toMap());
  });

  test('native errors surface as PlatformException', () async {
    messenger.setMockMethodCallHandler(method, (call) async {
      throw PlatformException(code: 'save', message: 'Not authorized');
    });
    await expectLater(
      channel.saveWorkout(payload()),
      throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'save')),
    );
    await expectLater(channel.authorize(), throwsA(isA<PlatformException>()));
  });

  group('Health Connect', () {
    const hc = MethodChannel('bike_control/health_connect/workouts');
    late List<MethodCall> hcCalls;
    late MethodChannelHealthWorkout healthConnect;
    var status = 'available';

    setUp(() {
      hcCalls = [];
      healthConnect = MethodChannelHealthWorkout.healthConnect();
      messenger.setMockMethodCallHandler(hc, (call) async {
        hcCalls.add(call);
        return switch (call.method) {
          'availability' => status,
          'authorize' => 'granted',
          'saveWorkout' => 'record-id',
          _ => null,
        };
      });
    });

    tearDown(() => messenger.setMockMethodCallHandler(hc, null));

    test('same protocol on its own channel, plus install', () async {
      expect(healthConnect.store, HealthStore.healthConnect);
      expect(await healthConnect.availability(), HealthAvailability.available);
      expect(await healthConnect.authorize(), HealthKitAuthorization.granted);
      expect(await healthConnect.saveWorkout(payload()), 'record-id');
      await healthConnect.openHealthSettings();
      await healthConnect.openInstall();
      expect(hcCalls.map((c) => c.method), ['availability', 'authorize', 'saveWorkout', 'openHealthSettings', 'openInstall']);
      expect(hcCalls[2].arguments, payload().toMap());
    });

    test('availability: not installed, unsupported, anything else', () async {
      status = 'notInstalled';
      expect(await healthConnect.availability(), HealthAvailability.notInstalled);
      status = 'unsupported';
      expect(await healthConnect.availability(), HealthAvailability.unsupported);
      status = '??';
      expect(await healthConnect.availability(), HealthAvailability.unsupported);
      status = 'available';
    });
  });
}
