@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:bike_control/bluetooth/devices/zwift/constants.dart' show ZwiftDeviceType;
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_play.dart';
import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/pages/onboarding/onboarding_models.dart';
import 'package:bike_control/pages/onboarding/onboarding_page.dart';
import 'package:bike_control/pages/onboarding/steps/step_controller.dart';
import 'package:bike_control/pages/onboarding/steps/step_done.dart';
import 'package:bike_control/pages/paywall.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/home/your_buttons.dart' show ControllerPress;
import 'package:bike_control/widgets/overlay/trainer_overlay_view.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/utils/prefs.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../widget_snapshot.dart';

/// Renders the phase-5 surfaces at the mocks' sizes: button mapping (phone
/// and iPad master–detail), onboarding step 3 and done, the paywall and the
/// overlay. Run:
/// `P5_SHOTS=/tmp/p5 flutter test --run-skipped test/pages/phase5_snapshot_test.dart`
Future<void> main() async {
  await ensureSnapshotHarness();
  final outDir = Platform.environment['P5_SHOTS'] ?? 'build/snapshots';

  final controller = ZwiftClickV2(BleDevice(name: 'Zwift Click', deviceId: 'p5-click'))
    ..firmwareVersion = '1.2.0'
    ..isConnected = true
    ..rssi = -51
    ..batteryLevel = 81;

  // Button mapping renders the real page (not a store render, which
  // anonymises the trainer app in some places and not others): a Zwift Play
  // with MyWhoosh receiving over the network, so its built-in actions are live.
  final play =
      ZwiftPlay(
          BleDevice(name: 'Zwift Play', deviceId: 'p5-play'),
          deviceType: ZwiftDeviceType.playRight,
        )
        ..firmwareVersion = '1.3.1'
        ..isConnected = true
        ..rssi = -51
        ..batteryLevel = 81;
  void realMappingPage() {
    screenshotMode = false;
    addTearDown(() => screenshotMode = true);
    core.connection.devices
      ..clear()
      ..add(play);
    core.settings.setObpMdnsEnabled(true);
    core.obpMdnsEmulator.isStarted.value = true;
    core.obpMdnsEmulator.isConnected.value = true;
    addTearDown(() {
      core.settings.setObpMdnsEnabled(false);
      core.obpMdnsEmulator.isStarted.value = false;
      core.obpMdnsEmulator.isConnected.value = false;
    });
  }

  setUp(() async {
    core.connection.devices
      ..clear()
      ..add(controller);
    core.settings.setTrainerApp(MyWhoosh());
    core.settings.setKeyMap(MyWhoosh());
    core.actionHandler.init(MyWhoosh());
    await core.settings.setClickV2OnboardingDone(true);
    propPrefs.setZwiftClickV2LastUnlock(controller.scanResult.deviceId, DateTime.now());
  });

  Future<void> shoot(
    WidgetTester tester, {
    required String name,
    required Size size,
    required Brightness brightness,
    required Widget Function(BuildContext) build,
    Color? background,
    List<String> locales = const ['en'],
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
      background: background,
      outputDir: outDir,
      locales: locales,
      beforeCapture: beforeCapture,
      builder: build,
    );
  }

  const phone = Size(390, 844);
  testWidgets('warm-up', (tester) async {
    await shoot(
      tester,
      name: 'warm-up',
      size: phone,
      brightness: Brightness.dark,
      build: (_) => ControllerSettingsPage(device: controller),
    );
  });

  final plus = controller.availableButtons.firstWhere(
    (b) => b.action == InGameAction.shiftUp,
    orElse: () => controller.availableButtons.first,
  );

  for (final brightness in Brightness.values) {
    final theme = brightness.name;

    testWidgets('mapping-390x844-$theme', (tester) async {
      realMappingPage();
      await shoot(
        tester,
        name: 'mapping-390x844-$theme',
        size: phone,
        brightness: brightness,
        build: (_) => ControllerSettingsPage(device: play),
      );
    });

    testWidgets('onboarding-step3-390x844-$theme', (tester) async {
      final presses = ValueNotifier<ControllerPress>((button: plus, generation: 1));
      await shoot(
        tester,
        name: 'onboarding-step3-390x844-$theme',
        size: phone,
        brightness: brightness,
        build: (c) => Scaffold(
          child: onboardingShell(
            c,
            step: OnboardingStep.controller,
            body: onboardingControllerBody(
              c,
              phase: ControllerPhase.list,
              devices: [controller],
              appName: 'MyWhoosh',
              presses: {controller.uniqueId: presses},
            ),
            footerActions: [
              PrimaryButton(onPressed: () {}, child: Text(c.i18n.onboardingContinue)),
            ],
            onBack: () {},
            onHelp: () {},
            onSelectStep: (_) {},
            stepValues: const {OnboardingStep.app: 'MyWhoosh', OnboardingStep.where: 'This device'},
          ),
        ),
      );
    });

    testWidgets('onboarding-done-390x844-$theme', (tester) async {
      await shoot(
        tester,
        name: 'onboarding-done-390x844-$theme',
        size: phone,
        brightness: brightness,
        build: (c) => Scaffold(
          child: onboardingShell(
            c,
            step: OnboardingStep.done,
            body: onboardingDoneBody(
              c,
              app: MyWhoosh(),
              controllerName: 'Zwift Click',
              trainerName: 'KICKR CORE',
              appConnected: true,
              trainerAppConnected: true,
              reduceMotion: true,
              showTestMode: true,
            ),
            footerActions: onboardingDoneFooter(
              c,
              state: OnboardingDoneState.ready,
              showPlanOptions: true,
              onStartRiding: () {},
              onSeePlanOptions: () {},
            ),
            onHelp: () {},
          ),
        ),
      );
    });

    testWidgets('paywall-390x844-$theme', (tester) async {
      IAPManager.instance.isPurchased.value = false;
      addTearDown(() => IAPManager.instance.isPurchased.value = true);
      await shoot(
        tester,
        name: 'paywall-390x844-$theme',
        size: phone,
        brightness: brightness,
        build: (_) => const Paywall(debugYearlyStorePrice: '24,99 €'),
      );
    });

    testWidgets('overlay-$theme', (tester) async {
      await shoot(
        tester,
        name: 'overlay-$theme',
        size: const Size(390, 180),
        brightness: brightness,
        // A stand-in for the trainer app behind the overlay.
        background: const Color(0xFF4F6247),
        build: (_) => Center(
          child: TrainerOverlayView(
            state: ValueNotifier(
              const TrainerOverlayState(
                gear: 12,
                maxGear: 24,
                gearRatio: 2.4,
                mode: TrainerMode.simMode,
                powerW: 250,
                cadenceRpm: 90,
                ergTargetW: null,
                fields: {OverlayField.controls, OverlayField.cadence, OverlayField.gearRatio},
              ),
            ),
            onPrimaryDecrement: () {},
            onPrimaryIncrement: () {},
          ),
        ),
      );
    });
  }

  // A controller still in beta: its neutral BETA badge on the card, and the
  // Click V2 unlock status inside it.
  for (final brightness in Brightness.values) {
    final name = 'mapping-beta-390x844-${brightness.name}';
    testWidgets(name, (tester) async {
      screenshotMode = false;
      addTearDown(() => screenshotMode = true);
      await shoot(
        tester,
        name: name,
        size: phone,
        brightness: brightness,
        build: (_) => ControllerSettingsPage(device: controller),
      );
      expect(controller.isBeta, isTrue);
      expect(find.text('BETA'), findsWidgets);
    });
  }

  // iPad portrait (below the master–detail width: one list), both themes.
  for (final brightness in Brightness.values) {
    final name = 'mapping-820x1180-${brightness.name}';
    testWidgets(name, (tester) async {
      realMappingPage();
      await shoot(
        tester,
        name: name,
        size: const Size(820, 1180),
        brightness: brightness,
        build: (_) => ControllerSettingsPage(device: play),
      );
    });
  }

  // Both large sizes: a tablet in landscape and a laptop window.
  for (final size in const [Size(1180, 820), Size(1280, 800)]) {
    final name = 'mapping-${size.width.toInt()}x${size.height.toInt()}-dark';
    testWidgets(name, (tester) async {
      realMappingPage();
      await shoot(
        tester,
        name: name,
        size: size,
        brightness: Brightness.dark,
        build: (_) => ControllerSettingsPage(device: play),
      );
    });
  }

  // German, where the owner rides: the vibration switch row above Reset in
  // the actions group, phone width, both themes.
  for (final brightness in Brightness.values) {
    final name = 'mapping-actions-390x844-${brightness.name}-de';
    testWidgets(name, (tester) async {
      realMappingPage();
      await shoot(
        tester,
        name: name,
        size: phone,
        brightness: brightness,
        locales: const ['de'],
        build: (_) => ControllerSettingsPage(device: play),
        beforeCapture: (tester) async {
          final reset = find.byKey(const ValueKey('controller-vibration'));
          await tester.ensureVisible(reset);
          await tester.pump(const Duration(milliseconds: 300));
        },
      );
    });
  }

  // A laptop window with the mouse over the long-press trigger card: the
  // hover wash the rows and cards share.
  testWidgets('mapping-1280x800-dark-hover', (tester) async {
    realMappingPage();
    await shoot(
      tester,
      name: 'mapping-1280x800-dark-hover',
      size: const Size(1280, 800),
      brightness: Brightness.dark,
      locales: const ['de'],
      build: (_) => ControllerSettingsPage(device: play),
      beforeCapture: (tester) async {
        FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
        addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('mapping-trigger-card-longPress'))));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
      },
    );
  });
}
