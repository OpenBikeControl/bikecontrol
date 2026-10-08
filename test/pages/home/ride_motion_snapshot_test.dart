@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/models/remembered_device.dart';
import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/pages/navigation.dart';
import 'package:bike_control/pages/overview.dart' show activityLogClock;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/widgets/home/ready_banner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/transporter/network_transporter.dart';
import 'package:prop/utils/prefs.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../helpers/activity_log_seed.dart';
import '../../helpers/shell_harness.dart';
import '../../widget_snapshot.dart';
import '../../widget_to_png.dart';

/// Ride while things connect, in German, for review. Run:
/// `flutter test --run-skipped test/pages/home/ride_motion_snapshot_test.dart`
/// Output: `$RIDE_SHOTS` (default `build/snapshots`): `anim-*.png`.
Future<void> main() async {
  await ensureSnapshotHarness();
  quietShellEnvironment();
  final outDir = Platform.environment['RIDE_SHOTS'] ?? 'build/snapshots';

  final controller = ZwiftClickV2(BleDevice(name: 'Zwift Click', deviceId: 'anim-click'))
    ..firmwareVersion = '1.2.0'
    ..rssi = -51
    ..batteryLevel = 81;
  final proxy =
      ProxyDevice(
          BleDevice(
            name: 'KICKR CORE',
            deviceId: 'anim-kickr',
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

  setUp(() async {
    core.connection.devices.clear();
    core.settings.setTrainerApp(MyWhoosh());
    core.settings.setKeyMap(MyWhoosh());
    core.actionHandler.init(MyWhoosh());
    await core.settings.setClickV2OnboardingDone(true);
    propPrefs.setZwiftClickV2LastUnlock(controller.scanResult.deviceId, DateTime.now());
  });
  tearDown(() {
    activityLogClock = DateTime.now;
    core.connection.endStartupReconnect();
    core.connection.debugForgetOfflineControllers();
    core.connection.rememberedTrainer = null;
    proxy.debugAttachFitnessBike(null);
    proxy.debugSetTrainerAppConnected(false);
    core.obpMdnsEmulator.isConnected.value = false;
    core.obpMdnsEmulator.isStarted.value = false;
  });

  void live() {
    controller.isConnected = true;
    core.connection.devices.addAll([controller, proxy]);
    core.connection.hasDevices.value = true;
    core.settings.setObpMdnsEnabled(true);
    core.obpMdnsEmulator.isStarted.value = true;
    core.obpMdnsEmulator.isConnected.value = true;
    proxy.debugSetTrainerAppConnected(true);
    proxy.debugAttachFitnessBike(definition);
  }

  testWidgets('anim-startup-390x844-light', (tester) async {
    // Launch: the KICKR and the Click from last time, on their way back.
    controller.isConnected = false;
    core.connection.debugRememberController(controller);
    core.connection.rememberedTrainer = RememberedDevice(
      deviceId: 'anim-kickr',
      name: 'KICKR CORE',
      kind: RememberedDeviceKind.trainer,
      lastConnected: DateTime(2026, 10, 4),
    );
    await core.settings.setAutoConnect('KICKR CORE', true);
    core.connection.beginStartupReconnect();
    await captureWidget(
      tester,
      name: 'anim-startup-390x844-light',
      locales: const ['de'],
      width: 390,
      height: 844,
      padding: EdgeInsets.zero,
      pixelRatio: 2,
      settle: false,
      outputDir: outDir,
      builder: (context) => const Navigation(),
    );
    await disposeShell(tester);
  });

  testWidgets('anim-startup-390x844-light-scrolled', (tester) async {
    // Launch: the KICKR and the Click from last time, on their way back.
    controller.isConnected = false;
    core.connection.debugRememberController(controller);
    core.connection.rememberedTrainer = RememberedDevice(
      deviceId: 'anim-kickr',
      name: 'KICKR CORE',
      kind: RememberedDeviceKind.trainer,
      lastConnected: DateTime(2026, 10, 4),
    );
    await core.settings.setAutoConnect('KICKR CORE', true);
    core.connection.beginStartupReconnect();
    await captureWidget(
      tester,
      name: 'anim-startup-390x844-light-scrolled',
      locales: const ['de'],
      width: 390,
      height: 844,
      padding: EdgeInsets.zero,
      pixelRatio: 2,
      settle: false,
      outputDir: outDir,
      builder: (context) => const Navigation(),
      // Down to Your buttons: the Click's placeholder card.
      beforeCapture: (tester) async {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -520));
        await tester.pump(const Duration(milliseconds: 300));
      },
    );
    await disposeShell(tester);
  });

  testWidgets('anim-live-390x844-light', (tester) async {
    live();
    await captureWidget(
      tester,
      name: 'anim-live-390x844-light',
      locales: const ['de'],
      width: 390,
      height: 844,
      padding: EdgeInsets.zero,
      pixelRatio: 2,
      settle: false,
      outputDir: outDir,
      builder: (context) => const Navigation(),
    );
    await disposeShell(tester);
  });

  testWidgets('anim-1280x800-dark', (tester) async {
    live();
    await captureWidget(
      tester,
      name: 'anim-1280x800-dark',
      locales: const ['de'],
      width: 1280,
      height: 800,
      padding: EdgeInsets.zero,
      pixelRatio: 2,
      brightness: Brightness.dark,
      settle: false,
      outputDir: outDir,
      builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) => seedRideActivityLog(controller));
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: const Navigation(),
        );
      },
    );
    await disposeShell(tester);
  });

  testWidgets('anim-steps sequence', (tester) async {
    // The banner with one step, then a second turns up: four frames of it
    // growing in.
    const app = ReadyBannerStep(
      linkId: 'app',
      linkTitle: 'MyWhoosh',
      step: SetupStep(id: SetupStepId.appConnected, done: false),
    );
    const unlock = ReadyBannerStep(
      linkId: 'controller',
      linkTitle: 'Zwift Click',
      step: SetupStep(id: SetupStepId.controllerUnlocked, done: false),
    );
    ChainBanner banner(int n) => ChainBanner(
      kind: ChainBannerKind.pending,
      status: LinkStatus.attention,
      stepsLeft: n,
      targetLinkId: 'controller',
      targetKey: ChainLinkKey.controller,
      outstandingKeys: const [ChainLinkKey.controller, ChainLinkKey.app],
      outstandingLinkIds: const ['controller', 'app'],
    );
    final two = ValueNotifier(false);
    final key = GlobalKey();
    await captureWidget(
      tester,
      name: 'anim-steps-final',
      locales: const ['de'],
      width: 390,
      padding: const EdgeInsets.all(12),
      pixelRatio: 2,
      outputDir: outDir,
      builder: (context) => RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.background,
          child: SizedBox(
            height: 330,
            child: Align(
              alignment: Alignment.topCenter,
              child: ValueListenableBuilder<bool>(
                valueListenable: two,
                builder: (context, both, _) => ReadyBanner(
                  banner: banner(both ? 2 : 1),
                  brokenLinkName: null,
                  appName: 'MyWhoosh',
                  steps: both ? const [unlock, app] : const [app],
                ),
              ),
            ),
          ),
        ),
      ),
      beforeCapture: (tester) async {
        await captureBoundaryToPng(tester, key, outputPath: '$outDir/anim-steps-0.png', pixelRatio: 2);
        two.value = true;
        await tester.pump();
        for (var i = 1; i <= 3; i++) {
          // Real time under this binding: short steps land inside the 250 ms.
          await tester.pump(const Duration(milliseconds: 30));
          await captureBoundaryToPng(tester, key, outputPath: '$outDir/anim-steps-$i.png', pixelRatio: 2);
        }
        await tester.pumpAndSettle();
        await captureBoundaryToPng(tester, key, outputPath: '$outDir/anim-steps-4.png', pixelRatio: 2);
      },
    );
  });
}
