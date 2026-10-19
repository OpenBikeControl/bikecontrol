// Picking a bridge mode on the ConnectionCard of a trainer that is not
// connected starts the upstream connect from the radio group's onChanged —
// a callback whose Future nobody holds. A WiFi trainer whose mDNS name does
// not resolve throws `SocketException: Failed host lookup` out of that
// connect; unhandled, it surfaces as an "App crashed" uncaught error. The card
// must handle it like the connect-from-picker path does.
import 'dart:io';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/proxy_device_details/connection_card.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
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
/// what `Socket.connect` threw in the support log.
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
}

void main() {
  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
    SharedPreferences.setMockInitialValues({});
    // The card's trial gate reaches Supabase.instance: an offline dummy one.
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'connection-card-connect-failure-test-anon-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  testWidgets('a host lookup failure when picking a bridge mode is handled, not uncaught', (tester) async {
    SharedPreferences.setMockInitialValues({'trainer_app': 'MyWhoosh'});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
    core.connection.devices.clear();
    UniversalBle.setInstance(FakeUniversalBlePlatform());
    FlutterLocalNotificationsPlatform.instance = _FakeLocalNotificationsPlatform();
    IAPManager.instance.setProForTesting(enabled: true);
    addTearDown(() async {
      core.connection.devices.clear();
      await core.connection.stop();
    });

    final trainer = _UnreachableWifiTrainer(
      BleDevice(
        deviceId: 'dircon://KICKR CORE 9588',
        name: 'KICKR CORE 9588',
        services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
      ),
    );
    core.connection.devices.add(trainer);

    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(child: SizedBox(width: 400, child: ConnectionCard(device: trainer))),
      ),
    );
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.text(AppLocalizations.current.proxyMode));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    expect(trainer.connectUpstreamCalls, 1, reason: 'the connect was actually attempted');
    expect(tester.takeException(), isNull);
    expect(trainer.isConnected, isFalse);
    expect(trainer.isStarting.value, isFalse);
  });
}
