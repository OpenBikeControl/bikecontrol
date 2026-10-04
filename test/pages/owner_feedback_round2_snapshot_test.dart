@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_play.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/pages/changelog_page.dart';
import 'package:bike_control/pages/navigation.dart';
import 'package:bike_control/pages/onboarding/onboarding_models.dart';
import 'package:bike_control/pages/onboarding/onboarding_page.dart';
import 'package:bike_control/pages/onboarding/steps/step_trainer.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/pages/proxy_device_details/mini_workout_card.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:bike_control/models/changelog.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/changelog_dialog.dart';
import 'package:flutter/services.dart' show StandardMessageCodec;
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/dircon_emulator.dart' show RetrofitMode;
import 'package:prop/emulators/transporter/network_transporter.dart';
import 'package:prop/utils/prefs.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../helpers/fake_overlay_controller.dart';
import '../helpers/shell_harness.dart';
import '../widget_snapshot.dart';

/// Renders the second owner-feedback round: Record Activity, the shifting
/// card's settings line and SIM | ERG, the banner with an absent Click V2
/// beside a working Zwift Play, Devices' new buttons, the trainer page's open
/// connection choice, the changelog and What's new, and the onboarding's
/// found-trainer card. German. Run:
/// `OF_SHOTS=.impeccable/review flutter test --run-skipped test/pages/owner_feedback_round2_snapshot_test.dart`
Future<void> main() async {
  await ensureSnapshotHarness();
  quietShellEnvironment();
  final outDir = Platform.environment['OF_SHOTS'] ?? 'build/snapshots';

  final click = ZwiftClickV2(BleDevice(name: 'Zwift Click', deviceId: 'of2-click'))
    ..firmwareVersion = '1.2.0'
    ..isConnected = true
    ..rssi = -51
    ..batteryLevel = 81;
  final play =
      ZwiftPlay(
          BleDevice(name: 'Zwift Play', deviceId: 'of2-play'),
          deviceType: ZwiftDeviceType.playLeft,
        )
        ..isConnected = true
        ..rssi = -55
        ..batteryLevel = 64;
  final proxy =
      ProxyDevice(
          BleDevice(
            name: 'KICKR CORE',
            deviceId: 'of2-kickr',
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

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
    (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
  );

  final changelog = File('CHANGELOG.md').readAsStringSync();

  /// Mid-ride: the Click V2 and the trainer connected, MyWhoosh receiving,
  /// the gear overlay on.
  Future<void> ready() async {
    core.connection.devices
      ..clear()
      ..addAll([click, proxy]);
    core.connection.hasDevices.value = true;
    core.settings.setTrainerApp(MyWhoosh());
    core.settings.setKeyMap(MyWhoosh());
    await core.settings.setLastTarget(Target.thisDevice);
    core.actionHandler.init(MyWhoosh());
    await core.settings.setClickV2OnboardingDone(true);
    propPrefs.setZwiftClickV2LastUnlock(click.scanResult.deviceId, DateTime.now());
    core.settings.setObpMdnsEnabled(true);
    core.obpMdnsEmulator.isStarted.value = true;
    core.obpMdnsEmulator.isConnected.value = true;
    proxy.isConnected = true;
    proxy.debugSetTrainerAppConnected(true);
    proxy.debugAttachFitnessBike(definition);
    TrainerOverlayService.setForTest(FakeOverlayController());
    TrainerOverlayService.debugSupportedPlatform = true;
    await core.settings.setOverlayEnabled(true);
    ChangelogSource.debugBundled = () async => changelog;
    ChangelogSource.debugCurrentVersion = '7.0.0';
  }

  setUp(ready);
  tearDown(() {
    debugHostPlatformOverride = null;
    screenshotMode = true;
    core.connection.debugForgetOfflineControllers();
    TrainerOverlayService.resetForTest();
    TrainerOverlayService.debugSupportedPlatform = null;
    ChangelogSource.debugBundled = null;
    ChangelogSource.debugCurrentVersion = null;
    if (definition.trainerMode.value == TrainerMode.ergMode) definition.exitErgMode();
  });

  Future<void> shoot(
    WidgetTester tester, {
    required String name,
    required Size size,
    required Brightness brightness,
    required Widget Function(BuildContext) build,
    Future<void> Function(WidgetTester tester)? beforeCapture,
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
      beforeCapture: beforeCapture,
      builder: build,
    );
    await disposeShell(tester);
  }

  const phone = Size(390, 844);
  const desktop = Size(1280, 800);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('warm-up', (tester) async {
    await shoot(
      tester,
      name: 'of2-warm-up',
      size: phone,
      brightness: Brightness.dark,
      build: (_) => const Navigation(),
    );
  });

  for (final brightness in Brightness.values) {
    final b = brightness.name;

    // ── Ride: the shifting card with its settings and overlay lines ────
    testWidgets('of2-ride-vs-390x844-$b', (tester) async {
      // Real app: the overlay's line shows (store renders leave it out).
      screenshotMode = false;
      await shoot(
        tester,
        name: 'of2-ride-vs-390x844-$b',
        size: phone,
        brightness: brightness,
        build: (_) => const Navigation(),
      );
    });

    // ── Ride: Record Activity under Your buttons ──────────────────────
    testWidgets('of2-ride-record-390x844-$b', (tester) async {
      await shoot(
        tester,
        name: 'of2-ride-record-390x844-$b',
        size: phone,
        brightness: brightness,
        build: (_) => const Navigation(),
        beforeCapture: (tester) async {
          await tester.ensureVisible(find.byType(MiniWorkoutCard));
          await settle(tester);
        },
      );
    });

    // ── Ride: an absent Click V2 beside a working Zwift Play ──────────
    testWidgets('of2-ride-absent-click-390x844-$b', (tester) async {
      core.connection.devices
        ..clear()
        ..addAll([play, proxy]);
      core.connection.debugRememberController(
        ZwiftClickV2(BleDevice(name: 'Zwift Click', deviceId: 'of2-click-away')),
      );
      core.actionHandler.init(MyWhoosh());
      await shoot(
        tester,
        name: 'of2-ride-absent-click-390x844-$b',
        size: phone,
        brightness: brightness,
        build: (_) => const Navigation(),
      );
    });

    testWidgets('of2-devices-absent-click-390x844-$b', (tester) async {
      core.connection.devices
        ..clear()
        ..addAll([play, proxy]);
      core.connection.debugRememberController(
        ZwiftClickV2(BleDevice(name: 'Zwift Click', deviceId: 'of2-click-away')),
      );
      core.actionHandler.init(MyWhoosh());
      await shoot(
        tester,
        name: 'of2-devices-absent-click-390x844-$b',
        size: phone,
        brightness: brightness,
        build: (_) => const Navigation(initialSection: AppSection.devices),
      );
    });

    // ── Devices: a nearby trainer to connect, MyWhoosh waiting with its
    //    optional Local control step ──────────────────────────────────
    for (final scrollToApp in [false, true]) {
      testWidgets('of2-devices${scrollToApp ? '-app' : ''}-390x844-$b', (tester) async {
        debugHostPlatformOverride = TargetPlatform.android;
        final nearby = ProxyDevice(
          BleDevice(
            name: 'KICKR CORE 1EB7',
            deviceId: 'of2-kickr-nearby',
            services: [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
          ),
        );
        core.connection.devices
          ..clear()
          ..addAll([click, nearby]);
        core.obpMdnsEmulator.isConnected.value = false;
        core.settings.setLocalEnabled(false);
        await shoot(
          tester,
          name: 'of2-devices${scrollToApp ? '-app' : ''}-390x844-$b',
          size: phone,
          brightness: brightness,
          build: (_) => const Navigation(initialSection: AppSection.devices),
          beforeCapture: scrollToApp
              ? (tester) async {
                  await tester.ensureVisible(find.text(AppLocalizations.current.chainStepLocalControlAction));
                  await settle(tester);
                }
              : null,
        );
      });
    }

    // ── The trainer page: the connection choice, open ─────────────────
    testWidgets('of2-trainer-390x844-$b', (tester) async {
      screenshotMode = false;
      proxy.setRetrofitMode(RetrofitMode.wifi);
      addTearDown(() => proxy.setRetrofitMode(RetrofitMode.proxy));
      await shoot(
        tester,
        name: 'of2-trainer-390x844-$b',
        size: phone,
        brightness: brightness,
        build: (_) => ProxyDeviceDetailsPage(device: proxy),
      );
    });

    // ── Changelog and What's new ──────────────────────────────────────
    testWidgets('of2-changelog-390x844-$b', (tester) async {
      await shoot(
        tester,
        name: 'of2-changelog-390x844-$b',
        size: phone,
        brightness: brightness,
        build: (_) => const ChangelogPage(),
      );
    });

    testWidgets('of2-changelog-earlier-390x844-$b', (tester) async {
      await shoot(
        tester,
        name: 'of2-changelog-earlier-390x844-$b',
        size: phone,
        brightness: brightness,
        build: (_) => const ChangelogPage(),
        beforeCapture: (tester) async {
          final row = find.byKey(const ValueKey('changelog-6.6.0'));
          await tester.ensureVisible(row);
          await tester.tap(row);
          await settle(tester);
          await tester.ensureVisible(find.byKey(const ValueKey('changelog-earlier')));
          await settle(tester);
        },
      );
    });

    testWidgets('of2-whats-new-390x844-$b', (tester) async {
      final releases = releasesSince(parseChangelog(changelog), '6.5.0');
      await shoot(
        tester,
        name: 'of2-whats-new-390x844-$b',
        size: phone,
        brightness: brightness,
        build: (context) => ColoredBox(
          color: Theme.of(context).colorScheme.background,
          child: ChangelogDialog(releases: releases, currentVersion: '7.0.0'),
        ),
      );
    });

    // ── Onboarding: a found trainer ───────────────────────────────────
    testWidgets('of2-onboarding-trainer-390x844-$b', (tester) async {
      final found = ProxyDevice(BleDevice(deviceId: 'of2-found', name: 'KICKR CORE 1EB7'));
      await shoot(
        tester,
        name: 'of2-onboarding-trainer-390x844-$b',
        size: phone,
        brightness: brightness,
        build: (c) => onboardingShell(
          c,
          step: OnboardingStep.virtualShifting,
          body: onboardingTrainerBody(c, app: MyWhoosh(), trainers: [found], onPick: (_) {}, onRescan: () {}),
          footerActions: [
            GhostButton(onPressed: () {}, child: Text(AppLocalizations.of(c).onboardingLetAppHandleVs('MyWhoosh'))),
          ],
          onBack: () {},
          onHelp: () {},
          onClose: () {},
        ),
      );
    });
  }

  // ── SIM | ERG: ERG picked on the card ───────────────────────────────
  testWidgets('of2-ride-erg-390x844-dark', (tester) async {
    await shoot(
      tester,
      name: 'of2-ride-erg-390x844-dark',
      size: phone,
      brightness: Brightness.dark,
      build: (_) => const Navigation(),
      beforeCapture: (tester) async {
        await tester.tap(find.byKey(const ValueKey('ride-vs-mode-erg')));
        await settle(tester);
      },
    );
  });

  // ── Wide windows ────────────────────────────────────────────────────
  testWidgets('of2-trainer-1280x800-dark', (tester) async {
    screenshotMode = false;
    proxy.setRetrofitMode(RetrofitMode.wifi);
    addTearDown(() => proxy.setRetrofitMode(RetrofitMode.proxy));
    await shoot(
      tester,
      name: 'of2-trainer-1280x800-dark',
      size: desktop,
      brightness: Brightness.dark,
      build: (_) => ProxyDeviceDetailsPage(device: proxy),
    );
  });

  testWidgets('of2-changelog-1280x800-dark', (tester) async {
    await shoot(
      tester,
      name: 'of2-changelog-1280x800-dark',
      size: desktop,
      brightness: Brightness.dark,
      build: (_) => const ChangelogPage(),
    );
  });

  testWidgets('of2-whats-new-1280x800-dark', (tester) async {
    final releases = releasesSince(parseChangelog(changelog), '6.5.0');
    await shoot(
      tester,
      name: 'of2-whats-new-1280x800-dark',
      size: desktop,
      brightness: Brightness.dark,
      build: (context) => ColoredBox(
        color: Theme.of(context).colorScheme.background,
        child: ChangelogDialog(releases: releases, currentVersion: '7.0.0'),
      ),
    );
  });
}
