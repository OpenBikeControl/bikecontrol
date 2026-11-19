@Tags(['screenshots'])
library;

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/bluetooth/devices/sram/sram_axs.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_click.dart';
import 'package:bike_control/pages/onboarding/onboarding_models.dart';
import 'package:bike_control/pages/onboarding/onboarding_page.dart';
import 'package:bike_control/pages/onboarding/onboarding_sheets.dart';
import 'package:bike_control/pages/onboarding/steps/step_app.dart';
import 'package:bike_control/pages/onboarding/steps/step_connection.dart';
import 'package:bike_control/pages/onboarding/steps/step_controller.dart';
import 'package:bike_control/pages/onboarding/steps/step_done.dart';
import 'package:bike_control/pages/onboarding/steps/step_trainer.dart';
import 'package:bike_control/pages/onboarding/steps/step_welcome.dart';
import 'package:bike_control/pages/onboarding/steps/step_gear.dart';
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/pages/onboarding/widgets/vs_stage.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import 'widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  Widget shell(BuildContext context, {required OnboardingStep step}) => SizedBox(
        height: 720,
        child: onboardingShell(
          context,
          step: step,
          body: const Text('body placeholder'),
          footerActions: [PrimaryButton(onPressed: () {}, child: const Text('Continue'))],
          onBack: step == OnboardingStep.app ? null : () {},
          onHelp: () {},
          onSelectStep: (_) {},
        ),
      );

  testWidgets('shell mobile', (tester) async {
    await captureWidget(tester, name: 'onboarding_shell_mobile', width: 380,
        builder: (c) => shell(c, step: OnboardingStep.gear));
  });

  testWidgets('shell desktop', (tester) async {
    await captureWidget(tester, name: 'onboarding_shell_desktop', width: 1000,
        builder: (c) => shell(c, step: OnboardingStep.gear));
  });

  // Wrap a sheet body so it reads like the bottom sheet (surface + padding).
  Widget sheet(Widget body) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: body,
        ),
      );

  testWidgets('welcome', (tester) async {
    await captureWidget(tester, name: 'onboarding_welcome', width: 390, height: 800, locales: const ['de', 'en'],
        padding: EdgeInsets.zero,
        builder: (c) => SizedBox(height: 800, child: OnboardingWelcome(onStart: () {}, onLater: () {})));
  });

  testWidgets('help sheet', (tester) async {
    await captureWidget(tester, name: 'onboarding_help_sheet', width: 380,
        builder: (c) => sheet(onboardingHelpSheetBody(c, topic: OnboardingHelpTopic.controller, onClose: () {})));
  });

  testWidgets('permission denied sheet', (tester) async {
    await captureWidget(tester, name: 'onboarding_permission_denied_sheet', width: 380,
        builder: (c) => sheet(permissionDeniedSheetBody(c, onContinueAnyway: () {}, onAllow: () {})));
  });

  testWidgets('step app unselected', (tester) async {
    await captureWidget(tester, name: 'onboarding_step_app', width: 380,
        builder: (c) => onboardingAppBody(c, selected: null, onSelect: (_) {}));
  });

  testWidgets('step app selected', (tester) async {
    await captureWidget(tester, name: 'onboarding_step_app_selected', width: 380,
        builder: (c) => onboardingAppBody(
              c,
              selected: SupportedApp.supportedApps.first,
              onSelect: (_) {},
            ));
  });

  testWidgets('step app wide', (tester) async {
    await captureWidget(tester, name: 'onboarding_step_app_wide', width: 640,
        builder: (c) => onboardingAppBody(c, selected: null, onSelect: (_) {}));
  });

  // Step 1 with "runs on" under the grid.
  testWidgets('step app with target', (tester) async {
    await captureWidget(tester, name: 'onboarding_step_app_target', width: 380,
        builder: (c) => onboardingAppBody(
              c,
              selected: MyWhoosh(),
              onSelect: (_) {},
              targets: Target.values,
              selectedTarget: Target.otherDevice,
              onSelectTarget: (_) {},
            ));
  });

  // ── Step controller: permission / scanning / empty / list phases ──────────
  final connectedDevice = SramAxs(BleDevice(deviceId: 'snap', name: 'SRAM Rival AXS'))..isConnected = true;
  final connectingDevice = SramAxs(BleDevice(deviceId: 'snap-2', name: 'SRAM Force AXS'));

  testWidgets('step controller permission', (tester) async {
    await captureWidget(tester, name: 'onboarding_step_controller_permission', width: 380,
        builder: (c) => onboardingControllerBody(c, phase: ControllerPhase.permission, devices: const [], appName: 'Zwift'));
  });

  // The wifi scan animation loops forever — settle:false, like the SRAM
  // "running"/"authorize" stages in sram_states_snapshot_test.dart.
  testWidgets('step controller scanning', (tester) async {
    await captureWidget(tester, name: 'onboarding_step_controller_scanning', width: 380, settle: false,
        builder: (c) => onboardingControllerBody(c, phase: ControllerPhase.scanning, devices: const [], appName: 'Zwift'));
  });

  testWidgets('step controller empty', (tester) async {
    await captureWidget(tester, name: 'onboarding_step_controller_empty', width: 380,
        builder: (c) => onboardingControllerBody(c, phase: ControllerPhase.empty, devices: const [], appName: 'Zwift'));
  });

  // The "still scanning" spinner in the list phase is also infinite.
  testWidgets('step controller list', (tester) async {
    await captureWidget(tester, name: 'onboarding_step_controller_list', width: 380, settle: false,
        builder: (c) => onboardingControllerBody(
              c,
              phase: ControllerPhase.list,
              devices: [connectedDevice, connectingDevice],
              appName: 'Zwift',
            ));
  });

  // A connected device with a ControllerLayout renders its contour so the
  // rider sees the available buttons.
  testWidgets('step controller list with contour', (tester) async {
    final click = ZwiftClick(BleDevice(deviceId: 'click-snap', name: 'Zwift Click'))..isConnected = true;
    await captureWidget(tester, name: 'onboarding_step_controller_contour', width: 380, settle: false,
        builder: (c) => onboardingControllerBody(
              c,
              phase: ControllerPhase.list,
              devices: [click],
              appName: 'Zwift',
            ));
  });


  // ── Step 4: virtual shifting ────────────────────────────────────────────
  // The "nearby trainers" spinner is also infinite — settle:false, like the
  // other loading-state captures above.
  testWidgets('step trainer intro', (tester) async {
    await captureWidget(tester, name: 'onboarding_step_trainer', width: 380, settle: false,
        builder: (c) => onboardingTrainerBody(
              c,
              app: SupportedApp.supportedApps.first,
              trainers: const <ProxyDevice>[],
              onPick: (_) {},
            ));
  });

  // A trainer in range: the scan card lists it with its Connect affordance.
  testWidgets('step trainer with device', (tester) async {
    final trainer = ProxyDevice(BleDevice(deviceId: 'trainer-snap', name: 'KICKR CORE 1EB7'));
    await captureWidget(tester, name: 'onboarding_step_trainer_device', width: 380, settle: false,
        builder: (c) => onboardingTrainerBody(
              c,
              app: SupportedApp.supportedApps.first,
              trainers: [trainer],
              onPick: (_) {},
              onRescan: () {},
            ));
  });

  // The stage holds still under screenshotMode, so each scene is captured by
  // opening on it — that's also the only way to see scenes 2 and 3 at rest.
  for (final (i, name) in const [(0, 'apps'), (1, 'ratios'), (2, 'front'), (3, 'more')]) {
    testWidgets('vs stage scene $name', (tester) async {
      await captureWidget(tester, name: 'onboarding_vs_stage_$name', width: 380, settle: false,
          builder: (c) => VirtualShiftingStage(initialScene: i));
    });
  }

  // MyWhoosh + Android + same-device can't reach a network virtual bike.
  testWidgets('step trainer virtual shifting blocked', (tester) async {
    await captureWidget(tester, name: 'onboarding_step_trainer_blocked', width: 380,
        builder: (c) => onboardingTrainerBody(c,
            app: MyWhoosh(), trainers: const [], onPick: (_) {}, virtualShiftingBlocked: true));
  });

  // ── Step 2: controller + trainer on one screen ────────────────────────
  final gearClick = ZwiftClick(BleDevice(deviceId: 'gear-click', name: 'Zwift Click'))..isConnected = true;
  Widget gear(BuildContext c, {required List<ProxyDevice> trainers, List<ZwiftClick>? controllers}) => SizedBox(
        height: 800,
        child: onboardingShell(
          c,
          step: OnboardingStep.gear,
          body: onboardingGearBody(
            c,
            controllerPhase: ControllerPhase.list,
            controllers: controllers ?? [gearClick],
            app: MyWhoosh(),
            trainers: trainers,
            onPickTrainer: (_) {},
            onRescanTrainers: () {},
            vsDailyMinutesWithoutPro: 30,
          ),
          footerActions: [
            BkPillButton(
              onPressed: trainers.length == 1 ? () {} : null,
              child: Text(trainers.isEmpty
                  ? 'Looking for Smart Trainers…'
                  : trainers.single.isBridged
                  ? 'Continue'
                  : 'Connect ${trainers.single.name}'),
            ),
            if (trainers.isEmpty || !trainers.single.isBridged)
              GhostButton(onPressed: () {}, child: const Text('Let MyWhoosh handle virtual shifting')),
          ],
          onBack: () {},
          onHelp: () {},
        ),
      );

  testWidgets('step gear searching', (tester) async {
    await captureWidget(tester, name: 'onboarding_step_gear_searching', width: 390, settle: false,
        builder: (c) => gear(c, trainers: const []));
  });

  testWidgets('step gear no controller yet', (tester) async {
    await captureWidget(tester, name: 'onboarding_step_gear_no_controller', width: 390, settle: false,
        builder: (c) => gear(c, trainers: const [], controllers: const []));
  });

  testWidgets('step gear trainer found', (tester) async {
    final trainer = ProxyDevice(BleDevice(deviceId: 'gear-trainer', name: 'KICKR CORE 1EB7'));
    await captureWidget(tester, name: 'onboarding_step_gear_found', width: 390, settle: false,
        builder: (c) => gear(c, trainers: [trainer]));
  });

  testWidgets('step gear trainer connected', (tester) async {
    final trainer = ProxyDevice(BleDevice(deviceId: 'gear-trainer-2', name: 'KICKR CORE 1EB7'))
      ..debugSetTrainerAppConnected(true);
    trainer.debugAttachFitnessBike(
      FitnessBikeDefinition(
        connectedDevice: trainer.scanResult,
        connectedDeviceServices: const [],
        data: ValueNotifier(''),
      )
        ..setDebugValues()
        ..setMaxGear(24),
    );
    await captureWidget(tester, name: 'onboarding_step_gear_connected', width: 390, settle: false,
        builder: (c) => gear(c, trainers: [trainer]));
  });

  for (var i = 0; i < 4; i++) {
    testWidgets('flat vs stage scene $i', (tester) async {
      await captureWidget(tester, name: 'onboarding_vs_stage_flat_$i', width: 360, settle: false,
          builder: (c) => VirtualShiftingStage(initialScene: i, flat: true));
    });
  }

  // ── Step 3: waiting for the app, with the guide and the folded methods ─
  testWidgets('step ride waiting for app', (tester) async {
    await captureWidget(tester, name: 'onboarding_step_ride_waiting', width: 380, settle: false,
        builder: (c) => onboardingDoneBody(
              c,
              app: MyWhoosh(),
              controllerName: 'Zwift Click',
              trainerName: 'KICKR CORE',
              appConnected: false,
              trainerAppConnected: false,
              reduceMotion: true,
              showTestMode: true,
              connectionMethods: OnboardingMethodsDisclosure(app: MyWhoosh(), onUpdate: () {}),
            ));
  });

  // The gear overlay as part of step 3: offered while the app is still
  // being set up, and a checklist row once it is on.
  for (final (name, appConnected, overlayOn) in [
    ('waiting', false, false),
    ('ready', true, false),
    ('on', true, true),
  ]) {
    testWidgets('step ride overlay $name', (tester) async {
      await captureWidget(tester, name: 'onboarding_step_ride_overlay_$name', width: 390, settle: false,
          locales: const ['de'],
          builder: (c) => onboardingDoneBody(
                c,
                app: MyWhoosh(),
                controllerName: 'Zwift Click',
                trainerName: 'Wahoo KICKR 1EB7',
                bridgeName: 'Wahoo KICKR 1EB7 - BikeControl',
                appConnected: appConnected,
                trainerAppConnected: appConnected,
                reduceMotion: true,
                showTestMode: false,
                offerOverlay: !overlayOn,
                onShowOverlay: () {},
                overlayOn: overlayOn,
              ));
    });
  }

  testWidgets('step ride waiting for zwift', (tester) async {
    await captureWidget(tester, name: 'onboarding_step_ride_waiting_zwift', width: 380, settle: false,
        locales: const ['de'],
        builder: (c) => onboardingDoneBody(
              c,
              app: Zwift(),
              controllerName: 'Zwift Click',
              trainerName: 'Wahoo KICKR 1EB7',
              bridgeName: 'BikeControl 1EB7',
              appConnected: false,
              trainerAppConnected: false,
              reduceMotion: true,
              showTestMode: false,
            ));
  });

  // ── Step 3 once the app is connected: done / test mode ──────────────────────────────
  testWidgets('step done no trainer', (tester) async {
    await captureWidget(tester, name: 'onboarding_step_done', width: 380,
        builder: (c) => onboardingDoneBody(
              c,
              app: MyWhoosh(),
              controllerName: 'SRAM Rival AXS',
              trainerName: null,
              appConnected: true,
              trainerAppConnected: false,
              reduceMotion: true,
              showTestMode: true,
            ));
  });

  testWidgets('step done with trainer', (tester) async {
    await captureWidget(tester, name: 'onboarding_step_done_trainer', width: 380,
        builder: (c) => onboardingDoneBody(
              c,
              app: MyWhoosh(),
              controllerName: 'SRAM Rival AXS',
              trainerName: 'KICKR CORE',
              appConnected: true,
              trainerAppConnected: false,
              reduceMotion: true,
              showTestMode: true,
            ));
  });

  // Purchased users re-running the guide shouldn't see the "test mode" card.
  testWidgets('step done purchased (no test mode card)', (tester) async {
    await captureWidget(tester, name: 'onboarding_step_done_purchased', width: 380,
        builder: (c) => onboardingDoneBody(
              c,
              app: MyWhoosh(),
              controllerName: 'SRAM Rival AXS',
              trainerName: null,
              appConnected: true,
              trainerAppConnected: false,
              reduceMotion: true,
              showTestMode: false,
            ));
  });

  // ── Desktop: rail, two-trainer footer with a long translation, folded tips ─
  testWidgets('desktop gear empty controller', (tester) async {
    final a = ProxyDevice(BleDevice(deviceId: 'desk-a', name: 'KICKR CORE 1EB7'));
    final b = ProxyDevice(BleDevice(deviceId: 'desk-b', name: 'KICKR CORE 1EB7 WiFi'));
    await captureWidget(tester, name: 'onboarding_desktop_gear', width: 1100, height: 760, locales: const ['de'],
        settle: false, padding: EdgeInsets.zero,
        builder: (c) => onboardingShell(
              c,
              step: OnboardingStep.gear,
              body: onboardingGearBody(
                c,
                controllerPhase: ControllerPhase.empty,
                controllers: const [],
                app: MyWhoosh(),
                trainers: [a, b],
                onPickTrainer: (_) {},
                onScanControllersAgain: () {},
                vsDailyMinutesWithoutPro: 30,
              ),
              footerActions: [
                PrimaryButton(onPressed: null, child: Text(AppLocalizations.of(c).onboardingTrainersFound(2))),
                GhostButton(onPressed: () {}, child: Text(AppLocalizations.of(c).onboardingLetAppHandleVs('MyWhoosh'))),
              ],
              onBack: () {},
              onHelp: () {},
              onClose: () {},
              onSelectStep: (_) {},
              stepValues: const {OnboardingStep.app: 'MyWhoosh · Anderes Gerät'},
            ),
        beforeCapture: (tester) async {
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byKey(const ValueKey('onboarding-scroll-more')), findsOneWidget);
          final opacity = tester.widget<AnimatedOpacity>(
            find.ancestor(of: find.byKey(const ValueKey('onboarding-scroll-more')), matching: find.byType(AnimatedOpacity)),
          );
          expect(opacity.opacity, 1, reason: 'more below the fold: the arrow shows');
        });
  });

  testWidgets('desktop app step', (tester) async {
    await captureWidget(tester, name: 'onboarding_desktop_app', width: 1100, height: 760, locales: const ['de'],
        settle: false, padding: EdgeInsets.zero,
        builder: (c) => onboardingShell(
              c,
              step: OnboardingStep.app,
              body: onboardingAppBody(
                c,
                selected: MyWhoosh(),
                onSelect: (_) {},
                targets: Target.values,
                selectedTarget: Target.otherDevice,
                onSelectTarget: (_) {},
              ),
              footerActions: [PrimaryButton(onPressed: () {}, child: const Text('Weiter mit MyWhoosh'))],
              onHelp: () {},
              onClose: () {},
              onSelectStep: (_) {},
            ));
  });
}
