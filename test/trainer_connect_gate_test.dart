// Every rider without Pro gets a daily virtual shifting trial, also after the
// trial period (and on builds that never had one). Connecting a trainer for
// virtual shifting must start, not end at the generic Pro dialog; only proxy
// mode stays locked behind the trial period.
import 'dart:async';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/proxy_device_details/connection_card.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
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

/// A WiFi trainer that only records whether a connect reached it.
class _RecordingWifiTrainer extends ProxyDevice {
  _RecordingWifiTrainer(super.scanResult) : super.wifi(host: 'KICKR-CORE-1234.local', port: 36866);

  int connectUpstreamCalls = 0;

  @override
  Future<void> connectUpstream() async {
    connectUpstreamCalls++;
    throw StateError('stop here');
  }
}

_RecordingWifiTrainer _trainer() => _RecordingWifiTrainer(
  BleDevice(
    deviceId: 'dircon://KICKR CORE 1234',
    name: 'KICKR CORE 1234',
    services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
  ),
);

Future<void> _useUpTodaysBudget() async {
  final prefs = core.bridgeUsageTracker.prefs;
  final now = DateTime.now();
  final today =
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  await prefs.setString('bridge_usage_date', today);
  await prefs.setInt('bridge_usage_seconds', core.bridgeUsageTracker.dailyLimit.inSeconds);
}

void main() {
  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      publishableKey: 'trainer-connect-gate-test-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  late _RecordingWifiTrainer trainer;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'trainer_app': 'MyWhoosh'});
    core.settings.prefs = await SharedPreferences.getInstance();
    final prefs = core.bridgeUsageTracker.prefs;
    await prefs.remove('bridge_usage_date');
    await prefs.remove('bridge_usage_seconds');
    core.actionHandler = StubActions();
    core.connection.devices.clear();
    UniversalBle.setInstance(FakeUniversalBlePlatform());
    FlutterLocalNotificationsPlatform.instance = _FakeLocalNotificationsPlatform();
    // No Pro, trial period over: the website build without Base, or a store
    // build past its trial.
    IAPManager.instance.setProForTesting(enabled: false);
    IAPManager.instance.trialExpiredForTesting = true;
    trainer = _trainer();
    core.connection.devices.add(trainer);
    addTearDown(() async {
      IAPManager.instance.trialExpiredForTesting = null;
      core.connection.devices.clear();
      await core.connection.stop();
    });
  });

  Future<BuildContext> pumpHost(WidgetTester tester, {Widget? child}) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(child: SizedBox(width: 400, child: child ?? const SizedBox())),
      ),
    );
    return tester.element(find.byType(Scaffold));
  }

  group('connectTrainerFromPicker', () {
    testWidgets('connects for virtual shifting after the trial period', (tester) async {
      final context = await pumpHost(tester);

      await tester.runAsync(() async {
        // Not awaited: a dialog would hold it open.
        unawaited(connectTrainerFromPicker(context, trainer));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(trainer.connectUpstreamCalls, 1, reason: 'the connect was started');
      expect(find.text(AppLocalizations.current.proFeature), findsNothing);
    });

    testWidgets('with today\'s budget used up, says so instead of connecting', (tester) async {
      await _useUpTodaysBudget();
      final context = await pumpHost(tester);

      await tester.runAsync(() async {
        unawaited(connectTrainerFromPicker(context, trainer));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(trainer.connectUpstreamCalls, 0);
      expect(find.text(AppLocalizations.current.bridgeTrialTimeOverTitle), findsOneWidget);
      expect(find.text(AppLocalizations.current.proFeature), findsNothing);
      // Still offers Pro.
      expect(find.text(AppLocalizations.current.goPro), findsOneWidget);
    });
  });

  group('ConnectionCard', () {
    testWidgets('virtual shifting connects after the trial period', (tester) async {
      await pumpHost(tester, child: ConnectionCard(device: trainer));
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.text(AppLocalizations.current.virtualShifting));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(trainer.connectUpstreamCalls, 1);
      expect(find.text(AppLocalizations.current.proFeature), findsNothing);
    });

    testWidgets('proxy mode still asks for Pro after the trial period', (tester) async {
      await pumpHost(tester, child: ConnectionCard(device: trainer));
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.text(AppLocalizations.current.proxyMode));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(trainer.connectUpstreamCalls, 0);
      expect(find.text(AppLocalizations.current.proFeature), findsOneWidget);
    });
  });

  group('startProxy (auto-connect)', () {
    test('lets virtual shifting through after the trial period', () async {
      trainer.setRetrofitMode(RetrofitMode.wifi);
      await core.settings.setAutoConnect(trainer.trainerKey, true);

      await expectLater(trainer.startProxy(), throwsStateError);

      expect(trainer.connectUpstreamCalls, 1);
    });

    test('refuses proxy mode after the trial period and stops auto-connecting', () async {
      trainer.setRetrofitMode(RetrofitMode.proxy);
      await core.settings.setAutoConnect(trainer.trainerKey, true);

      await trainer.startProxy();

      expect(trainer.connectUpstreamCalls, 0);
      expect(core.settings.getAutoConnect(trainer.trainerKey), isFalse);
    });
  });
}
