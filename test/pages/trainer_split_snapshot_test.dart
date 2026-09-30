@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/pages/navigation.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratios_editor_page.dart';
import 'package:bike_control/pages/settings/overlay_settings_page.dart';
import 'package:bike_control/pages/settings/virtual_shifting_settings_page.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter/services.dart' show StandardMessageCodec;
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/transporter/network_transporter.dart';
import 'package:prop/utils/prefs.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../helpers/fake_overlay_controller.dart';
import '../helpers/shell_harness.dart';
import '../widget_snapshot.dart';

/// Renders the dissolved Smart Trainer page's new homes at 390×844, dark and
/// light: Ride with the overlay off and on, the trainer's hardware page,
/// Settings, Settings → Virtual shifting (scrolled so the drivetrain and Gears
/// share the screen), Per-gear ratios and Settings → Overlay. Run:
/// `TS_SHOTS=.impeccable/review flutter test --run-skipped test/pages/trainer_split_snapshot_test.dart`
/// Output: `$TS_SHOTS` (default `build/snapshots`), `trainer-<surface>-<theme>.png`.
Future<void> main() async {
  await ensureSnapshotHarness();
  quietShellEnvironment();
  final outDir = Platform.environment['TS_SHOTS'] ?? 'build/snapshots';

  final controller = ZwiftClickV2(BleDevice(name: 'Zwift Click', deviceId: 'ts-shot-click'))
    ..firmwareVersion = '1.2.0'
    ..isConnected = true
    ..rssi = -51
    ..batteryLevel = 81;
  final proxy =
      ProxyDevice(
          BleDevice(
            name: 'KICKR CORE',
            deviceId: 'ts-shot-kickr',
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
  final overlay = FakeOverlayController();

  setUp(() async {
    screenshotMode = false;
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
    proxy.debugSetTrainerAppConnected(true);
    proxy.debugAttachFitnessBike(definition);
    TrainerOverlayService.setForTest(overlay);
    TrainerOverlayService.debugSupportedPlatform = true;
    debugHostPlatformOverride = TargetPlatform.iOS;
    await core.settings.setOverlayFields({OverlayField.gearRatio, OverlayField.controls});
    await core.settings.setOverlayDeclined(false);
    // Answered once and switched off since (the Live Activity's "stop ride"
    // does that at every ride end): Ride reads Ready and offers it again.
    await core.settings.setOverlayAnswered(true);
    await core.settings.setOverlayEnabled(false);
    await overlay.hide();
    await core.shiftingConfigs.upsert(
      core.shiftingConfigs.activeFor(proxy.trainerKey).copyWith(frontShiftEnabled: true),
    );
    definition.setFrontShiftEnabled(true);
  });

  tearDown(() {
    screenshotMode = true;
    debugHostPlatformOverride = null;
    TrainerOverlayService.debugSupportedPlatform = null;
  });

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
    (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
  );

  Future<void> shoot(WidgetTester tester, String name, Brightness brightness, Widget Function() build) async {
    await captureWidget(
      tester,
      name: 'trainer-$name-${brightness.name}',
      width: 390,
      height: 844,
      padding: EdgeInsets.zero,
      pixelRatio: 2,
      brightness: brightness,
      settle: false,
      outputDir: outDir,
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: build(),
      ),
    );
    await disposeShell(tester);
  }

  testWidgets('warm-up', (tester) async {
    await shoot(tester, 'warm-up', Brightness.dark, () => const Navigation());
  });

  for (final brightness in Brightness.values) {
    final theme = brightness.name;

    testWidgets('ride-overlay-off-$theme', (tester) async {
      await shoot(tester, 'ride-overlay-off', brightness, () => const Navigation());
    });

    testWidgets('ride-overlay-on-$theme', (tester) async {
      await core.settings.setOverlayEnabled(true);
      await shoot(tester, 'ride-overlay-on', brightness, () => const Navigation());
    });

    testWidgets('hardware-$theme', (tester) async {
      await shoot(tester, 'hardware', brightness, () => ProxyDeviceDetailsPage(device: proxy));
    });

    testWidgets('settings-$theme', (tester) async {
      await core.settings.setOverlayEnabled(true);
      await shoot(tester, 'settings', brightness, () => const Navigation(initialSection: AppSection.settings));
    });

    testWidgets('vs-$theme', (tester) async {
      await shoot(
        tester,
        'vs',
        brightness,
        () => _ScrolledTo(
          target: const ValueKey('vs-drivetrain'),
          child: VirtualShiftingSettingsPage(definition: definition, device: proxy),
        ),
      );
    });

    testWidgets('vs-top-$theme', (tester) async {
      await shoot(tester, 'vs-top', brightness, () => VirtualShiftingSettingsPage(definition: definition, device: proxy));
    });

    testWidgets('per-gear-$theme', (tester) async {
      await shoot(tester, 'per-gear', brightness, () => PerGearRatiosPage(definition: definition, device: proxy));
    });

    testWidgets('overlay-$theme', (tester) async {
      await overlay.show(definition, core.settings.getOverlayFields());
      await shoot(tester, 'overlay', brightness, () => OverlaySettingsPage(device: proxy, definition: definition));
    });
  }
}

/// Scrolls [target] to the top of the page once it is laid out.
class _ScrolledTo extends StatefulWidget {
  const _ScrolledTo({required this.target, required this.child});

  final Key target;
  final Widget child;

  @override
  State<_ScrolledTo> createState() => _ScrolledToState();
}

class _ScrolledToState extends State<_ScrolledTo> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final element = find.byKey(widget.target).evaluate().firstOrNull;
      if (element != null) Scrollable.ensureVisible(element, alignment: 0.02);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
