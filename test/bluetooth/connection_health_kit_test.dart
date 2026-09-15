import 'package:bike_control/main.dart' show installLoggerErrorListener;
import 'package:bike_control/services/sensors/fake_health_kit_channel.dart';
import 'package:bike_control/services/sensors/health_kit_channel.dart';
import 'package:bike_control/services/sensors/health_kit_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:prop/utils/shared.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// No-op local-notifications backend — `Connection._connect` posts a
/// "connected" notification on success, and the plugin's static platform
/// instance is only set by real plugin registration. Mirrors
/// `test/integration/harness/test_env.dart`'s own fake (and
/// `live_metrics_section_test.dart`'s, this file's own scaffolding source).
class _FakeLocalNotificationsPlatform extends FlutterLocalNotificationsPlatform {
  @override
  Future<void> show({required int id, String? title, String? body, String? payload}) async {}

  @override
  Future<void> cancel({required int id}) async {}

  @override
  Future<void> cancelAll() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'live-metrics-section-test-anon-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
    core.connection.devices.clear();
    FlutterLocalNotificationsPlatform.instance = _FakeLocalNotificationsPlatform();
    IAPManager.instance.setProForTesting(enabled: false);
  });

  tearDown(() {
    core.connection.devices.clear();
    IAPManager.instance.setProForTesting(enabled: false);
  });

  late FakeHealthKitChannel channel;

  setUp(() {
    // recordError() -> installLoggerErrorListener() only assigns
    // Logger.onRecordError the first time it runs in this isolate; trip
    // that guard here (before overriding the listener below) so the no-op
    // below isn't clobbered by the production listener on the first
    // recordError() call, keeping `flutter test` output pristine. The
    // denied-on-restore path is a user choice, not a crash — it logs via
    // `_appendLogEntry` instead — but other paths here (e.g. an unexpected
    // register/start failure in connectHealthKit) still go through
    // recordError.
    installLoggerErrorListener();
    Logger.onRecordError = (_, _, _) {};
    channel = FakeHealthKitChannel();
    core.connection.healthKitSource = HealthKitSensorSource(channel: channel);
  });

  tearDown(() async {
    await core.connection.disconnectHealthKit(forget: true);
    core.connection.healthKitSource = null;
    core.sensors.select(SensorQuantity.heartRate, null);
    Logger.onRecordError = null;
  });

  group('authorizeHealthKit', () {
    test('denied: throws, and never touches the hub', () async {
      channel.authorization = HealthKitAuthorization.denied;

      await expectLater(core.connection.authorizeHealthKit(), throwsA(isA<HealthKitDeniedException>()));
      expect(channel.authorizeCalls, 1);
      expect(channel.startCalls, 0);
      expect(core.connection.isHealthKitConnected, isFalse);
    });

    test('unknown: proceeds (read denials are invisible anyway)', () async {
      channel.authorization = HealthKitAuthorization.unknown;

      await core.connection.authorizeHealthKit();

      expect(channel.authorizeCalls, 1);
    });

    test('granted: proceeds', () async {
      await core.connection.authorizeHealthKit();

      expect(channel.authorizeCalls, 1);
    });

    test('no source (non-iOS) is a no-op', () async {
      core.connection.healthKitSource = null;

      await core.connection.authorizeHealthKit();

      expect(channel.authorizeCalls, 0);
    });
  });

  group('connectHealthKit', () {
    test('registers in the hub and starts the native side, without authorizing', () async {
      await core.connection.connectHealthKit();

      expect(channel.authorizeCalls, 0);
      expect(channel.startCalls, 1);
      expect(core.connection.isHealthKitConnected, isTrue);
      expect(core.sensors.sourcesFor(SensorQuantity.heartRate).map((s) => s.id), contains('healthkit'));
    });

    test('with no source (non-iOS) is a no-op', () async {
      core.connection.healthKitSource = null;

      await core.connection.connectHealthKit();

      expect(channel.startCalls, 0);
    });
  });

  test('disconnect(forget: false): unregisters and stops, selection survives', () async {
    await core.connection.connectHealthKit();
    core.sensors.select(SensorQuantity.heartRate, 'healthkit');

    await core.connection.disconnectHealthKit(forget: false);

    expect(channel.stopCalls, 1);
    expect(core.connection.isHealthKitConnected, isFalse);
    expect(core.sensors.selectionFor(SensorQuantity.heartRate), 'healthkit');
  });

  test('disconnect(forget: true): also clears the selection back to Trainer', () async {
    await core.connection.connectHealthKit();
    core.sensors.select(SensorQuantity.heartRate, 'healthkit');

    await core.connection.disconnectHealthKit(forget: true);

    expect(core.sensors.selectionFor(SensorQuantity.heartRate), isNull);
  });

  test('disconnect when never connected is a no-op', () async {
    await core.connection.disconnectHealthKit(forget: true);
    expect(channel.stopCalls, 0);
  });

  group('restoreHealthKitSelection', () {
    test('a persisted healthkit selection authorizes then connects silently on launch', () async {
      core.sensors.select(SensorQuantity.heartRate, 'healthkit');

      await core.connection.restoreHealthKitSelection();

      expect(channel.authorizeCalls, 1);
      expect(channel.startCalls, 1);
      expect(core.connection.isHealthKitConnected, isTrue);
    });

    test(
      'sensors-only mode: skips the restore entirely — Broadcast is what connects Apple Health there',
      () async {
        await core.settings.setSensorsOnlyMode(true);
        addTearDown(() => core.settings.setSensorsOnlyMode(false));
        core.sensors.select(SensorQuantity.heartRate, 'healthkit');

        await core.connection.restoreHealthKitSelection();

        expect(channel.authorizeCalls, 0);
        expect(channel.startCalls, 0);
        expect(core.connection.isHealthKitConnected, isFalse);
        expect(
          core.connection.lastLogEntries.map((e) => e.entry),
          contains('HealthKit: sensors-only mode — Apple Health connects when Broadcast is switched on'),
        );
      },
    );

    test('denial is a user choice, not a crash — logged, not recordError-ed, registers nothing', () async {
      channel.authorization = HealthKitAuthorization.denied;
      core.sensors.select(SensorQuantity.heartRate, 'healthkit');

      await core.connection.restoreHealthKitSelection();

      expect(core.connection.isHealthKitConnected, isFalse);
      expect(channel.startCalls, 0);
      expect(
        core.connection.lastLogEntries.map((e) => e.entry),
        contains('HealthKit: persisted Apple Health selection not restored — permission denied'),
      );
    });

    test('nothing selected → nothing happens', () async {
      await core.connection.restoreHealthKitSelection();
      expect(channel.authorizeCalls, 0);
      expect(channel.startCalls, 0);
    });

    test('with no source (non-iOS) is a no-op', () async {
      core.connection.healthKitSource = null;
      core.sensors.select(SensorQuantity.heartRate, 'healthkit');
      await core.connection.restoreHealthKitSelection();
      expect(channel.startCalls, 0);
    });

    test(
      'a native authorize failure at launch (e.g. app launched in background, no sheet possible) '
      'is a benign environmental outcome — logged, not recordError-ed, registers nothing',
      () async {
        channel.authorizeError = PlatformException(code: 'authorize', message: 'Authorization session timed out');
        core.sensors.select(SensorQuantity.heartRate, 'healthkit');

        await core.connection.restoreHealthKitSelection();

        expect(core.connection.isHealthKitConnected, isFalse);
        expect(channel.startCalls, 0);
        expect(
          core.connection.lastLogEntries.map((e) => e.entry),
          contains('HealthKit: authorization at launch failed — Authorization session timed out'),
        );
      },
    );
  });
}
