// Captures the onboarding wizard as a numbered 30 fps PNG sequence — the
// "screen layer" a video compositor later places in a 16:9 frame, with a
// synthetic pointer drawn from taps.json.
//
// Scenes:
//
// * `mywhoosh-controller` — the whole MyWhoosh wizard, one continuous take:
//   app → where ("This Device") → controller (a connected Zwift Ride, three of
//   its buttons pressed so the contour reacts) → trainer (the Virtual Shifting
//   stage from its gearing scene on, then a KICKR CORE bridged through the
//   real picker path) → link-app (the Network method switched on, the "Then
//   in MyWhoosh" guide, MyWhoosh connecting and pairing the trainer) → done,
//   ready to ride. `chapters.json` gives each step's frame range.
// * `mywhoosh-zwift-play`, `mywhoosh-zwift-click-v2`, `mywhoosh-shimano-di2`,
//   `mywhoosh-sram-axs` — the same take with another controller on step 3.
//   Only the controller step differs:
//   - Zwift Play: one connected Play on firmware 2 (`ZwiftPlayFw2`, what
//     Zwift Companion installs today; both halves report over one link, in
//     the Ride's protocol), three buttons pressed on its contour.
//   - Zwift Click V2: both pucks found, held back for the one-time unlock
//     explainer, which auto-opens on film. The rider reads both options and
//     picks "Use the right side" — the path that finishes inside BikeControl,
//     no Zwift app needed. The left puck is set aside, the right one connects
//     and two of its buttons are pressed on its contour.
//   - Shimano Di2: a connected rear derailleur, two D-Fly channels pressed.
//     Di2 has no contour in onboarding, so nothing on screen reacts; taps.json
//     places the presses on the device row.
//   - SRAM AXS: a derailleur connected over the offline machine's Bluetooth
//     (prop's scripted fake derailleur behind it). Its guided setup sheet
//     auto-opens on film and is walked with real taps: Continue → the
//     derailleur asks to be authorised → the AXS button is held (a hardware
//     beat on the fake derailleur) → Retry → all set → Done. Two shifter
//     paddles are then pressed; like Di2, AXS has no contour in onboarding.
// * `vs-settings` — a cutaway on the bridged trainer's page: gearing presets,
//   gear count and a second chainring; a gear change from a Ride press; the
//   SIM / ERG switch. Its `chapters.json` names those three beats. The rider
//   is pedalling (the trainer streams Indoor Bike Data), so the chain on the
//   gear card runs; the gear-count warning and the Mini Workout card are kept
//   off it with test-only flags. Because the chain never rests, the beat
//   boundaries here are not settled frames — it is one continuous take.
//
// Output (per scene):
//   build/video_frames/<scene>/000000.png, 000001.png, …  1140×2472 px
//   build/video_frames/<scene>/scene.json  {pixelRatio, width, height,
//     logicalWidth, logicalHeight, fps, frames} — pixelRatio maps the
//     380×824 logical screen to the PNG and taps.json pixel space. The wizard
//     takes add {controller, controllerName}: the website's device slug and
//     the controller's display name.
//   build/video_frames/<scene>/taps.json  [{frame, x, y, label, kind}] in PNG
//     pixels. kind "tap" is a finger on the screen; "swipe" a finger dragged
//     from x/y (at frame) to endX/endY (at endFrame); "hardware" a button
//     pressed (or held) on the controller, with an anchor saying where x/y
//     points: "contour-button" that button on the contour, "reaction" the spot
//     that reacts where no contour is on screen, "device-row" the controller's
//     row for a controller with no contour (nothing on screen reacts),
//     "sheet-hero" the derailleur drawn in the SRAM authorise step;
//     "event" something the app hears from outside (MyWhoosh connecting), at
//     the spot that shows it.
//   build/video_frames/<scene>/chapters.json  [{name, start, end, cut?}] —
//     every boundary between two chapters is a settled frame, so a cut there
//     is invisible.
//
// Tagged `video` and skipped by default (see dart_test.yaml). Run with:
//   flutter test --run-skipped --tags video test/onboarding_video_capture_test.dart
//
// Determinism
// -----------
// Every frame is a pure function of the script, which is what the second test
// proves byte for byte. What makes that hold:
//
// * The fake-clock binding. The snapshot harness normally installs the
//   integration binding, under which `pump(duration)` waits wall-clock time
//   and frames are stamped by the real vsync — an animation's phase in a
//   captured frame would depend on how fast the machine rendered the previous
//   one. Here time only moves when the script pumps, exactly 1/30 s at a time.
// * Assets are decoded before the first recorded frame. Fonts, the app logos,
//   the header icon, the Ride contour SVG and the guide screenshots all load
//   through real async I/O, which the fake clock never waits for; left to
//   load mid-recording they pop in on whichever frame the machine got to them.
// * An offline machine (test/helpers/offline_machine.dart). Connecting the
//   trainer and switching on the Network method run the app's real code down
//   to the platform: the app's emulated BLE platform stands in for Bluetooth,
//   an in-memory mDNS for the LAN, TCP servers bind to nothing, the network
//   interface list is fixed and HTTP is answered from local fixtures. Nothing
//   waits on the real event loop, and nothing leaves the machine.
// * `screenshotMode` stays on. It pins everything this path would otherwise
//   read from the machine: the permission probe returns nothing (so the
//   controller step goes straight to its device list), no update check hits
//   the network, and no BLE scan or connection queue runs. The motion it also
//   switches off — the reveal, the Virtual Shifting stage, the trainer radar —
//   is switched back on through [debugAnimatesInScreenshotMode].
//   App, controller and trainer names on this path are not anonymised by
//   screenshotMode, so the video shows the real "MyWhoosh", "Zwift Ride" and
//   "KICKR CORE" — except the Click V2's, which [debugKeepsControllerNamesInScreenshotMode]
//   keeps. The Click V2 explainer, which screenshotMode suppresses, is let
//   through with [debugClickV2OnboardingInScreenshotMode].
@Tags(['video'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/base_device.dart';
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
    show autoRespondToZwiftHandshake, buildFtmsTrainer, zwiftRideNotification;
import 'package:bike_control/bluetooth/emulation/profiles/zwift_profiles.dart' show buildZwiftController;
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart'
    show
        OtherLocalizationsDelegate,
        debugAnimatesInScreenshotMode,
        debugClickV2OnboardingInScreenshotMode,
        debugKeepsControllerNamesInScreenshotMode,
        screenshotLocale,
        screenshotMode;
import 'package:bike_control/pages/click_v2_onboarding.dart';
import 'package:bike_control/pages/onboarding/onboarding_app_guides.dart' show OnboardingPairAsTrainerCard;
import 'package:bike_control/pages/onboarding/onboarding_page.dart';
import 'package:bike_control/pages/onboarding/steps/step_app.dart' show OnboardingAppTile;
import 'package:bike_control/pages/onboarding/widgets/vs_stage.dart' show debugVirtualShiftingStageOpeningScene;
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratios_editor_page.dart' show debugHideGearCountMismatch;
import 'package:bike_control/pages/proxy_device_details/mini_workout_card.dart' show debugHideMiniWorkoutCard;
import 'package:bike_control/pages/proxy_device_details/gear_hero_card.dart';
import 'package:bike_control/utils/actions/base_actions.dart' show BaseActions, StubActions;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:bike_control/widgets/ui/setting_tile.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
// prop.dart's `SramAxs` is the protocol constants, not the app's device class.
import 'package:prop/prop.dart' as prop show SramAxs;
import 'package:prop/testing.dart' show FakeSramDerailleur;
import 'package:golden_screenshot/golden_screenshot.dart'; // tester.loadAssets()
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import 'helpers/offline_machine.dart';
import 'widget_snapshot.dart';
import 'widget_to_png.dart';

/// The mobile shell (the desktop rail starts at 800).
const _logicalSize = Size(380, 824);

/// 3× gives 1140×2472 px. Placed as a phone in a 1080p frame the screen is
/// roughly 900–1000 px tall, so a full-phone shot is downsampled ~2.5×, and
/// the compositor's 2.2× punch-in still lands on native pixels (at 2× it
/// upscaled ~1.17× past them, softening the text).
const _pixelRatio = 3.0;

const _fps = 30;

/// Settled frames kept before and after every tap (~0.4 s).
const _hold = 12;

/// How long a controller button is held down (~0.3 s) — long enough to read.
const _pressHoldFrames = 9;

/// The Virtual Shifting stage on the trainer step never comes to rest (it
/// cycles its four scenes every 5.5 s), so it gets a fixed run. The film opens
/// it on its gearing scene — the "works in every app" scene is cut, since by
/// step 4 the viewer has already picked a trainer — and leaves before the
/// stage moves on (5 s of its 5.5 s dwell).
const _vsStageOpeningScene = 1;
const _vsStageFrames = 150;

/// Cutaway holds: the opening page, the chosen preset, and each of SIM / ERG.
const _cutawayOpeningFrames = 45;
const _presetHoldFrames = 54;
const _modeHoldFrames = 60;

/// The cutaway starts the gear count here so two taps on + reach MyWhoosh's.
const _cutawayStartGears = 28;

/// Cadence and power the trainer reports during the cutaway, so the chain on
/// the gear card runs.
const _pedallingRpm = 90;
const _pedallingW = 200;

/// Each of the Click V2 explainer's two option pages is held for a ~3 s read
/// (the unlock option's hero loops, so it never rests on its own).
const _clickV2OptionPageFrames = 90;

/// The SRAM authorise step's hero pulses for as long as it is up: it is held
/// ~2 s before the rider acts, and the AXS button ~1.5 s.
const _sramAuthorizeFrames = 60;
const _sramAxsHoldFrames = 45;

/// Extra hold on a screen that is mostly text to read (the SRAM sheet's
/// intro and result, the Click V2 choice) before the rider acts (~1.5 s).
const _readFrames = 45;

const _cutawayScene = 'vs-settings';

const _trainerName = 'KICKR CORE';

/// The "Then in MyWhoosh" screenshots, served from local copies of the
/// website's own files instead of bikecontrol.app.
const _guideFixtures = {
  'https://bikecontrol.app/images/mywhoosh_obc/4-mywhoosh-connection-screen.jpg':
      'test/fixtures/onboarding_guides/mywhoosh_obc/4-mywhoosh-connection-screen.jpg',
  'https://bikecontrol.app/images/mywhoosh_obc/5-mywhoosh-openbikecontrol.jpg':
      'test/fixtures/onboarding_guides/mywhoosh_obc/5-mywhoosh-openbikecontrol.jpg',
  'https://bikecontrol.app/images/mywhoosh_obc/6-bikecontrol-connected.jpg':
      'test/fixtures/onboarding_guides/mywhoosh_obc/6-bikecontrol-connected.jpg',
};

class _Tap {
  _Tap(this.frame, this.x, this.y, this.label, {required this.kind, required this.settledBefore});
  final int frame;
  final double x;
  final double y;
  final String label;

  /// `tap`, `swipe`, `hardware` or `event` — see the header.
  final String kind;

  /// Whether the [_hold] frames before it were unchanged. Only a tap into a
  /// screen that never rests (the Virtual Shifting stage) lacks it.
  final bool settledBefore;

  int? endFrame;
  double? endX;
  double? endY;

  /// For hardware presses: what x/y points at.
  String? anchor;

  Map<String, Object> toJson() => {
        'frame': frame,
        'x': x,
        'y': y,
        'label': label,
        'kind': kind,
        if (endFrame != null) 'endFrame': endFrame!,
        if (endX != null) 'endX': endX!,
        if (endY != null) 'endY': endY!,
        if (anchor != null) 'anchor': anchor!,
      };
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class _Capture {
  final frames = <Uint8List>[];
  final taps = <_Tap>[];

  /// Frames each tap's consequence took to come to rest, keyed by tap label.
  final transitionFrames = <String, int>{};

  /// Chapter names and the frame each one starts on.
  final chapterStarts = <(String, int)>[];

  /// Screens proven to be inside the captured boundary, and the frame each
  /// was first seen on — see [_Recorder.sighting].
  final sightings = <String, int>{};

  List<({String name, int start, int end})> get chapters => [
        for (var i = 0; i < chapterStarts.length; i++)
          (
            name: chapterStarts[i].$1,
            start: chapterStarts[i].$2,
            end: i + 1 < chapterStarts.length ? chapterStarts[i + 1].$2 : frames.length - 1,
          ),
      ];

  String get tapsJson => const JsonEncoder.withIndent('  ').convert([for (final t in taps) t.toJson()]);

  String get chaptersJson => const JsonEncoder.withIndent('  ')
      .convert([
        for (final c in chapters) {'name': c.name, 'start': c.start, 'end': c.end},
      ]);
}

/// Drives the app frame by frame, capturing every frame it pumps.
class _Recorder {
  _Recorder(this.tester, this.boundary);

  final WidgetTester tester;
  final GlobalKey boundary;
  final capture = _Capture();

  /// Frame n is shown at n/30 s. Deriving each pump from the absolute frame
  /// time keeps the sequence exactly 30 fps with no rounding drift.
  static int _timeUs(int frame) => (frame * Duration.microsecondsPerSecond / _fps).round();

  List<Uint8List> get _frames => capture.frames;

  Future<void> _grab() async => _frames.add(await encodeBoundaryToPng(tester, boundary, pixelRatio: _pixelRatio));

  /// Frame 0: what is on screen right now, no time advanced.
  Future<void> first(String chapter) async {
    assert(_frames.isEmpty);
    await _grab();
    capture.chapterStarts.add((chapter, 0));
  }

  /// Advances exactly one frame and captures it.
  Future<void> step() async {
    final n = _frames.length;
    await tester.pump(Duration(microseconds: _timeUs(n) - _timeUs(n - 1)));
    await _grab();
  }

  Future<void> frames(int count) async {
    for (var i = 0; i < count; i++) {
      await step();
    }
  }

  /// Keeps capturing until [total] frames have passed since [since].
  Future<void> holdUntil(int since, int total) async {
    final remaining = since + total - _frames.length;
    if (remaining > 0) await frames(remaining);
  }

  bool _lastTwoEqual() => _frames.length >= 2 && _bytesEqual(_frames[_frames.length - 1], _frames[_frames.length - 2]);

  bool get _settled {
    if (_frames.length <= _hold) return false;
    final last = _frames.last;
    for (var i = _frames.length - _hold; i < _frames.length - 1; i++) {
      if (!_bytesEqual(_frames[i], last)) return false;
    }
    return true;
  }

  /// Starts the next chapter on the current (settled) frame. The previous
  /// chapter ends on the same frame, so the two share an invisible cut.
  /// [settled] false for a chapter that starts where something moves for good
  /// (the running chain in the cutaway) — there is no settled frame to take.
  void chapter(String name, {bool settled = true}) {
    if (settled) {
      expect(_settled, isTrue, reason: 'chapter "$name" must start on a settled frame (frame ${_frames.length - 1})');
    }
    capture.chapterStarts.add((name, _frames.length - 1));
  }

  /// Keeps capturing until [_hold] consecutive frames are unchanged — the
  /// screen has visually finished moving and the compositor has a settled
  /// hold to work with. Returns how many frames that took.
  Future<int> untilStill({int maxFrames = 150}) async {
    final start = _frames.length;
    var still = 0;
    while (still < _hold) {
      if (_frames.length - start >= maxFrames) {
        throw StateError('screen never settled within $maxFrames frames (from frame $start)');
      }
      await step();
      still = _lastTwoEqual() ? still + 1 : 0;
    }
    return _frames.length - start;
  }

  _Tap _record(Offset pos, String label, String kind) {
    final tap = _Tap(_frames.length, pos.dx * _pixelRatio, pos.dy * _pixelRatio, label,
        kind: kind, settledBefore: _settled);
    capture.taps.add(tap);
    return tap;
  }

  /// Records that [what] is on screen in the last captured frame AND is drawn
  /// inside the captured boundary — an overlay (a bottom sheet, a pushed
  /// route) hosted outside it would be missing from the PNGs even though the
  /// widget tree has it.
  void sighting(String name, Finder what) {
    expect(what, findsOneWidget, reason: '"$name" should be on screen');
    final root = boundary.currentContext!.findRenderObject();
    RenderObject? node = tester.renderObject(what);
    while (node != null && node != root) {
      node = node.parent;
    }
    expect(node, same(root), reason: '"$name" must be drawn inside the captured boundary');
    capture.sightings.putIfAbsent(name, () => _frames.length - 1);
  }

  /// A finger press on [finder]'s centre: down, ~100 ms held (so the pressed
  /// state is on film), up — then capture until the result has settled, or
  /// for exactly [thenFrames] when what follows never rests.
  Future<void> tap(Finder finder, String label, {int? thenFrames}) async {
    expect(finder.hitTestable(), findsOneWidget, reason: 'tap target "$label" must be on screen and hittable');
    final pos = tester.getCenter(finder);
    final gesture = await tester.startGesture(pos);
    // The first frame that shows the finger down.
    _record(pos, label, 'tap');
    await frames(3);
    await gesture.up();
    if (thenFrames != null) {
      await frames(thenFrames);
      capture.transitionFrames[label] = thenFrames;
    } else {
      capture.transitionFrames[label] = await untilStill();
    }
  }

  /// A finger dragged from [from] to [to] over [overFrames], then released
  /// and left to settle (the scroll view's own ballistics included).
  Future<void> swipe(Offset from, Offset to, String label, {int overFrames = 15}) async {
    final gesture = await tester.startGesture(from);
    final tap = _record(from, label, 'swipe');
    for (var i = 1; i <= overFrames; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / overFrames)!);
      await step();
    }
    tap
      ..endFrame = _frames.length - 1
      ..endX = to.dx * _pixelRatio
      ..endY = to.dy * _pixelRatio;
    await gesture.up();
    capture.transitionFrames[label] = await untilStill();
  }

  /// Something the app hears from outside, not a touch — [happen] makes it so
  /// through the app's own entry point. Recorded as kind `event` at [at], on
  /// the first frame it can show, then left to settle.
  Future<void> event(String label, Finder at, void Function() happen) async {
    expect(at, findsOneWidget, reason: '"$label" needs a spot on screen');
    final pos = tester.getCenter(at);
    happen();
    _record(pos, label, 'event');
    capture.transitionFrames[label] = await untilStill();
  }

  /// A button on the controller pressed ([press]) and, [holdFrames] later,
  /// released ([release] — none for a controller that reports no release).
  /// Both go in through the device's own decoder, the path a real press
  /// takes. x/y is [at]'s centre, described by [anchor] (see the header).
  Future<void> hardware(
    String label, {
    required Finder at,
    required String anchor,
    required Future<void> Function() press,
    Future<void> Function()? release,
    int holdFrames = _pressHoldFrames,
    int? thenFrames,
  }) async {
    expect(at, findsOneWidget, reason: '"$label" needs a spot on screen');
    final pos = tester.getCenter(at);
    await press();
    _record(pos, label, 'hardware').anchor = anchor;
    await frames(holdFrames);
    if (release != null) await release();
    if (thenFrames != null) {
      await frames(thenFrames);
      capture.transitionFrames[label] = thenFrames;
    } else {
      capture.transitionFrames[label] = await untilStill();
    }
  }

  /// Presses [mask] on a controller speaking the Ride protocol (the Ride, the
  /// Play on firmware 2, a Click V2 puck) and releases it [_pressHoldFrames]
  /// later.
  ///
  /// Both edges go in as the raw keypad notification the controller sends
  /// over BLE, through the device's own decoder (`processCharacteristic` →
  /// `handleButtonsClicked`) — the same path a real press takes. [reactsAt]
  /// locates the x/y recorded: [button] on the contour when one is on screen.
  Future<void> hardwarePress(
    ZwiftRide ride,
    RideButtonMask mask,
    ControllerButton button,
    String label, {
    Finder? reactsAt,
    int? thenFrames,
  }) =>
      hardware(
        label,
        at: reactsAt ?? find.byKey(ValueKey(button.name)),
        anchor: reactsAt == null ? 'contour-button' : 'reaction',
        press: () => ride.processCharacteristic(
          ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
          Uint8List.fromList(zwiftRideNotification(pressed: [mask])),
        ),
        release: () => ride.processCharacteristic(
          ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
          Uint8List.fromList(zwiftRideNotification()),
        ),
        thenFrames: thenFrames,
      );
}

/// The real action pipeline — keymap, pro guard, trainer routing — without any
/// platform key or touch output: a Ride shift lands on the bridged trainer.
class _FilmActions extends BaseActions {
  _FilmActions() : super(supportedModes: const []);

  @override
  void cleanup() {}
}

/// Prefs as they stood before any capture ran, so each capture starts from the
/// same stored state (a capture picks MyWhoosh and a target, which persists).
/// `Settings.reset()` would also re-run `Settings.init()` — Supabase, IAP and
/// window-manager steps whose timeouts would outlive the test.
late final Map<String, Object> _pristinePrefs;

Future<void> _restoreAppState() async {
  final prefs = core.settings.prefs;
  await prefs.clear();
  for (final MapEntry(:key, :value) in _pristinePrefs.entries) {
    switch (value) {
      case final bool v:
        await prefs.setBool(key, v);
      case final int v:
        await prefs.setInt(key, v);
      case final double v:
        await prefs.setDouble(key, v);
      case final String v:
        await prefs.setString(key, v);
      case final List<String> v:
        await prefs.setStringList(key, v);
      default:
        throw StateError('unhandled pref type for $key: ${value.runtimeType}');
    }
  }
  core.settings.trainerAppListenable.value = null;
  // Gearing lives in memory too; reload it from the restored prefs so the
  // cutaway's gear-count and preset changes don't carry into the next take.
  await core.shiftingConfigs.init();
  // A trainer is put back in the gear it was last left in; each take starts
  // from a trainer that was never ridden.
  ProxyDevice.debugClearRememberedGears();
  // A purchased account: nothing in the film is gated or counted down, which
  // is also the only state in which it's honest to show Virtual Shifting
  // without a trial note.
  IAPManager.instance.isPurchased.value = true;
  // Straight into step 1: the film starts at the app step, not the welcome
  // screen. Visually the shell is the same either way.
  await core.settings.setOnboardingState(Settings.onboardingStateCompleted);
  // No trainer app chosen yet — picking MyWhoosh is part of the film.
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

/// Lets real time and fake time pass in turn until [done] completes: parts of
/// a disconnect complete on the real event loop (stream cancellations), which
/// the fake clock never waits for. Never on film.
Future<void> _drive(WidgetTester tester, Future<void> done, String what) async {
  var finished = false;
  unawaited(done.whenComplete(() => finished = true));
  for (var i = 0; i < 100 && !finished; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finished, isTrue, reason: what);
}

/// A BLE controller as the connected-controllers list shows it: the real device
/// class over a hand-made scan result, connected, with the meta a connected
/// controller reports. Staged the way screenshot_test.dart stages its
/// controllers — no Bluetooth link behind it.
T _staged<T extends BaseDevice>(T device) {
  if (device case final ZwiftRide d) {
    d
      ..firmwareVersion = '1.2.0'
      ..rssi = -51
      ..batteryLevel = 81;
  } else if (device case final ShimanoDi2 d) {
    d
      ..rssi = -51
      ..batteryLevel = 81;
  }
  device.isConnected = true;
  return device;
}

/// The controller a MyWhoosh take is filmed with, and what happens on its step.
abstract class _ControllerTake {
  _ControllerTake({required this.scene, required this.slug, required this.name});

  /// Output folder under build/video_frames.
  final String scene;

  /// The website's device slug.
  final String slug;

  /// The controller's display name, for the compositor's overlay text.
  final String name;

  /// The controller step as (kind, label), in order, from "Continue to
  /// controller" on.
  List<(String, String)> get beats;

  /// Beats that go into a screen that never rests.
  Set<String> get unsettledBeats => const {};

  /// Whether the controller has a contour on the step that reacts to presses.
  bool get hasContour => true;

  /// Screens the take must have filmed (see [_Recorder.sighting]).
  List<String> get sightings => const [];

  /// SVGs the step draws, decoded before the first recorded frame.
  List<String> get svgAssets;

  /// Puts the controller in range (not on film).
  Future<void> stage(WidgetTester tester, _Stage stage);

  /// Films step 3, from the tap on "Continue to controller" to the last press.
  Future<void> film(WidgetTester tester, _Recorder rec);

  /// Takes the controller away again, so the next take starts without it.
  Future<void> unstage(WidgetTester tester, _Stage stage);
}

/// Forwards [device]'s presses to the wizard the way Connection does for a
/// device it connected. A staged controller is never BLE-connected, so that
/// one forwarding line is done here. Not awaited on cancel: a broadcast
/// subscription's cancel() completes on the real event loop, and awaiting it
/// would take the test body off the fake clock for good.
StreamSubscription<BaseNotification> _forward(BaseDevice device) =>
    device.actionStream.listen(core.connection.signalNotification);

/// Unmounts nothing: removes a staged controller from the device list.
Future<void> _unstageStaged(WidgetTester tester, BaseDevice device) async {
  device.isConnected = false;
  await _drive(tester, core.connection.disconnect(device, forget: true, persistForget: false),
      '${device.runtimeType} should have been removed');
}

class _RideTake extends _ControllerTake {
  _RideTake(this.ride) : super(scene: 'mywhoosh-controller', slug: 'zwift-ride', name: 'Zwift Ride');

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
    core.connection.addDevices([_staged(ride)]);
  }

  @override
  Future<void> film(WidgetTester tester, _Recorder rec) async {
    await rec.tap(find.byType(PrimaryButton).last, 'Continue to controller');

    // Step 3 — controller: the connected Ride is listed with its contour.
    expect(find.text(ride.displayName(tester.element(find.byType(OnboardingPage)))), findsOneWidget,
        reason: 'should be on the controller step with the Ride listed');

    // Press buttons on the Ride — a shift, a steer, a shift the other way.
    final forward = _forward(ride);
    await rec.hardwarePress(ride, RideButtonMask.SHFT_UP_R_BTN, ZwiftButtons.shiftUpRight, 'Ride button: Shift up');
    await rec.hardwarePress(ride, RideButtonMask.LEFT_BTN, ZwiftButtons.navigationLeft, 'Ride button: Steer left');
    await rec.hardwarePress(ride, RideButtonMask.SHFT_DN_L_BTN, ZwiftButtons.shiftDownLeft, 'Ride button: Shift down');
    unawaited(forward.cancel());
  }

  @override
  Future<void> unstage(WidgetTester tester, _Stage stage) => _unstageStaged(tester, ride);
}

/// A Zwift Play on firmware 2 — what Zwift Companion puts on a Play today.
/// On it both halves report over one link in the Ride's protocol, so the app
/// lists one "Zwift Play" with both halves on its contour (firmware 1 listed
/// the halves as two separate controllers).
class _PlayTake extends _ControllerTake {
  _PlayTake() : super(scene: 'mywhoosh-zwift-play', slug: 'zwift-play', name: 'Zwift Play');

  late ZwiftPlayFw2 play;

  @override
  List<(String, String)> get beats => const [
        ('tap', 'Continue to controller'),
        ('hardware', 'Play button: Shift up'),
        ('hardware', 'Play button: Steer left'),
        ('hardware', 'Play button: Shift down'),
      ];

  @override
  List<String> get svgAssets => [play.controllerLayout.svgAsset!];

  @override
  Future<void> stage(WidgetTester tester, _Stage stage) async {
    play = ZwiftPlayFw2(BleDevice(name: 'Zwift Play', deviceId: '00:11:22:33:44:66'));
    _staged(play).firmwareVersion = '2.0.1';
    core.connection.addDevices([play]);
  }

  @override
  Future<void> film(WidgetTester tester, _Recorder rec) async {
    await rec.tap(find.byType(PrimaryButton).last, 'Continue to controller');
    expect(find.text(play.displayName(tester.element(find.byType(OnboardingPage)))), findsOneWidget,
        reason: 'should be on the controller step with the Play listed');

    // The right half's shift button, the left half's D-pad, the left half's
    // shift button.
    final forward = _forward(play);
    await rec.hardwarePress(play, RideButtonMask.SHFT_UP_R_BTN, ZwiftButtons.shiftUpRight, 'Play button: Shift up');
    await rec.hardwarePress(play, RideButtonMask.LEFT_BTN, ZwiftButtons.navigationLeft, 'Play button: Steer left');
    await rec.hardwarePress(play, RideButtonMask.SHFT_UP_L_BTN, ZwiftButtons.shiftUpLeft, 'Play button: Shift down');
    unawaited(forward.cancel());
  }

  @override
  Future<void> unstage(WidgetTester tester, _Stage stage) => _unstageStaged(tester, play);
}

/// Both Click V2 pucks in range, as a rider with a new Click V2 has them. They
/// are held back for the unlock explainer, which opens by itself on step 3.
/// The rider picks "Use the right side": everything happens inside BikeControl
/// (no Zwift app), the left puck is set aside and the right one connects —
/// over the offline machine's Bluetooth, through the app's real connect path.
class _ClickV2Take extends _ControllerTake {
  _ClickV2Take() : super(scene: 'mywhoosh-zwift-click-v2', slug: 'zwift-click-v2', name: 'Zwift Click V2');

  static const _leftId = 'film-click-v2-left';
  static const _rightId = 'film-click-v2-right';

  late ZwiftClickV2LeftSide left;
  late ZwiftClickV2RightSide right;

  @override
  List<(String, String)> get beats => const [
        ('tap', 'Continue to controller'),
        ('tap', 'Click V2 setup: next option'),
        ('tap', 'Click V2 setup: to the choice'),
        ('tap', 'Use the right side'),
        ('hardware', 'Click V2 button: Shift up (+)'),
        ('hardware', 'Click V2 button: Shift down (B)'),
      ];

  @override
  // The unlock option's hero loops (its padlock); the right-side one rests.
  Set<String> get unsettledBeats => const {'Click V2 setup: to the choice'};

  @override
  List<String> get sightings => const ['click-v2-explainer', 'click-v2-choice'];

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

    // Built from the scan results the way the scanner builds them (the split
    // left/right representation is the default).
    left = ZwiftClickV2LeftSide(puck(_leftId, ZwiftConstants.CLICK_V2_LEFT_SIDE).scanResult);
    right = ZwiftClickV2RightSide(puck(_rightId, ZwiftConstants.CLICK_V2_RIGHT_SIDE).scanResult);
    core.connection.addDevices([left, right]);
  }

  @override
  Future<void> film(WidgetTester tester, _Recorder rec) async {
    final l10n = AppLocalizations.current;
    // Entering step 3 with a new Click V2 in range opens the explainer.
    await rec.tap(find.byType(PrimaryButton).last, 'Continue to controller', thenFrames: _clickV2OptionPageFrames);
    rec.sighting('click-v2-explainer', find.byType(ClickV2OnboardingPage));
    expect(find.text(l10n.clickV2Onboarding_rightOnlyTitle), findsOneWidget);

    // Both options, one page each, then the choice.
    await rec.tap(find.byKey(const ValueKey('click-onboarding-swipe-hint-0')), 'Click V2 setup: next option',
        thenFrames: _clickV2OptionPageFrames);
    expect(find.text(l10n.clickV2Onboarding_zwiftTitle).hitTestable(), findsOneWidget);
    await rec.tap(find.byKey(const ValueKey('click-onboarding-swipe-hint-1')), 'Click V2 setup: to the choice');
    rec.sighting('click-v2-choice', find.text(l10n.clickV2Onboarding_decisionTitle));
    expect(find.text(l10n.clickV2Onboarding_zwiftCta).hitTestable(), findsOneWidget,
        reason: 'both options are offered side by side');
    await rec.frames(_readFrames);

    // The option a rider finishes inside BikeControl: the right side alone.
    await rec.tap(find.text(l10n.clickV2Onboarding_rightOnlyCta), 'Use the right side');
    expect(find.byType(ClickV2OnboardingPage), findsNothing, reason: 'the explainer closes on a choice');
    expect(core.settings.getClickV2RightSideOnly(), isTrue);
    expect(right.isConnected, isTrue, reason: 'the right puck connects once chosen');
    expect(core.connection.devices, isNot(contains(left)), reason: 'the left puck is set aside');

    // The right puck on its own: + shifts up, B shifts down (the choice remaps
    // it, so one puck covers both directions).
    await rec.hardwarePress(right, RideButtonMask.SHFT_UP_R_BTN, ZwiftButtons.shiftUpRight,
        'Click V2 button: Shift up (+)');
    await rec.hardwarePress(right, RideButtonMask.B_BTN, ZwiftButtons.b, 'Click V2 button: Shift down (B)');
  }

  @override
  Future<void> unstage(WidgetTester tester, _Stage stage) async {
    for (final d in [left, right]) {
      if (core.connection.devices.contains(d)) {
        await _drive(tester, core.connection.disconnect(d, forget: true, persistForget: false),
            '$d should have disconnected');
      }
    }
    stage.machine.ble
      ..removePeripheral(_leftId)
      ..removePeripheral(_rightId);
  }
}

/// A Shimano Di2 rear derailleur, its shifters' buttons set to D-Fly channels.
/// Di2 has no contour in onboarding: its row is all the step shows, and
/// nothing on screen reacts to a press.
class _Di2Take extends _ControllerTake {
  _Di2Take() : super(scene: 'mywhoosh-shimano-di2', slug: 'shimano-di2', name: 'Shimano Di2');

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
    core.connection.addDevices([_staged(di2)]);
    // The derailleur reports its D-Fly state when the app subscribes; the
    // first frame is the baseline its buttons are discovered from.
    await _channels(const [0x00, 0x00, 0x00]);
  }

  @override
  Future<void> film(WidgetTester tester, _Recorder rec) async {
    await rec.tap(find.byType(PrimaryButton).last, 'Continue to controller');
    final row = find.text(di2.displayName(tester.element(find.byType(OnboardingPage))));
    expect(row, findsOneWidget, reason: 'should be on the controller step with the Di2 listed');

    final forward = _forward(di2);
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
  Future<void> unstage(WidgetTester tester, _Stage stage) => _unstageStaged(tester, di2);
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
  _SramTake() : super(scene: 'mywhoosh-sram-axs', slug: 'sram-axs-etap', name: 'SRAM AXS');

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
  Set<String> get unsettledBeats => const {'AXS button: Press & hold', 'SRAM setup: Retry'};

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
    // The derailleur's notifications are handed to the device where the
    // connection layer hands them over (as the Ride's are).
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
    await _drive(tester, core.connection.connectDevice(sram), 'the derailleur should have connected');
    expect(sram.isConnected, isTrue);
    expect(sram.needsGuidedSetup, isTrue);
  }

  @override
  Future<void> film(WidgetTester tester, _Recorder rec) async {
    final l10n = AppLocalizations.current;
    // Entering step 3 with the derailleur connected opens its guided setup.
    await rec.tap(find.byType(PrimaryButton).last, 'Continue to controller');
    rec.sighting('sram-setup-confirm', find.byType(SramGuidedSheet));
    expect(find.text(l10n.sramSetupIntro), findsOneWidget);
    await rec.frames(_readFrames);

    Finder sheetButton(String text) =>
        find.descendant(of: find.byType(SramGuidedSheet), matching: find.widgetWithText(PrimaryButton, text));
    await rec.tap(sheetButton(l10n.continueAction), 'SRAM setup: Continue',
        thenFrames: _sramAuthorizeFrames);
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
    await rec.tap(sheetButton(l10n.retry), 'SRAM setup: Retry');
    rec.sighting('sram-setup-success', find.text(l10n.sramAllSet));
    expect(sram.isShiftingDisabled, isTrue, reason: "setup should have handed the paddles to BikeControl");
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
    await _drive(tester, core.connection.disconnect(sram, forget: true, persistForget: false),
        'the derailleur should have disconnected');
    stage.machine.ble.removePeripheral(_id);
  }
}

/// One take of the MyWhoosh wizard with [take]'s controller on step 3. The
/// Ride take goes on into the gearing cutaway on the bridged trainer's page
/// ([withCutaway]).
Future<({_Capture onboarding, _Capture? cutaway})> _captureMyWhoosh(
  WidgetTester tester,
  _Stage stage,
  _ControllerTake take, {
  ZwiftRide? withCutaway,
}) async {
  await _restoreAppState();
  await take.stage(tester, stage);

  // An FTMS smart trainer in range, as the scan would have found it.
  final peripheral = buildFtmsTrainer(deviceId: 'film-kickr', name: _trainerName);
  stage.machine.ble.addPeripheral(peripheral);
  final trainer = stage.trainer = ProxyDevice(peripheral.scanResult);
  core.connection.addDevices([trainer]);

  tester.view.physicalSize = _logicalSize * _pixelRatio;
  tester.view.devicePixelRatio = _pixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // performScanning early-returns while this is set, so the controller step
  // never starts a scan of its own.
  core.connection.isScanning.value = true;
  addTearDown(() => core.connection.isScanning.value = false);

  final boundary = GlobalKey();
  Widget app(Widget home) => RepaintBoundary(
        key: boundary,
        child: ShadcnApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('en'),
          localizationsDelegates: [
            ...ShadcnLocalizations.localizationsDelegates,
            const OtherLocalizationsDelegate(),
            AppLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          theme: snapshotTheme(Brightness.light),
          materialTheme: m.ThemeData(),
          home: home,
        ),
      );

  // ── Warm-up (not recorded): decode every asset the film shows. ──────────
  await tester.pumpWidget(app(const OnboardingPage()));
  await tester.pump();
  // Every bundled font family, not just the ones step 1 happens to use: later
  // steps draw Material and other icon glyphs, which would otherwise be tofu.
  // (loadString, not loadStructuredData: that caches the parsed result under
  // the same key loadAssets later reads the manifest from.)
  final manifest = await tester.runAsync(() => rootBundle.loadString('FontManifest.json', cache: false));
  final bundledFonts = [for (final f in jsonDecode(manifest!) as List) (f as Map)['family'] as String];
  await tester.loadAssets(alsoLoadTheseFonts: bundledFonts, searchWidgetTreeForImages: false);
  final assetContext = tester.element(find.byType(OnboardingPage));
  await tester.runAsync(() async {
    await Future.wait([
      precacheImage(const AssetImage('icon.png'), assetContext),
      for (final a in SupportedApp.supportedApps)
        if (a.logoAsset != null) precacheImage(AssetImage(a.logoAsset!), assetContext),
      for (final svg in take.svgAssets) SvgAssetLoader(svg).loadBytes(assetContext),
      // Fetched through the offline HTTP client from the local fixtures.
      for (final url in _guideFixtures.keys) precacheImage(NetworkImage(url), assetContext),
    ]);
  });
  await tester.pumpWidget(app(const SizedBox()));
  await tester.pump();

  // ── The wizard. Frame 0 is the app step's first frame. ───────────────────
  final rec = _Recorder(tester, boundary);
  await tester.pumpWidget(app(const OnboardingPage()));
  await rec.first('app');
  rec.capture.transitionFrames['app step reveal'] = await rec.untilStill();

  // Step 1 — trainer app.
  await rec.tap(find.byWidgetPredicate((w) => w is OnboardingAppTile && w.app is MyWhoosh), 'MyWhoosh tile');
  rec.chapter('where');
  await rec.tap(find.byType(PrimaryButton).last, 'Continue with MyWhoosh');

  // Step 2 — where: MyWhoosh on this device.
  await rec.tap(find.byKey(const ValueKey('onboarding-where-thisDevice')), 'This Device');
  rec.chapter('controller');

  // Step 3 — controller: the take's own.
  final l10n = AppLocalizations.current;
  await take.film(tester, rec);

  // Step 4 — trainer: the Virtual Shifting stage plays, then the KICKR CORE
  // listed in the scan card is tapped and bridged over the real picker path.
  rec.chapter('trainer');
  await rec.tap(find.byType(PrimaryButton).last, 'Continue to trainer', thenFrames: _vsStageFrames);
  await rec.tap(find.text(_trainerName), _trainerName);
  expect(trainer.isBridged, isTrue, reason: 'tapping the trainer should bridge it');

  // Step 5 — link the app: switch on the recommended Network method, then
  // scroll down to the "Then in MyWhoosh" guide and the pair-as-trainer card.
  rec.chapter('link-app');
  await rec.tap(find.byType(PrimaryButton).last, 'Continue to connection');
  final network = find.text(l10n.onboardingMethodNetwork);
  await rec.tap(network, 'Network');
  expect(core.settings.getObpMdnsEnabled(), isTrue, reason: 'the Network method should be on');
  await rec.swipe(const Offset(190, 600), const Offset(190, 330), 'Scroll to the guide');
  expect(find.byType(Image), findsWidgets);
  await rec.swipe(const Offset(190, 330), const Offset(190, 600), 'Scroll back to the methods');

  // MyWhoosh, following the guide, connects: it sends its app info over the
  // Network method, through the emulator's own message handler.
  await rec.event('MyWhoosh connects', network, () {
    core.obpMdnsEmulator.onMessage(OpenBikeProtocolParser.encodeAppInfo(
      appId: 'MyWhoosh',
      appVersion: '1.0',
      supportedButtons: MyWhoosh().defaultObpSupportedButtons,
    ));
  });
  expect(core.obpMdnsEmulator.isConnected.value, isTrue);
  expect(find.text(l10n.networkTroubleshootTroubleshoot), findsNothing,
      reason: 'the troubleshoot offer goes once the app is connected');

  await rec.swipe(const Offset(190, 700), const Offset(190, 80), 'Scroll to pairing');
  // …and pairs "KICKR CORE - BikeControl" as its trainer: the bridge's
  // emulator reports the app holding the virtual trainer.
  await rec.event('MyWhoosh pairs the trainer', find.byType(OnboardingPairAsTrainerCard), () {
    ftmsEmulator.isConnected.value = true;
  });
  expect(trainer.isConnectedListenable.value, isTrue);

  // Step 6 — done, and ready.
  rec.chapter('done');
  await rec.tap(find.byType(PrimaryButton).last, 'Finish setup');
  expect(find.text(l10n.onboardingDoneTitle), findsOneWidget, reason: 'the take should end ready to ride');
  expect(find.text(l10n.onboardingDoneStartRiding), findsOneWidget);

  final ride = withCutaway;
  if (ride == null) {
    await _unbridge(tester, stage, peripheral.deviceId);
    await take.unstage(tester, stage);
    return (onboarding: rec.capture, cutaway: null);
  }

  // ── The cutaway: the bridged trainer's own page. ─────────────────────────
  // Its own take, on the same bridged trainer. Shifts go through the real
  // action pipeline from here on, so a Ride press changes the trainer's gear.
  core.actionHandler = _FilmActions()..init(core.settings.getTrainerApp());
  final definition = trainer.fitnessBike!;
  // The gear count starts two short of MyWhoosh's, so the stepper gets there.
  definition.setMaxGear(_cutawayStartGears);
  await core.shiftingConfigs.upsert(
    core.shiftingConfigs.activeFor(trainer.trainerKey).copyWith(maxGear: _cutawayStartGears),
  );
  // The rider is pedalling: the trainer sends FTMS Indoor Bike Data about once
  // a second. Each packet goes in where the connection layer hands a trainer
  // notification to the device (as the Ride presses do), and from there
  // through the bridge's own parser.
  void pedal() => unawaited(trainer.processCharacteristic(
        FitnessBikeDefinition.INDOOR_BIKE_DATA_UUID,
        Uint8List.fromList(_indoorBikeData(cadenceRpm: _pedallingRpm, powerW: _pedallingW)),
      ));
  pedal();
  final pedalling = Timer.periodic(const Duration(seconds: 1), (_) => pedal());
  final cut = _Recorder(tester, boundary);
  await tester.pumpWidget(app(const SizedBox()));
  await tester.pump();
  await tester.pumpWidget(app(ProxyDeviceDetailsPage(device: trainer)));
  await cut.first('gearing');
  expect(definition.cadenceRpm.value, _pedallingRpm, reason: 'the trainer should be reporting cadence');
  expect(find.text(l10n.miniWorkout), findsNothing, reason: 'the Mini Workout card is kept off this video');
  // The page opens on the running chain; hold it before the first tap.
  await cut.frames(_cutawayOpeningFrames - 1);

  // (a) Your gearing, your way.
  await cut.tap(find.text(l10n.gearSettings), 'Gear settings');
  await cut.tap(find.byWidgetPredicate((w) => w is Switch).first, 'Front derailleur');
  final plus = find.descendant(of: find.widgetWithText(SettingTile, l10n.gearCount), matching: find.byIcon(LucideIcons.plus));
  await cut.tap(plus, 'Gear count +');
  await cut.tap(plus, 'Gear count + again');
  expect(definition.maxGear, MyWhoosh().virtualGearAmount);
  final mismatch = l10n.gearCountMismatch(MyWhoosh().name, MyWhoosh().virtualGearAmount, _cutawayStartGears);
  expect(find.text(mismatch), findsNothing, reason: 'the gear-count warning is kept off this video');
  await cut.swipe(const Offset(190, 640), const Offset(190, 300), 'Scroll to presets');
  await cut.tap(find.text(l10n.presetCompact), 'Compact preset');
  // Rest on the chosen preset.
  final compact = cut.capture.taps.last.frame;
  await cut.holdUntil(compact, _presetHoldFrames);
  // Back on the page the chain is running again: nothing settles from here.
  await cut.tap(find.byIcon(LucideIcons.arrowLeft), 'Back', thenFrames: 30);

  // (b) Direct gear changes: two Ride shifts land on the gear card, and the
  // chain walks to the next cog each time.
  cut.chapter('direct-gear-changes', settled: false);
  final gearCard = find.byType(GearHeroCard);
  for (final label in ['Ride button: Shift up', 'Ride button: Shift up again']) {
    final before = definition.currentGear.value;
    await cut.hardwarePress(ride, RideButtonMask.SHFT_UP_R_BTN, ZwiftButtons.shiftUpRight, label,
        reactsAt: gearCard, thenFrames: 30);
    expect(definition.currentGear.value, before + 1, reason: '"$label" should shift the trainer up a gear');
  }

  // (c) SIM & ERG: the card's own mode switch, each held so it reads.
  cut.chapter('sim-erg', settled: false);
  final modeSwitch = find.descendant(of: gearCard, matching: find.byWidgetPredicate((w) => w is Switch));
  await cut.tap(modeSwitch, 'ERG', thenFrames: _modeHoldFrames - 3);
  expect(definition.trainerMode.value, TrainerMode.ergMode);
  await cut.tap(modeSwitch, 'SIM', thenFrames: _modeHoldFrames - 3);
  expect(definition.trainerMode.value, TrainerMode.simMode);
  pedalling.cancel();

  await _unbridge(tester, stage, peripheral.deviceId);
  await take.unstage(tester, stage);
  return (onboarding: rec.capture, cutaway: cut.capture);
}

/// Unmounts (cancelling the wizard's timers) and unbridges, so the next take
/// finds the trainer — and MyWhoosh — the way this one did. None of this is on
/// film.
Future<void> _unbridge(WidgetTester tester, _Stage stage, String peripheralId) async {
  final trainer = stage.trainer;
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  // Disconnecting detaches the trainer's definition from the emulator but does
  // not dispose it, which leaves its 1 s notify timer running; it is stopped
  // below.
  final definition = trainer.fitnessBike;
  await _drive(tester, core.connection.disconnect(trainer, forget: true, persistForget: false),
      'the trainer should have disconnected');
  definition?.dispose();
  ftmsEmulator.isConnected.value = false;
  core.obpMdnsEmulator.stopServer();
  await tester.pump(const Duration(seconds: 1));
  stage.machine.ble.removePeripheral(peripheralId);
}

/// An FTMS Indoor Bike Data packet: instantaneous speed (always present),
/// cadence (0.5 rpm units) and power, as a trainer notifies it.
List<int> _indoorBikeData({required int cadenceRpm, required int powerW}) {
  const flags = 0x0004 | 0x0040; // cadence present | power present
  final speed = 3000; // 30.00 km/h
  final cadence = cadenceRpm * 2;
  return [
    flags & 0xff, flags >> 8,
    speed & 0xff, speed >> 8,
    cadence & 0xff, cadence >> 8,
    powerW & 0xff, (powerW >> 8) & 0xff,
  ];
}

List<String> _frameHashes(_Capture c) => [for (final f in c.frames) sha256.convert(f).toString()];

String _sequenceHash(_Capture c) => sha256.convert(utf8.encode(_frameHashes(c).join())).toString();

(int, int) _pngSize(Uint8List png) {
  // IHDR: width and height are big-endian u32 at bytes 16 and 20.
  final d = ByteData.sublistView(png);
  return (d.getUint32(16), d.getUint32(20));
}

void _writeScene(String scene, _Capture capture, {_ControllerTake? controller}) {
  final dir = Directory('build/video_frames/$scene');
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);
  for (var i = 0; i < capture.frames.length; i++) {
    File('${dir.path}/${i.toString().padLeft(6, '0')}.png').writeAsBytesSync(capture.frames[i]);
  }
  File('${dir.path}/taps.json').writeAsStringSync(capture.tapsJson);
  File('${dir.path}/chapters.json').writeAsStringSync(capture.chaptersJson);
  final (width, height) = _pngSize(capture.frames.first);
  File('${dir.path}/scene.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
    'pixelRatio': _pixelRatio,
    'width': width,
    'height': height,
    'logicalWidth': _logicalSize.width,
    'logicalHeight': _logicalSize.height,
    'fps': _fps,
    'frames': capture.frames.length,
    if (controller != null) ...{
      'controller': controller.slug,
      'controllerName': controller.name,
    },
  }));
}

void _expectWellFormed(_Capture capture, {required Set<String> unsettledTaps, bool settledCuts = true}) {
  final (width, height) = _pngSize(capture.frames.first);
  expect((width, height), ((_logicalSize.width * _pixelRatio).round(), (_logicalSize.height * _pixelRatio).round()));
  for (final f in capture.frames) {
    expect(_pngSize(f), (width, height), reason: 'every frame must share one size');
  }
  for (final t in capture.taps) {
    expect(t.x, inInclusiveRange(0, width), reason: t.label);
    expect(t.y, inInclusiveRange(0, height), reason: t.label);
    expect(t.frame, inExclusiveRange(0, capture.frames.length), reason: t.label);
    // A settled hold precedes every tap, except into a screen that never rests.
    expect(t.settledBefore, !unsettledTaps.contains(t.label), reason: 'hold before "${t.label}"');
  }
  // Every cut between chapters is on a settled frame.
  final chapters = capture.chapters;
  for (var i = 1; i < chapters.length; i++) {
    final b = chapters[i].start;
    expect(chapters[i - 1].end, b);
    if (settledCuts) {
      expect(_bytesEqual(capture.frames[b], capture.frames[b - 1]), isTrue,
          reason: 'boundary into "${chapters[i].name}" (frame $b) must be settled');
    }
  }
  expect(chapters.last.end, capture.frames.length - 1);
  if (settledCuts) {
    expect(_bytesEqual(capture.frames.last, capture.frames[capture.frames.length - 2]), isTrue,
        reason: 'the take ends on a settled frame');
  }
}

/// How many of the frames from [t]'s on differ from the one before it.
int _reactingFrames(_Capture capture, _Tap t) {
  final before = capture.frames[t.frame - 1];
  return [for (var i = t.frame; i < t.frame + _pressHoldFrames + _hold; i++) capture.frames[i]]
      .where((f) => !_bytesEqual(f, before))
      .length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A connected Zwift Ride, staged the way screenshot_test.dart stages its
  // controllers: the real device class over a hand-made scan result. The
  // same object carries on into the cutaway.
  final ride = ZwiftRide(BleDevice(name: 'Zwift Ride', deviceId: '00:11:22:33:44:55'));
  final rideTake = _RideTake(ride);
  final takes = <_ControllerTake>[_PlayTake(), _ClickV2Take(), _Di2Take(), _SramTake()];
  late _Stage stage;

  // In setUpAll rather than main(): under the fake-clock binding, Supabase's
  // initialisation inside Settings.init() needs to run in a test zone.
  setUpAll(() async {
    await ensureSnapshotAppState();
    _pristinePrefs = {for (final k in core.settings.prefs.getKeys()) k: core.settings.prefs.get(k)!};
    stage = _Stage(OfflineMachine.install(httpFixtures: _guideFixtures));
  });

  setUp(() {
    // Keep the plumbing pinned (see the header) but let the wizard move.
    screenshotMode = true;
    debugAnimatesInScreenshotMode = true;
    debugClickV2OnboardingInScreenshotMode = true;
    debugKeepsControllerNamesInScreenshotMode = true;
    debugVirtualShiftingStageOpeningScene = _vsStageOpeningScene;
    debugHideGearCountMismatch = true;
    debugHideMiniWorkoutCard = true;
    addTearDown(() {
      debugAnimatesInScreenshotMode = false;
      debugClickV2OnboardingInScreenshotMode = false;
      debugKeepsControllerNamesInScreenshotMode = false;
      debugVirtualShiftingStageOpeningScene = null;
      debugHideGearCountMismatch = false;
      debugHideMiniWorkoutCard = false;
    });
  });

  const intoController = [
    ('tap', 'MyWhoosh tile'),
    ('tap', 'Continue with MyWhoosh'),
    ('tap', 'This Device'),
  ];

  const linkAndDone = [
    ('tap', 'Continue to connection'),
    ('tap', 'Network'),
    ('swipe', 'Scroll to the guide'),
    ('swipe', 'Scroll back to the methods'),
    ('event', 'MyWhoosh connects'),
    ('swipe', 'Scroll to pairing'),
    ('event', 'MyWhoosh pairs the trainer'),
    ('tap', 'Finish setup'),
  ];

  void expectStepChangesAnimate(_Capture capture, List<String> labels) {
    // A step change is filmed as Flutter's own reveal, not a cut: the content
    // eases in over many distinct frames before the settled hold.
    for (final label in labels) {
      expect(capture.transitionFrames[label]! - _hold, greaterThan(20),
          reason: '"$label" should animate across frames, not cut');
    }
  }

  void expectStagePlays(_Capture capture, String into) {
    final tap = capture.taps.firstWhere((t) => t.label == into);
    final stageFrames = capture.frames.sublist(tap.frame + 60, tap.frame + _vsStageFrames);
    expect(stageFrames.map(sha256.convert).toSet().length, greaterThan(30),
        reason: 'the Virtual Shifting stage should be moving on film');
  }

  /// Everything every wizard take must hold, whatever the controller.
  void expectWizardTake(_ControllerTake take, _Capture onboarding) {
    final info = jsonDecode(File('build/video_frames/${take.scene}/scene.json').readAsStringSync()) as Map;
    expect(info['pixelRatio'], 3);
    expect(info['frames'], onboarding.frames.length);
    expect(info['controller'], take.slug);
    expect(info['controllerName'], take.name);
    expect(_pngSize(onboarding.frames.first), (1140, 2472), reason: take.scene);

    expect(onboarding.taps.map((t) => (t.kind, t.label)), [
      ...intoController,
      ...take.beats,
      ('tap', 'Continue to trainer'),
      ('tap', _trainerName),
      ...linkAndDone,
    ]);
    expect(onboarding.chapters.map((c) => c.name), ['app', 'where', 'controller', 'trainer', 'link-app', 'done']);
    _expectWellFormed(onboarding, unsettledTaps: {_trainerName, ...take.unsettledBeats});
    expect(onboarding.sightings.keys, containsAll(take.sightings));

    // A press visibly reacts on a controller's contour; with no contour on
    // the step, nothing on screen does. MyWhoosh connecting always shows.
    for (final t in onboarding.taps.where((t) => t.kind == 'hardware' && t.anchor == 'contour-button')) {
      expect(_reactingFrames(onboarding, t), greaterThan(3), reason: '"${t.label}" should visibly react on film');
    }
    if (!take.hasContour) {
      expect(onboarding.taps.where((t) => t.kind == 'hardware' && t.anchor == 'contour-button'), isEmpty);
    }
    final connects = onboarding.taps.firstWhere((t) => t.label == 'MyWhoosh connects');
    expect(_reactingFrames(onboarding, connects), greaterThan(3), reason: 'MyWhoosh connecting should show on film');

    expectStepChangesAnimate(onboarding, ['app step reveal', 'Continue with MyWhoosh', 'Continue to connection']);
    expectStagePlays(onboarding, 'Continue to trainer');
  }

  void report(String scene, _Capture capture, Duration took) {
    // ignore: avoid_print
    print('video capture: $scene ${capture.frames.length} frames '
        '(${(capture.frames.length / _fps).toStringAsFixed(2)} s) in ${took.inMilliseconds} ms, '
        'sequence sha256 ${_sequenceHash(capture)}\n'
        '$scene chapters: ${capture.chaptersJson}\n'
        '$scene taps: ${capture.tapsJson}');
  }

  testWidgets('captures the MyWhoosh take and the gearing cutaway as 30 fps frame sequences', (tester) async {
    final watch = Stopwatch()..start();
    final (:onboarding, :cutaway) = await _captureMyWhoosh(tester, stage, rideTake, withCutaway: ride);
    watch.stop();
    _writeScene(rideTake.scene, onboarding, controller: rideTake);
    _writeScene(_cutawayScene, cutaway!);

    // Rendered at 3× so text stays sharp through the compositor's 2.2×
    // punch-in; scene.json says so, so nothing downstream has to guess.
    for (final (scene, capture) in [(rideTake.scene, onboarding), (_cutawayScene, cutaway)]) {
      expect(_pngSize(capture.frames.first), (1140, 2472), reason: scene);
      final info = jsonDecode(File('build/video_frames/$scene/scene.json').readAsStringSync()) as Map;
      expect(info['pixelRatio'], 3);
      expect(info['frames'], capture.frames.length);
    }

    expectWizardTake(rideTake, onboarding);
    // The controller step change too (the other takes open a sheet or a
    // page over it).
    expectStepChangesAnimate(onboarding, ['Continue to controller']);

    expect(cutaway.taps.map((t) => (t.kind, t.label)), [
      ('tap', 'Gear settings'),
      ('tap', 'Front derailleur'),
      ('tap', 'Gear count +'),
      ('tap', 'Gear count + again'),
      ('swipe', 'Scroll to presets'),
      ('tap', 'Compact preset'),
      ('tap', 'Back'),
      ('hardware', 'Ride button: Shift up'),
      ('hardware', 'Ride button: Shift up again'),
      ('tap', 'ERG'),
      ('tap', 'SIM'),
    ]);
    expect(cutaway.chapters.map((c) => c.name), ['gearing', 'direct-gear-changes', 'sim-erg']);
    // The chain runs whenever the gear card is on screen, so taps on that page
    // and the beat boundaries there can't wait for a still frame.
    _expectWellFormed(
      cutaway,
      unsettledTaps: const {'Gear settings', 'Ride button: Shift up', 'Ride button: Shift up again', 'ERG'},
      settledCuts: false,
    );
    int at(String label) => cutaway.taps.firstWhere((t) => t.label == label).frame;
    expect(at('Gear settings'), greaterThanOrEqualTo(_cutawayOpeningFrames), reason: 'hold the opening page');
    expect(at('Back') - at('Compact preset'), greaterThanOrEqualTo(_presetHoldFrames), reason: 'hold the preset');
    expect(at('SIM') - at('ERG'), greaterThanOrEqualTo(_modeHoldFrames), reason: 'hold ERG');
    expect(cutaway.frames.length - at('SIM'), greaterThanOrEqualTo(_modeHoldFrames), reason: 'hold SIM');
    // The chain on the gear card runs.
    expect(cutaway.frames.sublist(0, _cutawayOpeningFrames).map(sha256.convert).toSet().length, greaterThan(30),
        reason: 'the chain should be running on film');
    // A Ride press lands on the gear card.
    for (final t in cutaway.taps.where((t) => t.kind == 'hardware')) {
      expect(_reactingFrames(cutaway, t), greaterThan(3), reason: '"${t.label}" should visibly react on film');
    }

    report(rideTake.scene, onboarding, watch.elapsed);
    report(_cutawayScene, cutaway, watch.elapsed);
  });

  for (final take in takes) {
    testWidgets('captures the ${take.slug} take as a 30 fps frame sequence', (tester) async {
      final watch = Stopwatch()..start();
      final (:onboarding, cutaway: _) = await _captureMyWhoosh(tester, stage, take);
      watch.stop();
      _writeScene(take.scene, onboarding, controller: take);
      expectWizardTake(take, onboarding);
      report(take.scene, onboarding, watch.elapsed);
    });
  }

  void expectIdentical(String name, _Capture ca, _Capture cb) {
    final ha = _frameHashes(ca);
    final hb = _frameHashes(cb);
    // ignore: avoid_print
    print('determinism $name: run A ${ha.length} frames, sequence sha256 ${_sequenceHash(ca)}\n'
        'determinism $name: run B ${hb.length} frames, sequence sha256 ${_sequenceHash(cb)}');
    expect(hb.length, ha.length, reason: '$name: both runs must produce the same number of frames');
    final differing = [for (var i = 0; i < ha.length; i++) if (ha[i] != hb[i]) i];
    expect(differing, isEmpty, reason: '$name: frames that differ between the two runs');
    expect(cb.tapsJson, ca.tapsJson);
    expect(cb.chaptersJson, ca.chaptersJson);
  }

  testWidgets('two captures are byte-identical, frame for frame', (tester) async {
    final a = await _captureMyWhoosh(tester, stage, rideTake, withCutaway: ride);
    final b = await _captureMyWhoosh(tester, stage, rideTake, withCutaway: ride);
    expectIdentical(rideTake.scene, a.onboarding, b.onboarding);
    expectIdentical(_cutawayScene, a.cutaway!, b.cutaway!);
  });

  for (final take in takes) {
    testWidgets('two ${take.slug} captures are byte-identical, frame for frame', (tester) async {
      final a = await _captureMyWhoosh(tester, stage, take);
      final b = await _captureMyWhoosh(tester, stage, take);
      expectIdentical(take.scene, a.onboarding, b.onboarding);
    });
  }
}
