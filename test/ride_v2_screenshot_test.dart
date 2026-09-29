@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, navigatorKey, screenshotMode;
import 'package:bike_control/pages/click_v2_onboarding.dart';
import 'package:bike_control/pages/home/home_page.dart';
import 'package:bike_control/pages/support_chat/support_chat_page.dart';
import 'package:bike_control/pages/unlock.dart';
import 'package:bike_control/services/telemetry_snapshot.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/support/intake_options.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/zwift_ride_v2_unlock.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import 'widget_snapshot.dart';
import 'widget_to_png.dart';

/// The Zwift Ride V2 unlock flow, rendered to PNGs for review. Run:
/// `flutter test --run-skipped test/ride_v2_screenshot_test.dart`
/// Output: /tmp/ride-v2-shots/ (override with RIDE_V2_SHOTS).
Future<void> main() async {
  await ensureSnapshotHarness();
  await initializeDateFormatting();
  // The unlock status lines and the Ride V2 name are hidden in store renders.
  screenshotMode = false;
  await core.settings.setRideV2ExplainerShown(true);
  UniversalBle.setInstance(FakeUniversalBlePlatform());
  // A trainer app with a keymap, so the Ride's buttons are mapped and the
  // unlock step is the one left to do.
  core.actionHandler = StubActions();
  core.settings.setTrainerApp(MyWhoosh());
  core.settings.setKeyMap(MyWhoosh());

  final outDir = Platform.environment['RIDE_V2_SHOTS'] ?? '/tmp/ride-v2-shots';
  const phone = Size(390, 844);

  ZwiftRide rideV2() => ZwiftRide(BleDevice(deviceId: 'EF:12:34:56:78:9A', name: 'Zwift Ride'))
    ..firmwareVersion = '1.3.0'
    ..isConnected = true
    ..batteryLevel = 78
    ..rssi = -52;

  /// Renders a whole app (overlays and toasts included) at phone size.
  Future<void> shootApp(
    WidgetTester tester,
    String name,
    Widget home, {
    Brightness brightness = Brightness.light,
    Future<void> Function()? afterPump,
    bool settle = true,
  }) async {
    tester.view.physicalSize = phone * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await AppLocalizations.load(const Locale('en'));
    final key = GlobalKey();
    final app = RepaintBoundary(
      key: key,
      child: ShadcnApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        scaling: BkTheme.scaling,
        theme: snapshotTheme(Brightness.light),
        darkTheme: snapshotTheme(Brightness.dark),
        themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        materialTheme: m.ThemeData(),
        home: home,
      ),
    );
    await tester.pumpWidget(app);
    await tester.pump();
    await tester.loadAssets();
    await tester.binding.reassembleApplication();
    await remountWithLoadedFonts(tester, app);
    if (afterPump != null) await afterPump();
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.loadAssets();
    await tester.pump();
    await captureBoundaryToPng(tester, key, outputPath: '$outDir/$name.png');
  }

  /// The controller's device card, as the controller page shows it.
  Widget deviceCard(BuildContext context, ZwiftRide device) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.card,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Theme.of(context).colorScheme.border),
    ),
    child: device.showInformation(context, showFull: true),
  );

  testWidgets('0 Click V2 explainer, for comparison', (tester) async {
    await shootApp(tester, '0_clickv2_explainer', const ClickV2OnboardingPage(), settle: false);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('1 one-time explainer', (tester) async {
    for (final b in Brightness.values) {
      await shootApp(
        tester,
        b == Brightness.light ? '1_explainer' : '1_explainer_dark',
        ZwiftRideV2ExplainerPage(device: rideV2()),
        brightness: b,
      );
    }
  });

  testWidgets('2 home with the Ride V2 unlock step, locked', (tester) async {
    final ride = rideV2();
    core.connection.devices
      ..clear()
      ..add(ride);
    core.connection.hasDevices.value = true;
    core.actionHandler.init(MyWhoosh());
    await shootApp(
      tester,
      '2_home_locked',
      Scaffold(
        child: SingleChildScrollView(child: HomePage(isMobile: true, onUpdate: () {})),
      ),
      settle: false,
    );
    await tester.pumpWidget(const SizedBox());
    core.connection.devices.clear();
  });

  testWidgets('3/4/5 device card and unlock page', (tester) async {
    final ride = rideV2();
    core.connection.devices
      ..clear()
      ..add(ride);
    await captureWidget(
      tester,
      name: '3_device_card_locked',
      width: 390,
      outputDir: outDir,
      settle: false,
      builder: (context) => deviceCard(context, ride),
    );

    // The unlock page (bottom sheet) while BikeControl waits for Zwift.
    ftmsEmulator.isStarted.value = true;
    await captureWidget(
      tester,
      name: '4_unlock_page_locked',
      width: 390,
      outputDir: outDir,
      settle: false,
      builder: (context) => UnlockPage(device: ride),
    );
    // The same page for a Ride V2 that connected with its Zwift service
    // hidden: straight to the manual steps.
    final hidden = rideV2();
    await hidden.handleServices(const <BleService>[]);
    await captureWidget(
      tester,
      name: '4b_unlock_page_service_hidden',
      width: 390,
      outputDir: outDir,
      settle: false,
      builder: (context) => UnlockPage(device: hidden),
    );
    await tester.pumpWidget(const SizedBox());
    ftmsEmulator.isStarted.value = false;

    // Unlocked two hours ago: "unlocked until" lands about 22 hours out.
    propPrefs.setZwiftClickV2LastUnlock(
      ride.scanResult.deviceId,
      DateTime.now().subtract(const Duration(hours: 2)),
      keyPrefix: ride.unlockKeyPrefix,
    );
    for (final b in Brightness.values) {
      await captureWidget(
        tester,
        name: b == Brightness.light ? '5_device_card_unlocked' : '5_device_card_unlocked_dark',
        width: 390,
        outputDir: outDir,
        brightness: b,
        settle: false,
        builder: (context) => deviceCard(context, ride),
      );
    }
    await tester.pumpWidget(const SizedBox());
    core.connection.devices.clear();
  });

  testWidgets('6 locked toast', (tester) async {
    final ride = rideV2();
    // Connected with its Zwift service hidden: locked, whatever was stored.
    await ride.handleServices(const <BleService>[]);
    core.connection.devices
      ..clear()
      ..add(ride);
    core.connection.hasDevices.value = true;
    await shootApp(
      tester,
      '6_locked_toast',
      Scaffold(
        child: SingleChildScrollView(child: HomePage(isMobile: true, onUpdate: () {})),
      ),
      settle: false,
      afterPump: () async {
        showZwiftRideV2LockedToast(ride);
        await tester.pump(const Duration(milliseconds: 600));
      },
    );
    await tester.pumpWidget(const SizedBox());
    // Let the toast's own timer run out.
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('7 support with the Ride V2 lock intake', (tester) async {
    final ride = rideV2();
    await shootApp(
      tester,
      '7_support_intake',
      Builder(
        builder: (context) => SupportChatPage(
          initialText: AppLocalizations.of(context).rideV2SupportPrefill(ride.firmwareVersion!),
          initialIntake: rideV2LockIntake(ride),
          telemetryBuilder: () async => TelemetrySnapshot.general(freetext: 'Zwift Ride V2 firmware: 1.3.0'),
        ),
      ),
      settle: false,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
