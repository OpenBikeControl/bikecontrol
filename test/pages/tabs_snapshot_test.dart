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
import 'package:bike_control/pages/trainer_connection_settings.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/ui/connection_method.dart' show ConnectionMethodType;
import 'package:flutter/services.dart' show StandardMessageCodec;
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/transporter/network_transporter.dart';
import 'package:prop/prop.dart' show LogLevel;
import 'package:prop/utils/prefs.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../helpers/shell_harness.dart';
import '../widget_snapshot.dart';

/// Renders Devices, Activity, Settings and Connection settings mid-ride — a
/// bridged trainer in gear 12 of 24, a connected controller, MyWhoosh
/// receiving over the network — at the mocks' sizes. Run:
/// `TABS_SHOTS=/tmp/p4 flutter test --run-skipped test/pages/tabs_snapshot_test.dart`
/// Output: `$TABS_SHOTS` (default `build/snapshots`), `<tab>-<w>x<h>-<theme>.png`.
Future<void> main() async {
  await ensureSnapshotHarness();
  quietShellEnvironment();
  final outDir = Platform.environment['TABS_SHOTS'] ?? 'build/snapshots';

  final controller = ZwiftClickV2(BleDevice(name: 'Zwift Click', deviceId: 'tabs-shot-click'))
    ..firmwareVersion = '1.2.0'
    ..isConnected = true
    ..rssi = -51
    ..batteryLevel = 81;
  final proxy =
      ProxyDevice(
          BleDevice(
            name: 'KICKR CORE',
            deviceId: 'tabs-shot-kickr',
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
    await core.settings.setLastTarget(Target.thisDevice);
    core.actionHandler.init(MyWhoosh());
    await core.settings.setClickV2OnboardingDone(true);
    propPrefs.setZwiftClickV2LastUnlock(controller.scanResult.deviceId, DateTime.now());
    core.settings.setObpMdnsEnabled(true);
    core.obpMdnsEmulator.isStarted.value = true;
    core.obpMdnsEmulator.isConnected.value = true;
    await core.settings.addIgnoredDevice('tabs-shot-ignored-1', 'Neighbour Headwind');
    await core.settings.addIgnoredDevice('tabs-shot-ignored-2', 'Old remote');
    proxy.debugSetTrainerAppConnected(true);
    proxy.debugAttachFitnessBike(definition);
  });

  // With screenshot mode off the shell keeps the screen awake; the test host
  // has no wakelock plugin.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
    (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
  );

  tearDown(() {
    debugHostPlatformOverride = null;
    activityLogClock = DateTime.now;
  });

  /// A few minutes of a ride in the log: a connection earlier, then shifts, a
  /// press and a press with nothing assigned.
  Future<void> fillLog() async {
    final base = DateTime(2026, 9, 29, 10);
    Future<void> at(Duration ago, BaseNotification notification) async {
      activityLogClock = () => base.subtract(ago);
      core.connection.signalNotification(notification);
      await Future<void>.value();
      await Future<void>.value();
    }

    final plus = controller.availableButtons.firstWhere(
      (b) => b.action == InGameAction.shiftUp,
      orElse: () => controller.availableButtons.first,
    );
    final minus = controller.availableButtons.firstWhere(
      (b) => b.action == InGameAction.shiftDown,
      orElse: () => controller.availableButtons.last,
    );
    await at(
      const Duration(minutes: 3),
      AlertNotification(LogLevel.LOGLEVEL_INFO, 'Connected to MyWhoosh', connectionType: ConnectionMethodType.network),
    );
    await at(const Duration(seconds: 44), ActionNotification(Success('Shifted down to gear 10', button: minus)));
    await at(
      const Duration(seconds: 31),
      ActionNotification(
        Error('Could not perform Z: No action assigned', button: plus, type: ErrorType.noActionAssigned),
      ),
    );
    await at(const Duration(seconds: 6), ActionNotification(Success('Shifted up to gear 11', button: plus)));
    await at(Duration.zero, ActionNotification(Success('Shifted up to gear 12', button: plus)));
    activityLogClock = () => base;
  }

  Future<void> shoot(
    WidgetTester tester, {
    required String name,
    required Size size,
    required Brightness brightness,
    required Widget Function() build,
    Future<void> Function()? after,
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
      builder: (context) => Builder(
        builder: (context) {
          if (after != null) WidgetsBinding.instance.addPostFrameCallback((_) => after());
          return build();
        },
      ),
    );
    await disposeShell(tester);
  }

  const phone = Size(390, 844);
  // The first capture of a run can miss the display face's fonts; this one
  // is thrown away.
  testWidgets('warm-up', (tester) async {
    await shoot(
      tester,
      name: 'warm-up',
      size: phone,
      brightness: Brightness.dark,
      build: () => const Navigation(initialSection: AppSection.devices),
    );
  });

  for (final brightness in Brightness.values) {
    final theme = brightness.name;
    testWidgets('devices-390x844-$theme', (tester) async {
      debugHostPlatformOverride = TargetPlatform.iOS;
      await shoot(
        tester,
        name: 'devices-390x844-$theme',
        size: phone,
        brightness: brightness,
        build: () => const Navigation(initialSection: AppSection.devices),
      );
    });

    testWidgets('activity-390x844-$theme', (tester) async {
      await shoot(
        tester,
        name: 'activity-390x844-$theme',
        size: phone,
        brightness: brightness,
        // Entries land at once rather than mid-animation.
        build: () => Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const Navigation(initialSection: AppSection.activity),
          ),
        ),
        after: fillLog,
      );
    });

    testWidgets('settings-390x844-$theme', (tester) async {
      debugHostPlatformOverride = TargetPlatform.iOS;
      // The plan card's daily meter stays out of store renders.
      screenshotMode = false;
      addTearDown(() => screenshotMode = true);
      await shoot(
        tester,
        name: 'settings-390x844-$theme',
        size: phone,
        brightness: brightness,
        build: () => const Navigation(initialSection: AppSection.settings),
      );
    });

    testWidgets('connection-390x844-$theme', (tester) async {
      await shoot(
        tester,
        name: 'connection-390x844-$theme',
        size: phone,
        brightness: brightness,
        build: () => const TrainerConnectionSettingsPage(),
      );
    });
  }

  testWidgets('settings-1280x800-dark', (tester) async {
    screenshotMode = false;
    addTearDown(() => screenshotMode = true);
    await shoot(
      tester,
      name: 'settings-1280x800-dark',
      size: const Size(1280, 800),
      brightness: Brightness.dark,
      build: () => const Navigation(initialSection: AppSection.settings),
    );
  });
}
