// MyWhoosh on another device also takes BikeControl over Bluetooth, so a
// network connection that won't come up gets Bluetooth offered instead.
import 'dart:io';

import 'package:bike_control/bluetooth/devices/openbikecontrol/obp_mdns_backend.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, debugKeepsTrainerAppNamesInScreenshotMode;
import 'package:bike_control/pages/network_troubleshooting_page.dart';
import 'package:bike_control/pages/onboarding/onboarding_methods.dart';
import 'package:bike_control/pages/onboarding/steps/step_connection.dart';
import 'package:bike_control/services/network_self_test/network_check.dart';
import 'package:bike_control/services/network_self_test/network_probe_context.dart';
import 'package:bike_control/services/network_self_test/network_self_test_engine.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

NetworkProbeContext _ctx() => NetworkProbeContext(
  snapshot: null,
  snapshotError: null,
  emulatorStarted: true,
  trainerAppConnected: false,
  trainerAppConnectedNow: () => false,
  trainerAppName: 'MyWhoosh',
  backend: ObpMdnsBackend.platformDefault,
  advertisedHostname: null,
  platform: 'macos',
  resolve: (host) async => const [],
  tcpProbe: (address, port) async {},
  runProcess: (executable, arguments) async => ProcessResult(0, 0, '', ''),
  queryLog: () => const [],
  sleep: (d) async {},
  now: () => DateTime(2026, 11, 20),
  onWatchProgress: (progress) {},
);

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await ensureSnapshotAppState();
    debugKeepsTrainerAppNamesInScreenshotMode = true;
  });
  tearDownAll(() => debugKeepsTrainerAppNamesInScreenshotMode = false);

  Future<void> state(SupportedApp app, {Target target = Target.otherDevice, bool bluetooth = false}) async {
    core.settings.setTrainerApp(app);
    await core.settings.setLastTarget(target);
    await core.settings.setObpMdnsEnabled(true);
    await core.settings.setZwiftMdnsEmulatorEnabled(true);
    await core.settings.setBc2BleEnabled(bluetooth);
  }

  tearDown(() async {
    core.actionHandler = StubActions();
    await core.settings.setObpMdnsEnabled(false);
    await core.settings.setZwiftMdnsEmulatorEnabled(false);
    await core.settings.setBc2BleEnabled(false);
  });

  Future<AppLocalizations> pump(WidgetTester tester, Widget Function(BuildContext) child) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Builder(builder: child),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    return AppLocalizations.of(tester.element(find.byType(Builder).last));
  }

  group('offered', () {
    test('MyWhoosh on another device, Bluetooth off', () async {
      await state(MyWhoosh());
      expect(offersBluetoothFallback(MyWhoosh()), isTrue);
    });
    test('not once Bluetooth is on', () async {
      await state(MyWhoosh(), bluetooth: true);
      expect(offersBluetoothFallback(MyWhoosh()), isFalse);
    });
    test('not with MyWhoosh on this device', () async {
      await state(MyWhoosh(), target: Target.thisDevice);
      expect(offersBluetoothFallback(MyWhoosh()), isFalse);
    });
    test('not for an app without the BC2 method', () async {
      await state(Rouvy());
      expect(offersBluetoothFallback(Rouvy()), isFalse);
    });
  });

  Widget tiles(BuildContext c) => Scaffold(
    child: SingleChildScrollView(
      child: Column(
        children: onboardingMethodTiles(c, app: core.settings.getTrainerApp()!, onUpdate: () {}),
      ),
    ),
  );

  testWidgets('onboarding: the waiting network tile offers Bluetooth', (tester) async {
    await state(MyWhoosh());
    final l = await pump(tester, tiles);
    expect(find.text(l.bluetoothFallbackAction), findsOneWidget);
  });

  testWidgets('onboarding: Rouvy\'s network tile does not', (tester) async {
    await state(Rouvy());
    final l = await pump(tester, tiles);
    expect(find.text(l.networkTroubleshootTroubleshoot), findsOneWidget, reason: 'precondition: waiting');
    expect(find.text(l.bluetoothFallbackAction), findsNothing);
  });

  testWidgets('troubleshooting: a finished run offers Bluetooth', (tester) async {
    await state(MyWhoosh());
    final engine = NetworkSelfTestEngine(
      contextBuilder: _ctx,
      probes: [
        ProbeSpec(
          id: NetworkCheckId.advertisedAddress,
          timeout: const Duration(seconds: 1),
          run: (ctx) async => const NetworkCheck(id: NetworkCheckId.advertisedAddress, verdict: NetworkVerdict.fail),
        ),
      ],
    );
    final l = await pump(tester, (_) => NetworkTroubleshootingPage(engineFactory: () => engine));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('network-bluetooth-fallback')), findsOneWidget);
    expect(find.text(l.bluetoothFallbackBody('MyWhoosh')), findsOneWidget);
  });
}
