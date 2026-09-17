import 'package:bike_control/main.dart' show installLoggerErrorListener;
import 'package:bike_control/services/sensors/health_kit_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/utils/shared.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const method = MethodChannel('bike_control/health_kit');
  const event = EventChannel('bike_control/health_kit/heart_rate');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late MethodChannelHealthKit channel;

  setUp(() {
    calls = [];
    channel = MethodChannelHealthKit();
    // recordError() -> installLoggerErrorListener() only assigns
    // Logger.onRecordError the first time it runs in this isolate; trip
    // that guard here (before overriding the listener below) so the
    // no-op below isn't clobbered by the production listener on the
    // first recordError() call, keeping `flutter test` output pristine.
    installLoggerErrorListener();
    Logger.onRecordError = (_, _, _) {};
    messenger.setMockMethodCallHandler(method, (call) async {
      calls.add(call);
      return switch (call.method) {
        'isAvailable' => true,
        'authorize' => 'denied',
        _ => null,
      };
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(method, null);
    messenger.setMockStreamHandler(event, null);
    Logger.onRecordError = null;
  });

  test('method names and return mapping', () async {
    expect(await channel.isAvailable(), isTrue);
    expect(await channel.authorize(), HealthKitAuthorization.denied);
    await channel.start();
    await channel.stop();
    expect(calls.map((c) => c.method), ['isAvailable', 'authorize', 'start', 'stop']);
  });

  test('an unexpected authorize string maps to unknown', () async {
    messenger.setMockMethodCallHandler(method, (call) async => 'whatever');
    expect(await channel.authorize(), HealthKitAuthorization.unknown);
  });

  test('events: mode-only map, full sample, malformed sample and non-map payload dropped', () async {
    messenger.setMockStreamHandler(
      event,
      MockStreamHandler.inline(
        onListen: (args, sink) {
          sink.success({'mode': 'passive'});
          sink.success('not-a-map'); // dropped: not a Map at all
          sink.success({'bpm': 133, 'at': 1789200000000, 'mode': 'session'});
          sink.success({'bpm': 0, 'at': 1789200001000, 'mode': 'session'}); // dropped
          sink.success({'bpm': 'x', 'at': 1789200002000, 'mode': 'session'}); // dropped
          sink.success(42); // dropped: not a Map at all
          sink.success({'bpm': 140, 'at': 1789200003000, 'mode': 'session'});
          sink.endOfStream();
        },
      ),
    );

    final events = await channel.events.toList();
    expect(events, hasLength(3));
    expect(events[0], isA<HealthKitModeEvent>().having((e) => e.mode, 'mode', HealthKitMode.passive));
    final sample = events[1] as HealthKitSample;
    expect(sample.bpm, 133);
    expect(sample.at, DateTime.fromMillisecondsSinceEpoch(1789200000000, isUtc: true));
    expect(sample.mode, HealthKitMode.session);
    expect((events[2] as HealthKitSample).bpm, 140);
  });

  test('a platform error on the event stream surfaces as a stream error', () async {
    messenger.setMockStreamHandler(
      event,
      MockStreamHandler.inline(
        onListen: (args, sink) {
          sink.error(code: 'session', message: 'ended by OS');
          sink.endOfStream();
        },
      ),
    );
    expect(channel.events.first, throwsA(isA<PlatformException>()));
  });
}
