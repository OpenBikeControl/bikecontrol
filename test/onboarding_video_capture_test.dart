// Captures the onboarding wizard as a numbered 30 fps PNG sequence — the
// "screen layer" a video compositor later places in a 16:9 frame, with a
// synthetic pointer drawn from taps.json.
//
// The wizard has three screens (7.7): which app and where it runs, the gear
// (controller and smart trainer on one page), then linking the app. The film
// keeps the compositor's six chapters on them:
//
//   app         step 1: the app grid; the app's tile is picked and flies into
//               the spotlight (the grid is scrolled first for an app further
//               down, like "Other").
//   where       step 1: "<app> runs on" — This Device.
//   controller  step 2: the controller's own beats (presses, and the Click V2
//               explainer or the SRAM guided sheet where it opens).
//   trainer     step 2: the Virtual Shifting stage plays under the trainer
//               card, then the KICKR CORE is connected and bridged over the
//               real picker path; Continue.
//   link-app    step 3: "Almost there" — the guide is scrolled to and back,
//               then the app connects (through its connection method's own
//               entry point).
//   done        step 3: the app picks up the bridged trainer and the step
//               turns into "You're ready to ride". Zwift and "Other" take the
//               controller from the bridge itself, so one event does both.
//
// The phone is filmed as an iPhone (`debugHostPlatformOverride` = iOS): on a
// phone the app on "This Device" is reached over the network, which is the
// setup the website's guides describe.
//
// Scenes (`<app>-<controller>`; apps mywhoosh, rouvy, trainingpeaks, zwift,
// other):
//
// * `<app>-zwift-ride` — a connected Zwift Ride, three buttons pressed so the
//   contour reacts.
// * `<app>-zwift-play` — one connected Play on firmware 2 (`ZwiftPlayFw2`, what
//   Zwift Companion installs today; both halves report over one link, in the
//   Ride's protocol), three buttons pressed on its contour.
// * `<app>-zwift-click-v2` — both pucks found, held back for the one-time
//   unlock explainer, which opens by itself on step 2. The rider reads both
//   options, picks "No Zwift unlock" and "Use the right side" — the path that
//   finishes inside BikeControl, no Zwift app needed. The left puck is set
//   aside, the right one connects and two of its buttons are pressed.
// * `<app>-shimano-di2` — a connected rear derailleur whose shifter buttons
//   send D-Fly channels (set in Shimano's E-TUBE app), two channels pressed.
//   The wizard has no Di2 sub-flow: BikeControl's own Di2 setup (button mode
//   or E-TUBE channels) is offered on Ride after the wizard, not in it. Di2
//   has no contour in onboarding, so taps.json places the presses on the row.
// * `<app>-sram-axs` — a derailleur connected over the offline machine's
//   Bluetooth (prop's scripted fake derailleur behind it). Its guided setup
//   sheet opens by itself and is walked with real taps: Continue → the
//   derailleur asks to be authorised → the AXS button is held (a hardware
//   beat on the fake derailleur) → Retry → all set → Done. Two shifter
//   paddles are then pressed.
// * `vs-settings` — a cutaway on Settings → Virtual shifting for the bridged
//   trainer (filmed after the MyWhoosh Ride take, shared by every video): a
//   second chainring, gear count and gearing presets under the live
//   drivetrain; a gear change from a Ride press. The rider is pedalling, so
//   the chain on the drivetrain runs and the beat boundaries there are not
//   settled frames.
//
// Output (per scene):
//   build/video_frames/<scene>/000000.png, 000001.png, …  1140×2472 px
//   build/video_frames/<scene>/scene.json  {pixelRatio, width, height,
//     logicalWidth, logicalHeight, fps, frames} plus, for the wizard takes,
//     {app, appName, controller, controllerName}.
//   build/video_frames/<scene>/taps.json  [{frame, x, y, label, kind}] in PNG
//     pixels. kind "tap" is a finger on the screen; "swipe" a finger dragged
//     from x/y (at frame) to endX/endY (at endFrame); "hardware" a button
//     pressed (or held) on the controller, with an anchor saying where x/y
//     points: "contour-button" that button on the contour, "reaction" the spot
//     that reacts where no contour is on screen, "device-row" the controller's
//     row for a controller with no contour, "sheet-hero" the derailleur drawn
//     in the SRAM authorise step; "event" something the app hears from
//     outside (the trainer app connecting), at the spot that shows it.
//   build/video_frames/<scene>/chapters.json  [{name, start, end}] — every
//     boundary is a settled frame except the one into `trainer`, which sits on
//     the gear step with the Virtual Shifting stage moving.
//
// Tagged `video` and skipped by default (see dart_test.yaml). Run with:
//   flutter test --run-skipped --tags video test/onboarding_video_capture_test.dart
// One app only: add --dart-define=VIDEO_APPS=rouvy (comma-separated ids).
//
// Determinism
// -----------
// Every frame is a pure function of the script, which the determinism test
// proves byte for byte. What makes that hold:
//
// * The fake-clock binding: time only moves when the script pumps, exactly
//   1/30 s at a time.
// * Assets are decoded before the first recorded frame (fonts, logos, the
//   contour SVGs, the guide screenshots).
// * An offline machine (test/helpers/offline_machine.dart): the app's real
//   code runs down to emulated Bluetooth, an in-memory mDNS, TCP servers bound
//   to nothing and HTTP answered from local fixtures.
// * `screenshotMode` stays on, pinning everything read from the machine. The
//   motion it switches off is switched back on through
//   [debugAnimatesInScreenshotMode]; controller names are kept with
//   [debugKeepsControllerNamesInScreenshotMode]; the Click V2 explainer is let
//   through with [debugClickV2OnboardingInScreenshotMode].
@Tags(['video'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/shimano/shimano_di2.dart';
import 'package:bike_control/bluetooth/devices/sram/sram_axs.dart';
import 'package:bike_control/bluetooth/devices/sram/sram_setup_sheet.dart' show SramGuidedSheet;
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart' show ftmsEmulator;
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_left_side.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_right_side.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_play_fw2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart' show FakePeripheral;
import 'package:bike_control/bluetooth/emulation/emulated_peripherals.dart'
    show autoRespondToZwiftHandshake, buildFtmsTrainer;
import 'package:bike_control/bluetooth/emulation/profiles/zwift_profiles.dart' show buildZwiftController;
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart'
    show
        debugAnimatesInScreenshotMode,
        debugClickV2OnboardingInScreenshotMode,
        debugKeepsControllerNamesInScreenshotMode,
        screenshotLocale,
        screenshotMode;
import 'package:bike_control/pages/click_v2_onboarding.dart';
import 'package:bike_control/pages/onboarding/onboarding_page.dart';
import 'package:bike_control/pages/onboarding/steps/step_app.dart' show OnboardingAppTile;
import 'package:bike_control/pages/onboarding/widgets/vs_stage.dart' show debugVirtualShiftingStageOpeningScene;
import 'package:bike_control/pages/settings/virtual_shifting_settings_page.dart';
import 'package:bike_control/utils/device_setup_prompt.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/actions/base_actions.dart' show StubActions;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/training_peaks.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
// prop.dart's `SramAxs` is the protocol constants, not the app's device class.
import 'package:prop/prop.dart' as prop show SramAxs;
import 'package:prop/testing.dart' show FakeSramDerailleur;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import 'helpers/offline_machine.dart';
import 'helpers/video_capture.dart';
import 'widget_snapshot.dart';

/// The Virtual Shifting stage under the trainer card never comes to rest (it
/// cycles its scenes every 5.5 s). The film opens it on its gearing scene and
/// lets it play this long before the trainer is connected.
const _vsStageOpeningScene = 1;
const _vsStageFrames = 75;

/// Filmed after entering the gear step, before the first press (~2 s).
const _gearStepEntryFrames = 60;

/// What is filmed after an action on the gear step while the stage moves.
const _gearStepActionFrames = 30;

/// What is filmed after each cutaway action (its page never rests).
const _cutawayActionFrames = 24;

/// Cutaway holds: the opening page and the chosen preset.
const _cutawayOpeningFrames = 45;
const _presetHoldFrames = 54;

/// The cutaway starts the gear count here so two taps on + reach MyWhoosh's.
const _cutawayStartGears = 28;

/// Cadence and power the trainer reports during the cutaway, so the chain on
/// the gear card runs.
const _pedallingRpm = 90;
const _pedallingW = 200;

/// The Click V2 explainer is held ~3 s for a read before the rider picks.
const _clickV2ReadFrames = 90;

/// The SRAM authorise step's hero pulses for as long as it is up: it is held
/// ~2 s before the rider acts, and the AXS button ~1.5 s.
const _sramAuthorizeFrames = 60;
const _sramAxsHoldFrames = 45;

/// Extra hold on a screen that is mostly text to read (~1.5 s).
const _readFrames = 45;

/// Held on the guide in step 3 before scrolling back (~2 s).
const _guideReadFrames = 60;

/// Held on "You're ready to ride" at the end (~2 s).
const _readyHoldFrames = 60;

const _cutawayScene = 'vs-settings';

const _trainerName = 'KICKR CORE';

/// The guides' screenshots, served from local copies of the website's own
/// files instead of bikecontrol.app.
const _guideFixtures = {
  'https://bikecontrol.app/images/mywhoosh_obc/4-mywhoosh-connection-screen.jpg':
      'test/fixtures/onboarding_guides/mywhoosh_obc/4-mywhoosh-connection-screen.jpg',
  'https://bikecontrol.app/images/mywhoosh_obc/5-mywhoosh-openbikecontrol.jpg':
      'test/fixtures/onboarding_guides/mywhoosh_obc/5-mywhoosh-openbikecontrol.jpg',
  'https://bikecontrol.app/images/mywhoosh_obc/6-bikecontrol-connected.jpg':
      'test/fixtures/onboarding_guides/mywhoosh_obc/6-bikecontrol-connected.jpg',
  'https://bikecontrol.app/images/blog_rouvy_screenshot.jpg':
      'test/fixtures/onboarding_guides/rouvy/blog_rouvy_screenshot.jpg',
};

/// Each capture starts from the same stored state (a capture picks an app
/// and a target, which persists).
Future<void> _restoreAppState() async {
  await restorePristinePrefs();
  core.settings.trainerAppListenable.value = null;
  // Gearing lives in memory too; reload it from the restored prefs so the
  // cutaway's gear-count and preset changes don't carry into the next take.
  await core.shiftingConfigs.init();
  // A trainer is put back in the gear it was last left in; each take starts
  // from a trainer that was never ridden.
  ProxyDevice.debugClearRememberedGears();
  DeviceSetupPrompt.debugReset();
  // A purchased account: nothing in the film is gated or counted down, which
  // is also the only state in which it's honest to show Virtual Shifting
  // without a trial note.
  IAPManager.instance.isPurchased.value = true;
  // Straight into step 1: the film starts at the app step, not the welcome
  // screen.
  await core.settings.setOnboardingState(Settings.onboardingStateCompleted);
  core.actionHandler = StubActions();
  // The Ride's own buzz on a shift press is a BLE write to hardware that isn't
  // there; it isn't on film anyway.
  await core.settings.setVibrationEnabled(false);
  screenshotLocale = const Locale('en');
  await AppLocalizations.load(const Locale('en'));
}

class _Stage {
  _Stage(this.machine);

  final OfflineMachine machine;

  /// A fresh trainer per capture: a trainer the previous capture bridged is
  /// not the same object as one found for the first time.
  late ProxyDevice trainer;
}

/// The trainer app a take sets up, and how it connects on step 3.
class _AppFilm {
  const _AppFilm({
    required this.id,
    required this.isApp,
    required this.name,
    required this.connect,
    this.pickUpTrainer,
    this.guideImages = const [],
    this.unlocksClickV2 = false,
  });

  /// Whether the app unlocks a Zwift Click V2 itself (Zwift, Rouvy): the
  /// wizard then has no Click V2 choice to offer, and both pucks just work.
  final bool unlocksClickV2;

  /// Scene prefix and the website's app id.
  final String id;

  /// Picks the app's tile.
  final bool Function(SupportedApp) isApp;

  /// The app's name as the wizard shows it.
  final String name;

  /// The app connecting to BikeControl, through its method's own entry point.
  final void Function() connect;

  /// The app picking up the bridged trainer; null where [connect] already
  /// does (Zwift and "Other" take everything from the bridge).
  final void Function()? pickUpTrainer;

  /// The guide's screenshots (URLs served from [_guideFixtures], or assets).
  final List<String> guideImages;

  String get connectsLabel => '$name connects';
  String get pairsLabel => '$name pairs the trainer';
}

final _apps = <_AppFilm>[
  _AppFilm(
    id: 'mywhoosh',
    isApp: (a) => a is MyWhoosh,
    name: 'MyWhoosh',
    // MyWhoosh sends its app info over the Network (OpenBikeControl) method…
    connect: () => core.obpMdnsEmulator.onMessage(OpenBikeProtocolParser.encodeAppInfo(
      appId: 'MyWhoosh',
      appVersion: '1.0',
      supportedButtons: MyWhoosh().defaultObpSupportedButtons,
    )),
    // …and pairs "KICKR CORE - BikeControl": the bridge reports it held.
    pickUpTrainer: () => ftmsEmulator.isConnected.value = true,
    guideImages: [
      'https://bikecontrol.app/images/mywhoosh_obc/4-mywhoosh-connection-screen.jpg',
      'https://bikecontrol.app/images/mywhoosh_obc/5-mywhoosh-openbikecontrol.jpg',
    ],
  ),
  _AppFilm(
    id: 'rouvy',
    isApp: (a) => a is Rouvy,
    name: 'Rouvy',
    // Rouvy connects to BikeControl's controller over the network…
    connect: () => core.rouvyMdnsEmulator.clickEmulator.isConnected.value = true,
    // …and pairs "KICKR CORE - Bridge" as its trainer.
    pickUpTrainer: () => ftmsEmulator.isConnected.value = true,
    guideImages: ['https://bikecontrol.app/images/blog_rouvy_screenshot.jpg'],
    unlocksClickV2: true,
  ),
  _AppFilm(
    id: 'trainingpeaks',
    isApp: (a) => a is TrainingPeaks,
    name: 'TrainingPeaks Virtual',
    connect: () => core.obpMdnsEmulator.onMessage(OpenBikeProtocolParser.encodeAppInfo(
      appId: 'TrainingPeaks Virtual',
      appVersion: '1.0',
      supportedButtons: TrainingPeaks().defaultObpSupportedButtons,
    )),
    pickUpTrainer: () => ftmsEmulator.isConnected.value = true,
  ),
  _AppFilm(
    id: 'zwift',
    isApp: (a) => a is Zwift,
    name: 'Zwift',
    // Zwift pairs "BikeControl" for power, resistance, cadence and controls:
    // the one bridge carries both.
    connect: () => ftmsEmulator.isConnected.value = true,
    guideImages: ['assets/guides/zwift-pair-device.jpg', 'assets/guides/zwift-paired-devices.jpg'],
    unlocksClickV2: true,
  ),
  _AppFilm(
    id: 'other',
    isApp: (a) => a is CustomApp,
    name: 'Other',
    connect: () => ftmsEmulator.isConnected.value = true,
  ),
];

/// The controller a take is filmed with, and what happens on its part of the
/// gear step.
abstract class _ControllerTake {
  _ControllerTake({required this.sceneSuffix, required this.slug, required this.name});

  /// Scene folder suffix: build/video_frames/<app>-<suffix>.
  final String sceneSuffix;

  /// The website's device slug.
  final String slug;

  /// The app this take sets up (set before [stage]).
  late _AppFilm app;

  /// The controller's display name, for the compositor's overlay text.
  final String name;

  String scene(_AppFilm app) => '${app.id}-$sceneSuffix';

  /// What scene.json says about the controller.
  Map<String, Object> sceneInfo(_AppFilm app) =>
      {'app': app.id, 'appName': app.name, 'controller': slug, 'controllerName': name};

  /// The controller beats as (kind, label), in order, from "Continue to
  /// controller" on.
  List<(String, String)> get beats;

  /// Whether the controller has a contour on the step that reacts to presses.
  bool get hasContour => true;

  /// Screens the take must have filmed (see [VideoRecorder.sighting]).
  List<String> get sightings => const [];

  /// SVGs the step draws, decoded before the first recorded frame.
  List<String> get svgAssets;

  /// Puts the controller in range (not on film).
  Future<void> stage(WidgetTester tester, _Stage stage);

  /// Films the controller part of step 2, from the tap that enters it to the
  /// last press.
  Future<void> film(WidgetTester tester, VideoRecorder rec);

  /// Takes the controller away again, so the next take starts without it.
  Future<void> unstage(WidgetTester tester, _Stage stage);
}

/// "Continue with <app>" — the tap that leaves step 1 for the gear step.
/// The gear step builds in over ~1 s; it is given [_gearStepEntryFrames]
/// before the first press, so the page is seen whole (and the compositor's
/// camera pulls out for the page change rather than panning across it).
Future<void> _enterGearStep(VideoRecorder rec, {int? thenFrames}) => rec.tap(
    find.byType(PrimaryButton).last, 'Continue to controller',
    thenFrames: thenFrames ?? (rec.liveFrames == null ? null : _gearStepEntryFrames));

class _RideTake extends _ControllerTake {
  _RideTake(this.ride) : super(sceneSuffix: 'zwift-ride', slug: 'zwift-ride', name: 'Zwift Ride');

  final ZwiftRide ride;

  @override
  List<(String, String)> get beats => const [
        ('tap', 'Continue to controller'),
        ('hardware', 'Ride button: Shift up'),
        ('hardware', 'Ride button: Steer left'),
        ('hardware', 'Ride button: Shift down'),
      ];

  @override
  List<String> get svgAssets => [ride.controllerLayout.svgAsset!];

  @override
  Future<void> stage(WidgetTester tester, _Stage stage) async {
    core.connection.addDevices([stageConnected(ride)]);
  }

  @override
  Future<void> film(WidgetTester tester, VideoRecorder rec) async {
    await _enterGearStep(rec);
    expect(find.text(ride.displayName(tester.element(find.byType(OnboardingPage)))), findsOneWidget,
        reason: 'should be on the gear step with the Ride listed');

    // A shift, a steer, a shift the other way.
    final forward = forwardPresses(ride);
    await rec.hardwarePress(ride, RideButtonMask.SHFT_UP_R_BTN, ZwiftButtons.shiftUpRight, 'Ride button: Shift up');
    await rec.hardwarePress(ride, RideButtonMask.LEFT_BTN, ZwiftButtons.navigationLeft, 'Ride button: Steer left');
    await rec.hardwarePress(ride, RideButtonMask.SHFT_DN_L_BTN, ZwiftButtons.shiftDownLeft, 'Ride button: Shift down');
    unawaited(forward.cancel());
  }

  @override
  Future<void> unstage(WidgetTester tester, _Stage stage) => unstageStaged(tester, ride);
}

/// A Zwift Play on firmware 2 — what Zwift Companion puts on a Play today.
class _PlayTake extends _ControllerTake {
  _PlayTake() : super(sceneSuffix: 'zwift-play', slug: 'zwift-play', name: 'Zwift Play');

  late ZwiftPlayFw2 play;

  @override
  List<(String, String)> get beats => const [
        ('tap', 'Continue to controller'),
        ('hardware', 'Play button: Shift up'),
        ('hardware', 'Play button: Steer left'),
        ('hardware', 'Play button: Shift down'),
      ];

  @override
  List<String> get svgAssets => [ZwiftPlayFw2(BleDevice(name: 'Zwift Play', deviceId: 'svg')).controllerLayout.svgAsset!];

  @override
  Future<void> stage(WidgetTester tester, _Stage stage) async {
    play = ZwiftPlayFw2(BleDevice(name: 'Zwift Play', deviceId: '00:11:22:33:44:66'));
    stageConnected(play).firmwareVersion = '2.0.1';
    core.connection.addDevices([play]);
  }

  @override
  Future<void> film(WidgetTester tester, VideoRecorder rec) async {
    await _enterGearStep(rec);
    expect(find.text(play.displayName(tester.element(find.byType(OnboardingPage)))), findsOneWidget,
        reason: 'should be on the gear step with the Play listed');

    // The right half's shift button, the left half's D-pad, the left half's
    // shift button.
    final forward = forwardPresses(play);
    await rec.hardwarePress(play, RideButtonMask.SHFT_UP_R_BTN, ZwiftButtons.shiftUpRight, 'Play button: Shift up');
    await rec.hardwarePress(play, RideButtonMask.LEFT_BTN, ZwiftButtons.navigationLeft, 'Play button: Steer left');
    await rec.hardwarePress(play, RideButtonMask.SHFT_UP_L_BTN, ZwiftButtons.shiftUpLeft, 'Play button: Shift down');
    unawaited(forward.cancel());
  }

  @override
  Future<void> unstage(WidgetTester tester, _Stage stage) => unstageStaged(tester, play);
}

/// Both Click V2 pucks in range, as a rider with a new Click V2 has them. They
/// are held back for the unlock explainer, which opens by itself on step 2.
/// The rider picks "No Zwift unlock" and "Use the right side": everything
/// happens inside BikeControl (no Zwift app), the left puck is set aside and
/// the right one connects — over the offline machine's Bluetooth, through the
/// app's real connect path.
class _ClickV2Take extends _ControllerTake {
  _ClickV2Take() : super(sceneSuffix: 'zwift-click-v2', slug: 'zwift-click-v2', name: 'Zwift Click V2');

  static const _leftId = 'film-click-v2-left';
  static const _rightId = 'film-click-v2-right';

  late ZwiftClickV2LeftSide left;
  late ZwiftClickV2RightSide right;

  @override
  List<(String, String)> get beats => app.unlocksClickV2
      ? const [
          ('tap', 'Continue to controller'),
          ('hardware', 'Click V2 button: Shift up (+)'),
          ('hardware', 'Click V2 button: Shift down (−)'),
        ]
      : const [
          ('tap', 'Continue to controller'),
          ('tap', 'Click V2 setup: no Zwift unlock'),
          ('tap', 'Use the right side'),
          ('hardware', 'Click V2 button: Shift up (+)'),
          ('hardware', 'Click V2 button: Shift down (B)'),
        ];

  @override
  List<String> get sightings => app.unlocksClickV2 ? const [] : const ['click-v2-explainer', 'click-v2-choice'];

  @override
  List<String> get svgAssets => const [
        'assets/contours/zwift_click_v2_left_side.svg',
        'assets/contours/zwift_click_v2_right_side.svg',
      ];

  @override
  Future<void> stage(WidgetTester tester, _Stage stage) async {
    FakePeripheral puck(String id, int side) {
      final peripheral = buildZwiftController(
        deviceId: id,
        name: 'Zwift Click',
        manufacturerType: side,
        extraCharacteristicUuids: const [
          '00000100-19ca-4651-86e5-fa29dcdd09d1',
          '00000101-19ca-4651-86e5-fa29dcdd09d1',
        ],
      );
      autoRespondToZwiftHandshake(stage.machine.ble, peripheral, startResponse: ZwiftConstants.RESPONSE_START_CLICK_V2);
      stage.machine.ble.addPeripheral(peripheral);
      return peripheral;
    }

    left = ZwiftClickV2LeftSide(puck(_leftId, ZwiftConstants.CLICK_V2_LEFT_SIDE).scanResult);
    right = ZwiftClickV2RightSide(puck(_rightId, ZwiftConstants.CLICK_V2_RIGHT_SIDE).scanResult);
    core.connection.addDevices([left, right]);
    if (app.unlocksClickV2) {
      // Zwift and Rouvy unlock the Click V2 themselves, so once one is picked
      // nothing holds the pucks back and both connect (the scanner's connect
      // queue, which would do it, doesn't run under screenshotMode). They are
      // connected here through the app's real connect path, with the app
      // picked for the moment — a puck is held back while no app is — and
      // the pick undone again before the film starts on the app grid.
      await core.settings.prefs.setString('trainer_app', app.name);
      for (final d in [left, right]) {
        await driveUntil(tester, core.connection.connectDevice(d), '$d should have connected');
        expect(d.isConnected, isTrue, reason: '$d should be connected');
      }
      await core.settings.prefs.remove('trainer_app');
    }
  }

  @override
  Future<void> film(WidgetTester tester, VideoRecorder rec) async {
    final l10n = AppLocalizations.current;
    if (app.unlocksClickV2) {
      // No choice to make: both pucks are connected, each on its contour.
      await _enterGearStep(rec);
      expect(find.byType(ClickV2OnboardingPage), findsNothing, reason: '${app.name} unlocks the Click V2 itself');
      expect(left.isConnected && right.isConnected, isTrue, reason: 'both pucks should be connected');
      await rec.hardwarePress(right, RideButtonMask.SHFT_UP_R_BTN, ZwiftButtons.shiftUpRight,
          'Click V2 button: Shift up (+)');
      await rec.hardwarePress(left, RideButtonMask.SHFT_UP_L_BTN, ZwiftButtons.shiftUpLeft,
          'Click V2 button: Shift down (−)');
      return;
    }
    // Entering the gear step with a new Click V2 in range opens the explainer
    // over it (a page of its own: the moving stage is under it).
    rec.liveFrames = null;
    await _enterGearStep(rec);
    rec.sighting('click-v2-explainer', find.byType(ClickV2OnboardingPage));
    expect(find.text(l10n.clickV2Onboarding_noUnlockTitle), findsOneWidget);
    expect(find.text(l10n.clickV2Onboarding_zwiftTitle), findsOneWidget, reason: 'both options are offered');
    await rec.frames(_clickV2ReadFrames);

    // The option a rider finishes inside BikeControl: the right side alone.
    await rec.tap(find.byKey(const ValueKey('click-onboarding-option-no-unlock')), 'Click V2 setup: no Zwift unlock');
    rec.sighting('click-v2-choice', find.text(l10n.clickV2Onboarding_rightOnlyCta));
    await rec.frames(_readFrames);
    rec.liveFrames = _gearStepActionFrames * 2;
    await rec.tap(find.byKey(const ValueKey('click-onboarding-cta')), 'Use the right side');
    rec.liveFrames = _gearStepActionFrames;
    expect(find.byType(ClickV2OnboardingPage), findsNothing, reason: 'the explainer closes on a choice');
    expect(core.settings.getClickV2RightSideOnly(), isTrue);
    expect(right.isConnected, isTrue, reason: 'the right puck connects once chosen');
    expect(core.connection.devices, isNot(contains(left)), reason: 'the left puck is set aside');

    // The right puck on its own: + shifts up, B shifts down.
    await rec.hardwarePress(right, RideButtonMask.SHFT_UP_R_BTN, ZwiftButtons.shiftUpRight,
        'Click V2 button: Shift up (+)');
    await rec.hardwarePress(right, RideButtonMask.B_BTN, ZwiftButtons.b, 'Click V2 button: Shift down (B)');
  }

  @override
  Future<void> unstage(WidgetTester tester, _Stage stage) async {
    for (final d in [left, right]) {
      if (core.connection.devices.contains(d)) {
        await driveUntil(tester, core.connection.disconnect(d, forget: true, persistForget: false),
            '$d should have disconnected');
      }
    }
    stage.machine.ble
      ..removePeripheral(_leftId)
      ..removePeripheral(_rightId);
  }
}

/// A Shimano Di2 rear derailleur whose shifter buttons send D-Fly channels.
class _Di2Take extends _ControllerTake {
  _Di2Take() : super(sceneSuffix: 'shimano-di2', slug: 'shimano-di2', name: 'Shimano Di2');

  late ShimanoDi2 di2;

  /// Button names the presses decoded to, in order.
  final heard = <String>[];

  @override
  List<(String, String)> get beats => const [
        ('tap', 'Continue to controller'),
        ('hardware', 'Di2 button: D-Fly Ch1'),
        ('hardware', 'Di2 button: D-Fly Ch2'),
      ];

  @override
  bool get hasContour => false;

  @override
  List<String> get svgAssets => const [];

  Future<void> _channels(List<int> channels) =>
      di2.processCharacteristic(ShimanoDi2Constants.D_FLY_CHANNEL_UUID, Uint8List.fromList([0x00, ...channels]));

  @override
  Future<void> stage(WidgetTester tester, _Stage stage) async {
    heard.clear();
    di2 = ShimanoDi2(BleDevice(name: 'RDR Di2', deviceId: '00:11:22:33:44:77'));
    core.connection.addDevices([stageConnected(di2)]);
    // The derailleur reports its D-Fly state when the app subscribes; the
    // first frame is the baseline its buttons are discovered from.
    await _channels(const [0x00, 0x00, 0x00]);
  }

  @override
  Future<void> film(WidgetTester tester, VideoRecorder rec) async {
    await _enterGearStep(rec);
    final row = find.text(di2.displayName(tester.element(find.byType(OnboardingPage))));
    expect(row, findsOneWidget, reason: 'should be on the gear step with the Di2 listed');

    final forward = forwardPresses(di2);
    final listen = core.connection.actionStream.listen((n) {
      if (n is ButtonNotification && n.device == di2 && n.buttonsClicked.isNotEmpty) {
        heard.add(n.buttonsClicked.single.name);
      }
    });
    for (final (channel, label) in [(0, 'Di2 button: D-Fly Ch1'), (1, 'Di2 button: D-Fly Ch2')]) {
      await rec.hardware(
        label,
        at: row,
        anchor: 'device-row',
        // 0x10 on a channel is a short press; back to 0x00 is the release.
        press: () => _channels([for (var i = 0; i < 3; i++) i == channel ? 0x10 : 0x00]),
        release: () => _channels(const [0x00, 0x00, 0x00]),
      );
    }
    unawaited(listen.cancel());
    unawaited(forward.cancel());
    expect(heard, ['D-Fly Channel 1', 'D-Fly Channel 2'], reason: 'each press should decode to its channel');
  }

  @override
  Future<void> unstage(WidgetTester tester, _Stage stage) => unstageStaged(tester, di2);
}

/// A SRAM AXS rear derailleur on the offline machine's Bluetooth, with prop's
/// scripted fake derailleur answering it: the bond handshake, the reaction
/// config the setup backs up and clears, and encrypted button presses.
///
/// A derailleur that has never met BikeControl only completes the bond once
/// its AXS button is held. Until then the fake stands for that by answering
/// the key exchange with a create-bond frame the app can't decrypt — the
/// failure the app's authorise step is there for.
class _SramTake extends _ControllerTake {
  _SramTake() : super(sceneSuffix: 'sram-axs', slug: 'sram-axs-etap', name: 'SRAM AXS');

  static const _id = 'film-sram-axs';

  late SramAxs sram;
  late FakeSramDerailleur derailleur;
  var _axsButtonHeld = false;

  /// Button names the presses decoded to, in order.
  final heard = <String>[];

  @override
  List<(String, String)> get beats => const [
        ('tap', 'Continue to controller'),
        ('tap', 'SRAM setup: Continue'),
        ('hardware', 'AXS button: Press & hold'),
        ('tap', 'SRAM setup: Retry'),
        ('tap', 'SRAM setup: Done'),
        ('hardware', 'SRAM button: Shifter A paddle'),
        ('hardware', 'SRAM button: Shifter B paddle'),
      ];

  @override
  bool get hasContour => false;

  @override
  List<String> get sightings => const ['sram-setup-confirm', 'sram-setup-authorize', 'sram-setup-success'];

  @override
  List<String> get svgAssets => const [];

  @override
  Future<void> stage(WidgetTester tester, _Stage stage) async {
    heard.clear();
    _axsButtonHeld = false;
    final peripheral = FakePeripheral(
      deviceId: _id,
      name: 'SRAM AXS',
      advertisedServices: FakeSramDerailleur.advertisedServices,
      services: FakeSramDerailleur.buildServices(),
    );
    sram = SramAxs(peripheral.scanResult);
    derailleur = FakeSramDerailleur(
      notify: (characteristic, value) =>
          unawaited(sram.processCharacteristic(characteristic, Uint8List.fromList(value))),
      onReadValue: (characteristic, value) => peripheral.readValues[characteristic] = value,
    );
    final bondChar = prop.SramAxs.bondChar.toLowerCase();
    peripheral.onWrite = (service, characteristic, value) {
      final isKeyExchange = characteristic.toLowerCase() == bondChar && value.length == 16 && !_isBondInit(value);
      if (isKeyExchange && !_axsButtonHeld) {
        derailleur.notify(prop.SramAxs.bondChar, Uint8List(48));
        return;
      }
      derailleur.handleWrite(service, characteristic, value);
    };
    stage.machine.ble.addPeripheral(peripheral);
    core.connection.addDevices([sram]);
    // Connected through the app's real connect path (the scanner's connect
    // queue doesn't run under screenshotMode).
    await driveUntil(tester, core.connection.connectDevice(sram), 'the derailleur should have connected');
    expect(sram.isConnected, isTrue);
    expect(sram.needsGuidedSetup, isTrue);
  }

  @override
  Future<void> film(WidgetTester tester, VideoRecorder rec) async {
    final l10n = AppLocalizations.current;
    // Entering the gear step with the derailleur connected opens its guided
    // setup sheet over the step.
    await _enterGearStep(rec, thenFrames: _gearStepActionFrames * 2);
    rec.sighting('sram-setup-confirm', find.byType(SramGuidedSheet));
    expect(find.text(l10n.sramSetupIntro), findsOneWidget);
    await rec.frames(_readFrames);

    Finder sheetButton(String text) =>
        find.descendant(of: find.byType(SramGuidedSheet), matching: find.widgetWithText(PrimaryButton, text));
    await rec.tap(sheetButton(l10n.continueAction), 'SRAM setup: Continue', thenFrames: _sramAuthorizeFrames);
    rec.sighting('sram-setup-authorize', find.text(l10n.sramAuthorizeTitle));

    // Holding the AXS button on the derailleur authorises BikeControl.
    await rec.hardware(
      'AXS button: Press & hold',
      at: find.text('AXS'),
      anchor: 'sheet-hero',
      press: () async => _axsButtonHeld = true,
      holdFrames: _sramAxsHoldFrames,
      thenFrames: 0,
    );
    await rec.tap(sheetButton(l10n.retry), 'SRAM setup: Retry', thenFrames: _gearStepActionFrames * 2);
    rec.sighting('sram-setup-success', find.text(l10n.sramAllSet));
    expect(sram.isShiftingDisabled, isTrue, reason: 'setup should have handed the paddles to BikeControl');
    expect(derailleur.derailleurUnassigned, isTrue);
    await rec.frames(_readFrames);

    await rec.tap(sheetButton(l10n.done), 'SRAM setup: Done');
    expect(find.byType(SramGuidedSheet), findsNothing);

    final row = find.text(sram.displayName(tester.element(find.byType(OnboardingPage))));
    final listen = core.connection.actionStream.listen((n) {
      if (n is ButtonNotification && n.device == sram && n.buttonsClicked.isNotEmpty) {
        heard.add(n.buttonsClicked.single.name);
      }
    });
    // Two shifters' paddles. A press reports no release.
    for (final (serial, label) in [(0x0A, 'SRAM button: Shifter A paddle'), (0x0B, 'SRAM button: Shifter B paddle')]) {
      await rec.hardware(label, at: row, anchor: 'device-row', press: () async => derailleur.pressPaddle(serial));
    }
    unawaited(listen.cancel());
    expect(heard, ['SRAM Shifter A – Paddle', 'SRAM Shifter B – Paddle'],
        reason: 'each press should decode to its shifter');
  }

  /// The bond handshake's opening write: the fixed token 0, 1, …, 15.
  static bool _isBondInit(Uint8List value) {
    for (var i = 0; i < value.length; i++) {
      if (value[i] != i) return false;
    }
    return true;
  }

  @override
  Future<void> unstage(WidgetTester tester, _Stage stage) async {
    await driveUntil(tester, core.connection.disconnect(sram, forget: true, persistForget: false),
        'the derailleur should have disconnected');
    stage.machine.ble.removePeripheral(_id);
  }
}

/// One take of the wizard for [app] with [take]'s controller. The MyWhoosh
/// Ride take goes on into the gearing cutaway on the bridged trainer's page
/// ([withCutaway]).
Future<({VideoCapture onboarding, VideoCapture? cutaway})> _captureWizard(
  WidgetTester tester,
  _Stage stage,
  _AppFilm app,
  _ControllerTake take, {
  ZwiftRide? withCutaway,
}) async {
  await _resetMachine(tester, stage);
  await _restoreAppState();
  take.app = app;
  await take.stage(tester, stage);

  // An FTMS smart trainer in range, as the scan would have found it.
  final peripheral = buildFtmsTrainer(deviceId: 'film-kickr', name: _trainerName);
  stage.machine.ble.addPeripheral(peripheral);
  final trainer = stage.trainer = ProxyDevice(peripheral.scanResult);
  core.connection.addDevices([trainer]);

  useVideoView(tester);

  // performScanning early-returns while this is set, so the gear step never
  // starts a scan of its own.
  core.connection.isScanning.value = true;
  addTearDown(() => core.connection.isScanning.value = false);

  final boundary = GlobalKey();
  Widget appShell(Widget home) => videoApp(boundary, home);

  // ── Warm-up (not recorded): decode every asset the film shows. ──────────
  await tester.pumpWidget(appShell(const OnboardingPage()));
  await tester.pump();
  await loadAllVideoFonts(tester);
  final assetContext = tester.element(find.byType(OnboardingPage));
  await tester.runAsync(() async {
    Future<void> quietly(Future<void> f) => f.catchError((_) {});
    await Future.wait([
      precacheImage(const AssetImage('icon.png'), assetContext),
      for (final a in SupportedApp.supportedApps)
        if (a.logoAsset != null) quietly(precacheImage(AssetImage(a.logoAsset!), assetContext)),
      for (final svg in take.svgAssets) SvgAssetLoader(svg).loadBytes(assetContext),
      for (final img in app.guideImages)
        img.startsWith('http')
            ? precacheImage(NetworkImage(img), assetContext)
            : precacheImage(AssetImage(img), assetContext),
    ]);
  });
  await tester.pumpWidget(appShell(const SizedBox()));
  await tester.pump();

  // ── The wizard. Frame 0 is the app step's first frame. ───────────────────
  final rec = VideoRecorder(tester, boundary);
  await tester.pumpWidget(appShell(const OnboardingPage()));
  await rec.first('app');
  rec.capture.transitionFrames['app step reveal'] = await rec.untilStill();

  // Step 1 — the app: scrolled to, where it isn't in view, and picked.
  final tile = find.byWidgetPredicate((w) => w is OnboardingAppTile && app.isApp(w.app));
  expect(tile, findsOneWidget, reason: '${app.name} should be in the grid');
  for (var i = 0; tile.hitTestable().evaluate().isEmpty || _underFooter(tester, tile); i++) {
    expect(i, lessThan(12), reason: 'should have scrolled to ${app.name}');
    final before = tester.getRect(tile).top;
    await rec.swipe(const Offset(190, 680), const Offset(190, 180), 'Scroll to ${app.name}');
    if (tester.getRect(tile).top == before) break; // the end of the grid
  }
  await rec.tap(tile, '${app.name} tile');

  // …where it runs: this device.
  rec.chapter('where');
  await rec.tap(find.byKey(const ValueKey('onboarding-where-thisDevice')), 'This Device');

  // Step 2 — the gear: the controller's own beats. The Virtual Shifting stage
  // under the trainer card never rests from here until the trainer connects.
  rec.chapter('controller');
  final l10n = AppLocalizations.current;
  rec.liveFrames = _gearStepActionFrames;
  await take.film(tester, rec);

  // …and the smart trainer: the stage plays, then the KICKR CORE is
  // connected from the step's primary button and bridged.
  rec.chapter('trainer', settled: false);
  // Picking the app and where it runs switches on its network method
  // (applyTargetSelection). Under screenshotMode that step reads every method
  // as already on and leaves it off, so the film switches on what it switches
  // on for a rider — a stored setting, nothing on screen.
  _switchOnNetworkMethod();
  await rec.frames(_vsStageFrames);
  rec.liveFrames = null;
  await rec.tap(find.byKey(const ValueKey('onboarding-gear-primary')), 'Connect $_trainerName');
  expect(trainer.isBridged, isTrue, reason: 'connecting the trainer should bridge it');

  // Step 3 — link the app: the guide, then the app connecting.
  rec.chapter('link-app');
  await rec.tap(find.byType(PrimaryButton).last, 'Continue to connection');
  expect(find.text(l10n.onboardingAlmostThereTitle.toUpperCase()), findsOneWidget,
      reason: 'step 3 should wait for ${app.name}');
  await rec.swipe(const Offset(190, 640), const Offset(190, 300), 'Scroll to the guide');
  await rec.frames(_guideReadFrames);
  await rec.swipe(const Offset(190, 300), const Offset(190, 640), 'Scroll back to the checklist');
  final waiting = find.text(l10n.onboardingSummaryWaitingFor(app.name));
  await rec.event(app.connectsLabel, waiting.first, app.connect);
  expect(core.logic.connectedTrainerConnections.any((c) => c.isConnected.value), isTrue,
      reason: '${app.name} should be connected');

  // …and the app picking up the bridged trainer: ready to ride.
  rec.chapter('done');
  if (app.pickUpTrainer case final pickUp?) {
    await rec.event(app.pairsLabel, find.text(l10n.onboardingSummaryWaitingFor(app.name)), pickUp);
  }
  expect(trainer.isConnectedListenable.value, isTrue, reason: '${app.name} should hold the bridged trainer');
  expect(find.text(l10n.onboardingDoneTitle.toUpperCase()), findsOneWidget, reason: 'the take should end ready to ride');
  expect(find.text(l10n.onboardingDoneStartRiding), findsOneWidget);
  await rec.frames(_readyHoldFrames);

  final ride = withCutaway;
  if (ride == null) {
    await _unbridge(tester, stage, peripheral.deviceId);
    await take.unstage(tester, stage);
    return (onboarding: rec.capture, cutaway: null);
  }

  // ── The cutaway: Settings → Virtual shifting for the bridged trainer. ─────
  // Its own take, on the same bridged trainer. Shifts go through the real
  // action pipeline from here on, so a Ride press changes the trainer's gear.
  core.actionHandler = FilmActions()..init(core.settings.getTrainerApp());
  final definition = trainer.fitnessBike!;
  // The gear count starts two short of MyWhoosh's, so the stepper gets there.
  definition.setMaxGear(_cutawayStartGears);
  await core.shiftingConfigs.upsert(
    core.shiftingConfigs.activeFor(trainer.trainerKey).copyWith(maxGear: _cutawayStartGears),
  );
  // The rider is pedalling: the trainer sends FTMS Indoor Bike Data about once
  // a second, through the bridge's own parser.
  void pedal() => unawaited(trainer.processCharacteristic(
        FitnessBikeDefinition.INDOOR_BIKE_DATA_UUID,
        Uint8List.fromList(indoorBikeData(cadenceRpm: _pedallingRpm, powerW: _pedallingW)),
      ));
  pedal();
  final pedalling = Timer.periodic(const Duration(seconds: 1), (_) => pedal());
  final cut = VideoRecorder(tester, boundary);
  await tester.pumpWidget(appShell(const SizedBox()));
  await tester.pump();
  await tester.pumpWidget(appShell(VirtualShiftingSettingsPage(definition: definition, device: trainer)));
  await cut.first('gearing');
  // The chain on the drivetrain runs wherever the page is scrolled: nothing
  // on this page settles.
  cut.liveFrames = _cutawayActionFrames;
  expect(definition.cadenceRpm.value, _pedallingRpm, reason: 'the trainer should be reporting cadence');
  await cut.frames(_cutawayOpeningFrames - 1);

  // (a) Your gearing, your way: one scroll puts the drivetrain at the top,
  // with the gear presets, the gear count and the front derailleur right
  // under it, so every change lands in view of the chain.
  final drivetrain = find.byKey(const ValueKey('vs-drivetrain'));
  final scrollBy = tester.getRect(drivetrain).top - 76;
  await cut.swipe(const Offset(190, 760), Offset(190, 760 - scrollBy), 'Scroll to the drivetrain', overFrames: 20);
  // The gear count first: changing it puts the gearing back on Default.
  final plus = find.descendant(of: find.byKey(const ValueKey('vs-gears')), matching: find.byIcon(LucideIcons.plus));
  await cut.tap(plus, 'Gear count +');
  await cut.tap(plus, 'Gear count + again');
  expect(definition.maxGear, MyWhoosh().virtualGearAmount);
  await cut.tap(find.text(l10n.presetCompact), 'Compact preset');
  await cut.frames(_presetHoldFrames - _cutawayActionFrames);
  final frontDerailleur = find.descendant(
    of: find.byKey(const ValueKey('vs-front-derailleur')),
    matching: find.byWidgetPredicate((w) => w is Switch),
  );
  await cut.tap(frontDerailleur.first, 'Front derailleur', thenFrames: _presetHoldFrames);

  // (b) Direct gear changes: two Ride shifts land on the drivetrain.
  cut.chapter('direct-gear-changes', settled: false);
  final gearCard = find.byKey(const ValueKey('vs-drivetrain'));
  for (final label in ['Ride button: Shift up', 'Ride button: Shift up again']) {
    final before = definition.currentGear.value;
    await cut.hardwarePress(ride, RideButtonMask.SHFT_UP_R_BTN, ZwiftButtons.shiftUpRight, label,
        reactsAt: gearCard, thenFrames: 45);
    expect(definition.currentGear.value, before + 1, reason: '"$label" should shift the trainer up a gear');
  }
  pedalling.cancel();

  await _unbridge(tester, stage, peripheral.deviceId);
  await take.unstage(tester, stage);
  return (onboarding: rec.capture, cutaway: cut.capture);
}

/// The network method applyTargetSelection turns on for the picked app on
/// this device (OpenBikeControl's, or the Zwift-style one Rouvy shares).
void _switchOnNetworkMethod() {
  final app = core.settings.getTrainerApp()!;
  if (app.supports(AppConnectionMethod.obpMdns) || app.supports(AppConnectionMethod.obpDirCon)) {
    unawaited(core.settings.setObpMdnsEnabled(true));
  } else {
    unawaited(core.settings.setZwiftMdnsEmulatorEnabled(true));
  }
}

/// Every controller, trainer and app connection gone — whatever a take that
/// failed half-way left behind — so each take starts from the same machine.
Future<void> _resetMachine(WidgetTester tester, _Stage stage) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  for (final d in [...core.connection.devices]) {
    if (d is ProxyDevice) d.fitnessBike?.dispose();
    d.isConnected = false;
    try {
      await driveUntil(tester, core.connection.disconnect(d, forget: true, persistForget: false), '$d removed');
    } catch (_) {
      // Best effort: the next take's own checks say if anything stayed.
    }
  }
  ftmsEmulator.isConnected.value = false;
  core.rouvyMdnsEmulator.clickEmulator.isConnected.value = false;
  core.obpMdnsEmulator.stopServer();
  core.rouvyMdnsEmulator.stop();
  core.zwiftMdnsEmulator.stop();
  for (final id in const ['film-kickr', _ClickV2Take._leftId, _ClickV2Take._rightId, _SramTake._id]) {
    stage.machine.ble.removePeripheral(id);
  }
  await tester.pump(const Duration(seconds: 1));
}

/// Whether [tile] reaches under the footer's button (hittable at its centre,
/// but half-hidden).
bool _underFooter(WidgetTester tester, Finder tile) =>
    tester.getRect(tile).bottom > tester.getRect(find.byType(PrimaryButton).last).top - 8;

/// Unmounts (cancelling the wizard's timers) and unbridges, so the next take
/// finds the trainer — and the app — the way this one did. None of this is on
/// film.
Future<void> _unbridge(WidgetTester tester, _Stage stage, String peripheralId) async {
  final trainer = stage.trainer;
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  // Disconnecting detaches the trainer's definition from the emulator but does
  // not dispose it, which leaves its 1 s notify timer running; it is stopped
  // below.
  final definition = trainer.fitnessBike;
  await driveUntil(tester, core.connection.disconnect(trainer, forget: true, persistForget: false),
      'the trainer should have disconnected');
  definition?.dispose();
  ftmsEmulator.isConnected.value = false;
  core.rouvyMdnsEmulator.clickEmulator.isConnected.value = false;
  core.obpMdnsEmulator.stopServer();
  core.rouvyMdnsEmulator.stop();
  core.zwiftMdnsEmulator.stop();
  await tester.pump(const Duration(seconds: 1));
  stage.machine.ble.removePeripheral(peripheralId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A connected Zwift Ride, staged the way screenshot_test.dart stages its
  // controllers: the real device class over a hand-made scan result. The
  // same object carries on into the cutaway.
  final ride = ZwiftRide(BleDevice(name: 'Zwift Ride', deviceId: '00:11:22:33:44:55'));
  final rideTake = _RideTake(ride);
  final takes = <_ControllerTake>[rideTake, _PlayTake(), _ClickV2Take(), _Di2Take(), _SramTake()];
  const only = String.fromEnvironment('VIDEO_APPS');
  final apps = only.isEmpty ? _apps : _apps.where((a) => only.split(',').contains(a.id)).toList();
  const onlyTakes = String.fromEnvironment('VIDEO_TAKES');
  bool wanted(_ControllerTake t) => onlyTakes.isEmpty || onlyTakes.split(',').contains(t.sceneSuffix);
  late _Stage stage;

  // In setUpAll rather than main(): under the fake-clock binding, Supabase's
  // initialisation inside Settings.init() needs to run in a test zone.
  setUpAll(() async {
    await ensureSnapshotAppState();
    rememberPristinePrefs();
    stage = _Stage(OfflineMachine.install(httpFixtures: _guideFixtures));
  });

  setUp(() {
    // Keep the plumbing pinned (see the header) but let the wizard move.
    screenshotMode = true;
    debugAnimatesInScreenshotMode = true;
    debugClickV2OnboardingInScreenshotMode = true;
    debugKeepsControllerNamesInScreenshotMode = true;
    debugVirtualShiftingStageOpeningScene = _vsStageOpeningScene;
    // Filmed as a phone: "This Device" reaches the app over the network.
    debugHostPlatformOverride = TargetPlatform.iOS;
    addTearDown(() {
      debugAnimatesInScreenshotMode = false;
      debugClickV2OnboardingInScreenshotMode = false;
      debugKeepsControllerNamesInScreenshotMode = false;
      debugVirtualShiftingStageOpeningScene = null;
      debugHostPlatformOverride = null;
    });
  });

  void expectStepChangesAnimate(VideoCapture capture, List<String> labels) {
    // A step change is filmed as Flutter's own reveal, not a cut.
    for (final label in labels) {
      expect(capture.transitionFrames[label]! - videoHold, greaterThanOrEqualTo(15),
          reason: '"$label" should animate across frames, not cut');
    }
  }

  /// Everything every wizard take must hold, whatever the app and controller.
  void expectWizardTake(_AppFilm app, _ControllerTake take, VideoCapture onboarding) {
    final scene = take.scene(app);
    final info = jsonDecode(File('build/video_frames/$scene/scene.json').readAsStringSync()) as Map;
    expect(info['pixelRatio'], 3);
    expect(info['frames'], onboarding.frames.length);
    expect(info['controller'], take.slug);
    expect(info['controllerName'], take.name);
    expect(pngSize(onboarding.frames.first), (1140, 2472), reason: scene);

    final scrolls = onboarding.taps.where((t) => t.label == 'Scroll to ${app.name}').length;
    expect(onboarding.taps.map((t) => (t.kind, t.label)), [
      for (var i = 0; i < scrolls; i++) ('swipe', 'Scroll to ${app.name}'),
      ('tap', '${app.name} tile'),
      ('tap', 'This Device'),
      ...take.beats,
      ('tap', 'Connect $_trainerName'),
      ('tap', 'Continue to connection'),
      ('swipe', 'Scroll to the guide'),
      ('swipe', 'Scroll back to the checklist'),
      ('event', app.connectsLabel),
      if (app.pickUpTrainer != null) ('event', app.pairsLabel),
    ]);
    expect(onboarding.chapters.map((c) => c.name), ['app', 'where', 'controller', 'trainer', 'link-app', 'done']);
    // On the gear step the stage moves under every beat; the Click V2
    // explainer, a page over it, is the exception.
    final gearBeats = {
      for (final (_, label) in take.beats) label,
      'Connect $_trainerName',
    };
    // (Whether a given beat there happens to start on a still frame depends
    // on where the stage is in its loop.)
    expectWellFormed(onboarding, unsettledTaps: const {}, mayBeUnsettledTaps: gearBeats, unsettledChapters: const {'trainer'});
    expect(onboarding.sightings.keys, containsAll(take.sightings));

    for (final t in onboarding.taps.where((t) => t.kind == 'hardware' && t.anchor == 'contour-button')) {
      expect(reactingFrames(onboarding, t), greaterThan(3), reason: '"${t.label}" should visibly react on film');
    }
    if (!take.hasContour) {
      expect(onboarding.taps.where((t) => t.kind == 'hardware' && t.anchor == 'contour-button'), isEmpty);
    }
    final connects = onboarding.taps.firstWhere((t) => t.label == app.connectsLabel);
    expect(reactingFrames(onboarding, connects), greaterThan(3), reason: '${app.name} connecting should show on film');

    expectStepChangesAnimate(onboarding, ['app step reveal', 'Continue to connection']);
    // The stage moves on film before the trainer connects.
    final connect = onboarding.taps.firstWhere((t) => t.label == 'Connect $_trainerName');
    expect(onboarding.frames.sublist(connect.frame - _vsStageFrames, connect.frame).map(sha256.convert).toSet().length,
        greaterThan(10),
        reason: 'the Virtual Shifting stage should be moving on film');
  }

  for (final app in apps) {
    for (final take in takes.where(wanted)) {
      final withCutaway = app.id == 'mywhoosh' && take == rideTake;
      testWidgets('captures the ${take.scene(app)} take as a 30 fps frame sequence', (tester) async {
        final watch = Stopwatch()..start();
        final (:onboarding, :cutaway) =
            await _captureWizard(tester, stage, app, take, withCutaway: withCutaway ? ride : null);
        watch.stop();
        writeScene(take.scene(app), onboarding, extra: take.sceneInfo(app));
        expectWizardTake(app, take, onboarding);
        reportCapture(take.scene(app), onboarding, watch.elapsed);
        if (cutaway == null) return;

        writeScene(_cutawayScene, cutaway);
        expect(pngSize(cutaway.frames.first), (1140, 2472));
        expect(cutaway.taps.map((t) => (t.kind, t.label)), [
          ('swipe', 'Scroll to the drivetrain'),
          ('tap', 'Gear count +'),
          ('tap', 'Gear count + again'),
          ('tap', 'Compact preset'),
          ('tap', 'Front derailleur'),
          ('hardware', 'Ride button: Shift up'),
          ('hardware', 'Ride button: Shift up again'),
        ]);
        expect(cutaway.chapters.map((c) => c.name), ['gearing', 'direct-gear-changes']);
        expectWellFormed(
          cutaway,
          unsettledTaps: {for (final t in cutaway.taps) t.label},
          settledCuts: false,
        );
        expect(cutaway.frames.sublist(0, _cutawayOpeningFrames).map(sha256.convert).toSet().length, greaterThan(30),
            reason: 'the chain should be running on film');
        for (final t in cutaway.taps.where((t) => t.kind == 'hardware')) {
          expect(reactingFrames(cutaway, t), greaterThan(3), reason: '"${t.label}" should visibly react on film');
        }
        reportCapture(_cutawayScene, cutaway, watch.elapsed);
      });
    }
  }

  testWidgets('two captures are byte-identical, frame for frame', (tester) async {
    final app = _apps.first;
    final a = await _captureWizard(tester, stage, app, rideTake, withCutaway: ride);
    final b = await _captureWizard(tester, stage, app, rideTake, withCutaway: ride);
    expectIdentical(rideTake.scene(app), a.onboarding, b.onboarding);
    expectIdentical(_cutawayScene, a.cutaway!, b.cutaway!);
  });
}
