// The Devices tab: the setup chain as grouped rows (controllers, the smart
// trainer, the trainer app), then Share sensors, the other ways in and any
// accessories. Each row states its status and opens its own page.
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/pages/devices/devices_page.dart';
import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/pages/sensors/sensors_page.dart';
import 'package:bike_control/pages/trainer_connection_settings.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/requirements/multi.dart' show Target;
import 'package:bike_control/widgets/devices/chain_link_row.dart';
import 'package:bike_control/widgets/devices/trainer_metrics_strip.dart';
import 'package:bike_control/widgets/scan.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/transporter/network_transporter.dart';
import 'package:prop/utils/prefs.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../widget_snapshot.dart';

class _PushRecorder extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushed.add(route);
}

Future<void> _pumpDevices(WidgetTester tester, {List<NavigatorObserver> observers = const []}) async {
  tester.view.physicalSize = const Size(430, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ShadcnApp(
      localizationsDelegates: [
        ...ShadcnLocalizations.localizationsDelegates,
        const OtherLocalizationsDelegate(),
        AppLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      navigatorObservers: observers,
      theme: BkTheme.build(Brightness.dark),
      home: Scaffold(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DevicesPage(isMobile: true, onUpdate: () {}),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _row(ChainLinkKey key) =>
    find.byWidgetPredicate((w) => w is ChainLinkRow && w.link.key == key, description: 'ChainLinkRow(${key.name})');

Finder _inRow(ChainLinkKey key, Finder finder) => find.descendant(of: _row(key), matching: finder);

Future<void> main() async {
  await ensureSnapshotHarness();
  late AppLocalizations l;

  setUp(() async {
    l = AppLocalizations.current;
    core.appConnectionLatch.reset();
    core.settings.setTrainerApp(MyWhoosh());
    core.settings.setKeyMap(MyWhoosh());
    core.actionHandler.init(MyWhoosh());
    await core.settings.setSensorsOnlyMode(false);
  });

  tearDown(() {
    core.connection.devices.clear();
    core.connection.isScanning.value = false;
    debugHostPlatformOverride = null;
  });

  group('controllers', () {
    testWidgets('nothing paired: "Connect Controllers" opens the scan sheet', (tester) async {
      await _pumpDevices(tester);

      final connect = _inRow(ChainLinkKey.controller, find.text(l.connectControllers));
      expect(connect, findsOneWidget);
      expect(find.byType(ScanWidget), findsNothing);

      await tester.tap(connect);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ScanWidget), findsOneWidget);
      core.connection.isScanning.value = false;
    });

    testWidgets('a connected controller shows firmware, signal, status and battery, and opens its page', (
      tester,
    ) async {
      final click = ZwiftClickV2(BleDevice(name: 'Zwift Click', deviceId: 'devices-click'))
        ..firmwareVersion = '1.2.0'
        ..isConnected = true
        ..rssi = -51
        ..batteryLevel = 81;
      await core.settings.setClickV2OnboardingDone(true);
      propPrefs.setZwiftClickV2LastUnlock(click.scanResult.deviceId, DateTime.now());
      core.connection.devices.add(click);
      final recorder = _PushRecorder();
      await _pumpDevices(tester, observers: [recorder]);

      final row = find.byKey(ValueKey('devices-controller-${click.uniqueId}'));
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('FW 1.2.0 · ${l.devicesSignalGood}')), findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('81%')), findsOneWidget);
      // Adding another stays one tap away.
      expect(find.byKey(const ValueKey('devices-connect-controllers')), findsOneWidget);

      final before = recorder.pushed.length;
      await tester.tap(find.descendant(of: row, matching: find.text(click.displayName(tester.element(row)))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(recorder.pushed.length, before + 1);
      expect(find.byType(ControllerSettingsPage), findsOneWidget);
    });
  });

  group('smart trainer', () {
    ProxyDevice bridgedTrainer() {
      final proxy =
          ProxyDevice(
              BleDevice(
                name: 'KICKR CORE',
                deviceId: 'devices-kickr',
                services: [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
              ),
            )
            ..services = [BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [])]
            ..isConnected = true;
      final definition = FitnessBikeDefinition(
        connectedDevice: proxy.scanResult,
        connectedDeviceServices: proxy.services!,
        data: ValueNotifier(''),
      )..setDebugValues();
      proxy.emulator.debugSetTransporter(NetworkTransporter(definition: definition));
      proxy.debugSetTrainerAppConnected(true);
      proxy.debugAttachFitnessBike(definition);
      core.connection.devices.add(proxy);
      addTearDown(() {
        proxy.debugAttachFitnessBike(null);
        proxy.debugSetTrainerAppConnected(false);
      });
      return proxy;
    }

    testWidgets('bridged: says so and to which app, with the live numbers, and opens the trainer', (tester) async {
      final proxy = bridgedTrainer();
      final recorder = _PushRecorder();
      await _pumpDevices(tester, observers: [recorder]);

      expect(_inRow(ChainLinkKey.trainer, find.text(l.chainStatusBridged)), findsOneWidget);
      expect(_inRow(ChainLinkKey.trainer, find.text(l.devicesBridgedTo('MyWhoosh'))), findsOneWidget);
      final gear = _inRow(ChainLinkKey.trainer, find.byKey(trainerMetricGearKey));
      expect(gear, findsOneWidget);
      expect(
        find.descendant(of: gear, matching: find.textContaining('/ ${proxy.fitnessBike!.maxGear}', findRichText: true)),
        findsOneWidget,
      );

      await tester.tap(_inRow(ChainLinkKey.trainer, find.text(proxy.toString())));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ProxyDeviceDetailsPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('none: an invitation to connect one', (tester) async {
      await _pumpDevices(tester);
      expect(_inRow(ChainLinkKey.trainer, find.text(l.sensorsConnectTrainer)), findsOneWidget);
    });
  });

  testWidgets('the trainer app row names the app and opens Connection settings', (tester) async {
    await _pumpDevices(tester);

    expect(_inRow(ChainLinkKey.app, find.text('MyWhoosh')), findsOneWidget);
    await tester.tap(_inRow(ChainLinkKey.app, find.text('MyWhoosh')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TrainerConnectionSettingsPage), findsOneWidget);
  });

  testWidgets('the trainer app row offers its optional Local control step a button of its own', (tester) async {
    // Waiting for MyWhoosh is the step in front; "Add keyboard and mouse
    // actions" is the optional one behind it and still needs a way to act.
    debugHostPlatformOverride = TargetPlatform.macOS;
    await core.settings.setLastTarget(Target.thisDevice);
    core.settings.setLocalEnabled(false);
    core.settings.setObpMdnsEnabled(true);
    addTearDown(() => core.settings.setObpMdnsEnabled(false));
    await _pumpDevices(tester);

    expect(_inRow(ChainLinkKey.app, find.text(l.chainStepLocalControl)), findsOneWidget);
    final action = _inRow(ChainLinkKey.app, find.text(l.chainStepLocalControlAction));
    expect(action, findsOneWidget);
    final button = find.ancestor(of: action, matching: find.byWidgetPredicate((w) => w is Button));
    expect(tester.widget<Button>(button.first).onPressed, isNotNull);
  });

  testWidgets('Share sensors wears the PRO badge without Pro and opens the Sensors page', (tester) async {
    IAPManager.instance.setProForTesting(enabled: false);
    await _pumpDevices(tester);

    final row = find.byKey(const ValueKey('devices-share-sensors'));
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.byType(ProBadge)), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text(l.statusOff)), findsOneWidget);

    await tester.tap(row);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SensorsPage), findsOneWidget);
  });

  testWidgets('Other inputs: phone steering on a phone, the ignored devices with their count', (tester) async {
    debugHostPlatformOverride = TargetPlatform.android;
    await core.settings.addIgnoredDevice('x', 'Neighbour Headwind');
    await core.settings.addIgnoredDevice('y', 'Old remote');
    addTearDown(() async {
      await core.settings.removeIgnoredDevice('x');
      await core.settings.removeIgnoredDevice('y');
    });
    await _pumpDevices(tester);

    final section = find.byKey(const ValueKey('devices-other-inputs'));
    expect(find.descendant(of: section, matching: find.text(l.devicesPhoneSteering)), findsOneWidget);
    expect(find.descendant(of: section, matching: find.text(l.devicesMediaRemotes)), findsNothing);
    final ignored = find.byKey(const ValueKey('devices-ignored'));
    expect(find.descendant(of: ignored, matching: find.text('2')), findsOneWidget);
  });

  testWidgets('ride feedback, Health and Quit are no longer on Devices', (tester) async {
    debugHostPlatformOverride = TargetPlatform.android;
    await _pumpDevices(tester);

    expect(find.text(l.shiftFeedbackSound), findsNothing);
    expect(find.text(l.shiftFeedbackHaptics), findsNothing);
    expect(find.text(l.healthRideToggleTitle), findsNothing);
    expect(find.text(l.chainCloseAndQuit), findsNothing);
  });
}
