@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/pages/navigation.dart';
import 'package:bike_control/pages/overview.dart' show activityLogClock;
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/transporter/network_transporter.dart';
import 'package:prop/utils/prefs.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../helpers/shell_harness.dart';
import '../widget_snapshot.dart';

/// Renders the brand touch-up (the brand band, the handlebar mark, Barlow
/// section titles, the blue icon tiles) in German, mid-ride: Ride, Devices
/// and Settings on a phone in both themes, and Ride on a laptop. Run:
/// `TOUCHUP_SHOTS=.impeccable/review flutter test --run-skipped test/pages/touchup_snapshot_test.dart`
/// Output: `touchupB-<page>-<w>x<h>-<theme>.png`.
Future<void> main() async {
  await ensureSnapshotHarness();
  quietShellEnvironment();
  final outDir = Platform.environment['TOUCHUP_SHOTS'] ?? 'build/snapshots';

  final controller = ZwiftClickV2(BleDevice(name: 'Zwift Click', deviceId: 'touchup-click'))
    ..firmwareVersion = '1.2.0'
    ..isConnected = true
    ..rssi = -51
    ..batteryLevel = 81;
  final proxy =
      ProxyDevice(
          BleDevice(
            name: 'KICKR CORE',
            deviceId: 'touchup-kickr',
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
    core.connection.devices
      ..clear()
      ..addAll([controller, proxy]);
    core.connection.hasDevices.value = true;
    core.settings.setTrainerApp(MyWhoosh());
    core.settings.setKeyMap(MyWhoosh());
    core.actionHandler.init(MyWhoosh());
    await core.settings.setClickV2OnboardingDone(true);
    propPrefs.setZwiftClickV2LastUnlock(controller.scanResult.deviceId, DateTime.now());
    core.settings.setMyWhooshLinkEnabled(true);
    core.whooshLink.isConnected.value = true;
    core.settings.setObpMdnsEnabled(true);
    core.obpMdnsEmulator.isStarted.value = true;
    core.obpMdnsEmulator.isConnected.value = true;
    proxy.debugSetTrainerAppConnected(true);
    proxy.debugAttachFitnessBike(definition);
  });
  tearDown(() {
    activityLogClock = DateTime.now;
    screenshotMode = true;
    debugHostPlatformOverride = null;
  });

  Future<void> shoot(
    WidgetTester tester, {
    required String name,
    required Size size,
    required Brightness brightness,
    AppSection section = AppSection.ride,
  }) async {
    await captureWidget(
      tester,
      name: name,
      width: size.width,
      height: size.height,
      padding: EdgeInsets.zero,
      pixelRatio: 2,
      brightness: brightness,
      settle: false,
      outputDir: outDir,
      locales: const ['de'],
      builder: (context) => Builder(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final plus = controller.availableButtons.firstWhere(
              (b) => b.name.toLowerCase().contains('shiftup'),
              orElse: () => controller.availableButtons.first,
            );
            core.connection.signalNotification(ButtonNotification(device: controller, buttonsClicked: [plus]));
          });
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: Navigation(initialSection: section),
          );
        },
      ),
    );
    await disposeShell(tester);
  }

  const phone = Size(390, 844);
  testWidgets('warm-up', (tester) async {
    await shoot(tester, name: 'warm-up', size: phone, brightness: Brightness.dark);
  });

  for (final brightness in Brightness.values) {
    final theme = brightness.name;
    testWidgets('touchupB-ride-390x844-$theme', (tester) async {
      debugHostPlatformOverride = TargetPlatform.iOS;
      await shoot(tester, name: 'touchupB-ride-390x844-$theme', size: phone, brightness: brightness);
    });
    testWidgets('touchupB-devices-390x844-$theme', (tester) async {
      debugHostPlatformOverride = TargetPlatform.iOS;
      await shoot(
        tester,
        name: 'touchupB-devices-390x844-$theme',
        size: phone,
        brightness: brightness,
        section: AppSection.devices,
      );
    });
    testWidgets('touchupB-settings-390x844-$theme', (tester) async {
      debugHostPlatformOverride = TargetPlatform.iOS;
      // The plan card's daily meter stays out of store renders, not these.
      screenshotMode = false;
      await shoot(
        tester,
        name: 'touchupB-settings-390x844-$theme',
        size: phone,
        brightness: brightness,
        section: AppSection.settings,
      );
    });
  }

  // Ride's stacked shifting card (two columns from 840), where − gear + share
  // a row under the band.
  testWidgets('touchupB-ride-1180x820-light', (tester) async {
    debugHostPlatformOverride = TargetPlatform.iOS;
    screenshotMode = false;
    await shoot(
      tester,
      name: 'touchupB-ride-1180x820-light',
      size: const Size(1180, 820),
      brightness: Brightness.light,
    );
  });

  testWidgets('touchupB-ride-1280x800-dark', (tester) async {
    debugHostPlatformOverride = TargetPlatform.macOS;
    screenshotMode = false;
    await shoot(tester, name: 'touchupB-ride-1280x800-dark', size: const Size(1280, 800), brightness: Brightness.dark);
  });
}
