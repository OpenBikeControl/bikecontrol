import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:nsd_platform_interface/nsd_platform_interface.dart';
import 'package:prop/utils/self_advertisement_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import 'fake_ble_platform.dart';
import 'fake_nsd_platform.dart';

/// No-op local-notifications backend. The plugin's static platform instance
/// is only initialized by real plugin registration; without this, every
/// connection-state notification crashes with a LateInitializationError.
class _FakeLocalNotificationsPlatform extends FlutterLocalNotificationsPlatform {
  @override
  Future<void> show(int id, String? title, String? body, {String? payload}) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}
}

/// All platform fakes for one integration-test file.
class IntegrationEnv {
  IntegrationEnv._();

  final ble = FakeUniversalBlePlatform();
  final mdns = FakeNsdPlatform();

  /// One-time process setup: localizations, channel mocks, platform fakes.
  /// Call from main() before any test. Idempotent.
  static Future<IntegrationEnv> setUp() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await AppLocalizations.load(const Locale('en'));

    // IAP checks reach Supabase.instance on the hot path (isLoggedIn) — give
    // it an offline dummy instance so free-tier logic runs without asserts.
    // No session is stored, so no network request is ever made. Must run
    // inside a test zone (it constructs an HttpClient), hence setUpAll.
    setUpAll(() async {
      await Supabase.initialize(
        url: 'http://127.0.0.1:9',
        anonKey: 'integration-test-anon-key',
        debug: false,
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
          detectSessionInUri: false,
          autoRefreshToken: false,
        ),
      );
    });

    final env = IntegrationEnv._();
    UniversalBle.setInstance(env.ble);
    NsdPlatformInterface.instance = env.mdns;
    FlutterLocalNotificationsPlatform.instance = _FakeLocalNotificationsPlatform();

    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    // flutter_local_notifications: connection events trigger unawaited
    // show() calls — swallow them instead of MissingPluginException.
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => null,
    );
    // gamepads: Connection.performScanning polls for gamepads every 3 s.
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/gamepads'),
      (call) async => call.method == 'listGamepads' ? <dynamic>[] : null,
    );

    await env.resetState();
    return env;
  }

  /// Per-test reset of all shared mutable state (the app's `core` and the
  /// fakes survive across tests in a file).
  Future<void> resetState({Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    core.settings.prefs = await SharedPreferences.getInstance();

    ble.reset();
    mdns.reset();
    SelfAdvertisementRegistry.instance.clear();
  }

  /// Tear down everything the Connection built up during a test: emulators,
  /// devices, subscriptions, scan state.
  Future<void> resetConnection() async {
    // Disconnect first — proxy-device disconnects stop the shared ftms
    // emulator and per-instance proxy emulators (mDNS + TCP teardown).
    for (final device in List.of(core.connection.devices)) {
      try {
        await core.connection.disconnect(device, persistForget: false, forget: true);
      } catch (e, s) {
        // A device that was never connected can throw on teardown — the test
        // is over, we only care that the list ends up empty.
        debugPrint('resetConnection: teardown of $device failed: $e\n$s');
      }
    }
    // Drain the reconnect attempts the disconnect listeners just scheduled
    // (they call performScanning), THEN reset the scan state so the next
    // test's performScanning actually starts a fresh scan.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await core.connection.stop();
    core.connection.devices.clear();
    core.connection.hasDevices.value = false;
    core.connection.isScanning.value = false;
  }

  /// Pump the real event loop until [condition] is true.
  static Future<void> waitFor(
    FutureOr<bool> Function() condition, {
    Duration timeout = const Duration(seconds: 5),
    String description = 'condition',
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    throw TimeoutException('Timed out waiting for $description');
  }
}
