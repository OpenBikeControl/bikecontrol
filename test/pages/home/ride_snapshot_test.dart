@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/pages/navigation.dart';
import 'package:bike_control/pages/overview.dart' show activityLogClock;
import 'package:bike_control/utils/window_size.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/transporter/network_transporter.dart';
import 'package:prop/utils/prefs.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../helpers/activity_log_seed.dart';
import '../../helpers/shell_harness.dart';
import '../../widget_snapshot.dart';

/// Renders Ride mid-ride — a bridged trainer in gear 12 of 24 at 250 W and
/// 90 rpm, a connected two-pod controller, MyWhoosh receiving — at the
/// mocks' sizes. Run:
/// `flutter test --run-skipped test/pages/home/ride_snapshot_test.dart`
/// Output: `$RIDE_SHOTS` (default `build/snapshots`), `ride-<w>x<h>-<theme>.png`.
Future<void> main() async {
  await ensureSnapshotHarness();
  quietShellEnvironment();
  final outDir = Platform.environment['RIDE_SHOTS'] ?? 'build/snapshots';

  final controller = ZwiftClickV2(BleDevice(name: 'Zwift Click', deviceId: 'ride-shot-click'))
    ..firmwareVersion = '1.2.0'
    ..isConnected = true
    ..rssi = -51
    ..batteryLevel = 81;
  final proxy =
      ProxyDevice(
          BleDevice(
            name: 'KICKR CORE',
            deviceId: 'ride-shot-kickr',
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
    // MyWhoosh receiving over the network, so Ride reads "Ready to ride".
    core.settings.setObpMdnsEnabled(true);
    core.obpMdnsEmulator.isStarted.value = true;
    core.obpMdnsEmulator.isConnected.value = true;
    proxy.debugSetTrainerAppConnected(true);
    proxy.debugAttachFitnessBike(definition);
  });
  tearDown(() => activityLogClock = DateTime.now);

  // Phone, iPad portrait (top tabs, one wide column), iPad landscape, laptop.
  const sizes = [Size(390, 844), Size(820, 1180), Size(1180, 820), Size(1280, 800)];
  for (final size in sizes) {
    for (final brightness in Brightness.values) {
      if (size.width > 1000 && brightness == Brightness.light) continue;
      final name = 'ride-${size.width.toInt()}x${size.height.toInt()}-${brightness.name}';
      // From 840 Ride shows the latest-events preview under Your buttons.
      final showsLog = size.width >= Breakpoints.medium;
      testWidgets(name, (tester) async {
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
          builder: (context) => Builder(
            builder: (context) {
              // One press, so the last-press strip has something to say.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final plus = controller.availableButtons.firstWhere(
                  (b) => b.name.toLowerCase().contains('shiftup'),
                  orElse: () => controller.availableButtons.first,
                );
                core.connection.signalNotification(ButtonNotification(device: controller, buttonsClicked: [plus]));
              });
              if (!showsLog) return const Navigation();
              // Wide enough for the log beside Ride: the same few
              // minutes of a ride the Activity tab capture shows, landing at
              // once rather than mid-animation. Each mount gets a fresh log,
              // so the last mount's seed is the one captured.
              WidgetsBinding.instance.addPostFrameCallback((_) => seedRideActivityLog(controller));
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: const Navigation(),
              );
            },
          ),
        );
        await disposeShell(tester);
      });
    }
  }
}
