// Support log (Windows, KICKR CORE over WiFi): switching the control protocol
// on the trainer page cycles the bridge via ProxyDevice.reconnectUpstream. When
// the trainer's mDNS name did not resolve right then, the DirCon socket connect
// threw `SocketException: Failed host lookup` and nothing caught it — the
// protocol select fires its async onChanged and drops the Future, so the
// failure surfaced as an "App crashed" uncaught error. A failed upstream
// connect on that path must be handled like any other failed connect.
import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/prop.dart' show LogLevel;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

class _FakeLocalNotificationsPlatform extends FlutterLocalNotificationsPlatform {
  @override
  Future<void> show({required int id, String? title, String? body, String? payload}) async {}

  @override
  Future<void> cancel({required int id}) async {}

  @override
  Future<void> cancelAll() async {}
}

/// A WiFi trainer whose DirCon upstream cannot be reached: the connect throws
/// exactly what `Socket.connect` threw in the log. Teardown is recorded rather
/// than run — the emulator machinery is not what is under test.
class _UnreachableWifiTrainer extends ProxyDevice {
  _UnreachableWifiTrainer(super.scanResult) : super.wifi(host: 'KICKR-CORE-9588.local', port: 36866);

  int connectUpstreamCalls = 0;

  @override
  Future<void> connectUpstream() async {
    connectUpstreamCalls++;
    throw const SocketException(
      "Failed host lookup: 'KICKR-CORE-9588.local'",
      osError: OSError('No such host is known.', 11001),
    );
  }

  @override
  Future<void> disconnect() async {
    isConnected = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
    SharedPreferences.setMockInitialValues({});
    // The trial gate in startProxy reaches Supabase.instance; an offline dummy
    // keeps that path from asserting. No session, no network.
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'proxy-reconnect-upstream-failure-test-anon-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  const trainerName = 'KICKR CORE 9588';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
    core.connection.devices.clear();
    UniversalBle.setInstance(FakeUniversalBlePlatform());
    FlutterLocalNotificationsPlatform.instance = _FakeLocalNotificationsPlatform();
    IAPManager.instance.setProForTesting(enabled: true);
    // The rider had the bridge up — that is what reconnectUpstream cycles.
    await core.settings.setAutoConnect(trainerName, true);
  });

  tearDown(() async {
    core.connection.devices.clear();
    await core.connection.stop();
  });

  _UnreachableWifiTrainer connectedTrainer() {
    final trainer = _UnreachableWifiTrainer(
      BleDevice(
        deviceId: 'dircon://$trainerName',
        name: trainerName,
        services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
      ),
    );
    core.connection.devices.add(trainer);
    trainer.isConnected = true;
    return trainer;
  }

  test('a host lookup failure while reconnecting is handled, not thrown at the caller', () async {
    final trainer = connectedTrainer();
    final notifications = <BaseNotification>[];
    final sub = core.connection.actionStream.listen(notifications.add);
    addTearDown(sub.cancel);

    // The protocol select awaits this inside a callback whose Future nobody
    // holds — anything it throws is an uncaught error, so it must not throw.
    await expectLater(trainer.reconnectUpstream(), completes);
    await pumpEventQueue();

    expect(trainer.connectUpstreamCalls, 1, reason: 'the reconnect was actually attempted');
    expect(trainer.isConnected, isFalse);
    expect(trainer.isStarting.value, isFalse, reason: 'state is reset, so the next connect is not blocked');
    expect(
      notifications.whereType<AlertNotification>().where((n) => n.level == LogLevel.LOGLEVEL_ERROR),
      isNotEmpty,
      reason: 'the rider is told the reconnect failed',
    );
  });

  test('a failed reconnect leaves no uncaught error behind', () async {
    final trainer = connectedTrainer();
    final uncaught = <Object>[];

    // How the protocol select calls it: fire-and-forget from onChanged.
    await runZonedGuarded(() async {
      unawaited(trainer.reconnectUpstream());
      await pumpEventQueue();
    }, (e, _) => uncaught.add(e));
    await pumpEventQueue();

    expect(uncaught, isEmpty);
  });
}
