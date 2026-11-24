// A trainer app that finds trainers over Bluetooth only (FulGaz, Biketerra, the Wahoo app) turns
// the picker's WiFi bridge into a Bluetooth one. On Android that needs
// BLUETOOTH_ADVERTISE, which nothing asked for: the bridge spun forever and
// the trainer app never listed it (2026-11-24). The picker asks now.
import 'dart:async';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/utils/requirements/platform.dart';
import 'package:bike_control/utils/trainer_connect.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/prop.dart' show RetrofitMode;
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

/// A trainer that only records whether a connect reached it.
class _RecordingTrainer extends ProxyDevice {
  _RecordingTrainer(super.scanResult);

  int connectUpstreamCalls = 0;

  @override
  Future<void> connectUpstream() async {
    connectUpstreamCalls++;
    throw StateError('stop here');
  }
}

void main() {
  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      publishableKey: 'trainer-connect-bt-permission-test-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  late _RecordingTrainer trainer;
  late List<List<PlatformRequirement>> asked;

  Future<void> setUpWith(String trainerApp, {required bool grant}) async {
    SharedPreferences.setMockInitialValues({'trainer_app': trainerApp, 'last_target': 'otherDevice'});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
    core.connection.devices.clear();
    UniversalBle.setInstance(FakeUniversalBlePlatform());
    FlutterLocalNotificationsPlatform.instance = _FakeLocalNotificationsPlatform();
    IAPManager.instance.setProForTesting(enabled: true);
    debugHostPlatformOverride = TargetPlatform.android;
    asked = [];
    debugSatisfyBridgeRequirements = (context, requirements) async {
      asked.add(requirements);
      return grant;
    };
    trainer = _RecordingTrainer(
      BleDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        name: 'Wahoo KICKR 1EB7',
        services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
      ),
    );
    core.connection.devices.add(trainer);
    addTearDown(() async {
      debugHostPlatformOverride = null;
      debugSatisfyBridgeRequirements = null;
      core.connection.devices.clear();
      await core.connection.stop();
    });
  }

  Future<BuildContext> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: const Scaffold(child: SizedBox()),
      ),
    );
    return tester.element(find.byType(Scaffold));
  }

  Future<void> pick(WidgetTester tester, BuildContext context) async {
    await tester.runAsync(() async {
      unawaited(connectTrainerFromPicker(context, trainer));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
  }

  testWidgets('a Bluetooth-only app asks for the advertise permission first', (tester) async {
    await setUpWith('FulGaz', grant: true);
    final context = await pumpHost(tester);

    await pick(tester, context);

    expect(trainer.savedRetrofitMode, RetrofitMode.bluetooth);
    expect(asked.expand((r) => r).whereType<BluetoothAdvertiseRequirement>(), hasLength(1));
    expect(trainer.connectUpstreamCalls, 1, reason: 'granted, so the connect goes ahead');
  });

  testWidgets('declining it leaves the trainer unconnected', (tester) async {
    await setUpWith('FulGaz', grant: false);
    final context = await pumpHost(tester);

    await pick(tester, context);

    expect(trainer.connectUpstreamCalls, 0);
    expect(core.settings.getAutoConnect(trainer.trainerKey), isFalse);
  });

  testWidgets('a WiFi bridge asks for nothing Bluetooth', (tester) async {
    await setUpWith('MyWhoosh', grant: true);
    final context = await pumpHost(tester);

    await pick(tester, context);

    expect(asked.expand((r) => r).whereType<BluetoothAdvertiseRequirement>(), isEmpty);
    expect(trainer.connectUpstreamCalls, 1);
  });
}
