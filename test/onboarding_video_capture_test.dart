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
// * `mywhoosh-trainer` — the same take with no controller: the controller
//   step is got through with "Can't find my controller" → "Set up later", and
//   its chapter is marked `"cut": true` for the edit.
// * `vs-settings` — a cutaway on the bridged trainer's page: gearing presets,
//   gear count and a second chainring; a gear change from a Ride press; the
//   SIM / ERG switch. Its `chapters.json` names those three beats.
//
// Output (per scene):
//   build/video_frames/<scene>/000000.png, 000001.png, …  760×1648 px
//   build/video_frames/<scene>/taps.json  [{frame, x, y, label, kind}] in PNG
//     pixels. kind "tap" is a finger on the screen; "swipe" a finger dragged
//     from x/y (at frame) to endX/endY (at endFrame); "hardware" a button
//     pressed on the controller — x/y is that button on the contour, or, where
//     no contour is on screen, the spot that reacts (anchor says which);
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
//   is switched back on through [debugOnboardingAnimatesInScreenshotMode].
//   App, controller and trainer names on this path are not anonymised by
//   screenshotMode, so the video shows the real "MyWhoosh", "Zwift Ride" and
//   "KICKR CORE".
@Tags(['video'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart' show ftmsEmulator;
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/bluetooth/emulation/emulated_peripherals.dart'
    show buildFtmsTrainer, zwiftRideNotification;
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, screenshotLocale, screenshotMode;
import 'package:bike_control/pages/onboarding/onboarding_app_guides.dart' show OnboardingPairAsTrainerCard;
import 'package:bike_control/pages/onboarding/onboarding_page.dart';
import 'package:bike_control/pages/onboarding/steps/step_app.dart' show OnboardingAppTile;
import 'package:bike_control/pages/onboarding/widgets/onboarding_reveal.dart';
import 'package:bike_control/pages/onboarding/widgets/vs_stage.dart' show debugVirtualShiftingStageOpeningScene;
import 'package:bike_control/pages/proxy_device_details.dart';
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
import 'package:golden_screenshot/golden_screenshot.dart'; // tester.loadAssets()
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import 'helpers/offline_machine.dart';
import 'widget_snapshot.dart';
import 'widget_to_png.dart';

/// The mobile shell (the desktop rail starts at 800).
const _logicalSize = Size(380, 824);

/// 2× gives 760×1648 px. Placed as a phone in a 1080p frame the screen is
/// roughly 900–1000 px tall, so every frame is downsampled ~1.7× — crisp text
/// and edges — with headroom for a compositor zoom of up to ~1.7× before any
/// pixel is upscaled. 3× would add 2.25× the pixels (and encode time) for
/// detail a 1080p frame cannot show.
const _pixelRatio = 2.0;

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

const _onboardingScene = 'mywhoosh-controller';
const _trainerOnlyScene = 'mywhoosh-trainer';
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

  /// `tap`, `swipe` or `hardware` — see the header.
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

  /// Chapter names, the frame each one starts on, and whether the edit drops
  /// it.
  final chapterStarts = <(String, int, bool)>[];

  List<({String name, int start, int end, bool cut})> get chapters => [
        for (var i = 0; i < chapterStarts.length; i++)
          (
            name: chapterStarts[i].$1,
            start: chapterStarts[i].$2,
            end: i + 1 < chapterStarts.length ? chapterStarts[i + 1].$2 : frames.length - 1,
            cut: chapterStarts[i].$3,
          ),
      ];

  String get tapsJson => const JsonEncoder.withIndent('  ').convert([for (final t in taps) t.toJson()]);

  String get chaptersJson => const JsonEncoder.withIndent('  ')
      .convert([
        for (final c in chapters) {'name': c.name, 'start': c.start, 'end': c.end, if (c.cut) 'cut': true},
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
    capture.chapterStarts.add((chapter, 0, false));
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
  void chapter(String name, {bool cut = false}) {
    expect(_settled, isTrue, reason: 'chapter "$name" must start on a settled frame (frame ${_frames.length - 1})');
    capture.chapterStarts.add((name, _frames.length - 1, cut));
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

  /// Presses [mask] on the Ride and releases it [_pressHoldFrames] later.
  ///
  /// Both edges go in as the raw keypad notification the Ride sends over BLE,
  /// through the device's own decoder (`processCharacteristic` →
  /// `handleButtonsClicked`) — the same path a real press takes. [anchor]
  /// locates the x/y recorded: [button] on the contour when one is on screen.
  Future<void> hardwarePress(
    ZwiftRide ride,
    RideButtonMask mask,
    ControllerButton button,
    String label, {
    Finder? reactsAt,
  }) async {
    final onContour = find.byKey(ValueKey(button.name));
    final anchor = reactsAt ?? onContour;
    expect(anchor, findsOneWidget, reason: '"$label" needs a spot on screen');
    final pos = tester.getCenter(anchor);
    await ride.processCharacteristic(
      ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
      Uint8List.fromList(zwiftRideNotification(pressed: [mask])),
    );
    _record(pos, label, 'hardware').anchor = reactsAt == null ? 'contour-button' : 'reaction';
    await frames(_pressHoldFrames);
    await ride.processCharacteristic(
      ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
      Uint8List.fromList(zwiftRideNotification()),
    );
    capture.transitionFrames[label] = await untilStill();
  }
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
  _Stage(this.machine, this.ride);

  final OfflineMachine machine;
  final ZwiftRide ride;

  /// A fresh trainer per capture: a trainer the previous capture bridged is
  /// not the same object as one found for the first time.
  late ProxyDevice trainer;
}

/// One take of the MyWhoosh wizard. With [withController] a connected Zwift
/// Ride is staged and pressed on the controller step, and the take goes on
/// into the gearing cutaway on the bridged trainer's page. Without it the
/// controller step is got through the way a rider without one would, and
/// there is no cutaway.
Future<({_Capture onboarding, _Capture? cutaway})> _captureMyWhoosh(
  WidgetTester tester,
  _Stage stage, {
  required bool withController,
}) async {
  await _restoreAppState();
  final ride = stage.ride;
  core.connection.devices.remove(ride);
  if (withController) core.connection.addDevices([ride]);

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
      SvgAssetLoader(ride.controllerLayout.svgAsset!).loadBytes(assetContext),
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
  rec.chapter('controller', cut: !withController);
  // Without a controller the step opens on its scan, which never comes to
  // rest: 2 s of it, then on.
  await rec.tap(find.byType(PrimaryButton).last, 'Continue to controller', thenFrames: withController ? null : 60);

  final l10n = AppLocalizations.current;
  if (!withController) {
    // Step 3 — no controller: the scan finds nothing. The rider says so and
    // sets it up later. The edit drops this chapter.
    await rec.tap(find.text(l10n.onboardingCantFindController), 'Can\'t find my controller');
    rec.chapter('trainer');
    await rec.tap(find.text(l10n.onboardingSetUpLater), 'Set up later', thenFrames: _vsStageFrames);
  } else {
  // Step 3 — controller: the connected Ride is listed with its contour.
  expect(find.text(ride.displayName(tester.element(find.byType(OnboardingPage)))), findsOneWidget,
      reason: 'should be on the controller step with the Ride listed');

  // Press buttons on the Ride — a shift, a steer, a shift the other way.
  // In the app, Connection forwards each connected device's action stream to
  // core.connection.actionStream (which the wizard listens to) when it
  // connects the device; the staged Ride is never BLE-connected, so that one
  // forwarding line is done here.
  final forward = ride.actionStream.listen(core.connection.signalNotification);
  await rec.hardwarePress(ride, RideButtonMask.SHFT_UP_R_BTN, ZwiftButtons.shiftUpRight, 'Ride button: Shift up');
  await rec.hardwarePress(ride, RideButtonMask.LEFT_BTN, ZwiftButtons.navigationLeft, 'Ride button: Steer left');
  await rec.hardwarePress(ride, RideButtonMask.SHFT_DN_L_BTN, ZwiftButtons.shiftDownLeft, 'Ride button: Shift down');
  // Not awaited: a broadcast subscription's cancel() returns a future that
  // completes on the real event loop, and awaiting it here would take the test
  // body off the fake clock for good — every pump after it would never return.
  unawaited(forward.cancel());

  // Step 4 — trainer: the Virtual Shifting stage plays, then the KICKR CORE
  // listed in the scan card is tapped and bridged over the real picker path.
  rec.chapter('trainer');
  await rec.tap(find.byType(PrimaryButton).last, 'Continue to trainer', thenFrames: _vsStageFrames);
  }
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
  if (!withController) {
    // Tear down and stop: no cutaway in the trainer-only take.
    await _unbridge(tester, stage, peripheral.deviceId);
    return (onboarding: rec.capture, cutaway: null);
  }

  // ── The cutaway: the bridged trainer's own page. ─────────────────────────
  // Its own take, on the same bridged trainer. Shifts go through the real
  // action pipeline from here on, so a Ride press changes the trainer's gear.
  core.actionHandler = _FilmActions()..init(core.settings.getTrainerApp());
  final cut = _Recorder(tester, boundary);
  await tester.pumpWidget(app(const SizedBox()));
  await tester.pump();
  await tester.pumpWidget(app(ProxyDeviceDetailsPage(device: trainer)));
  await cut.first('gearing');
  await cut.untilStill();

  // (a) Your gearing, your way.
  await cut.tap(find.text(l10n.gearSettings), 'Gear settings');
  await cut.tap(find.byWidgetPredicate((w) => w is Switch).first, 'Front derailleur');
  final gearCount = find.widgetWithText(SettingTile, l10n.gearCount);
  await cut.tap(find.descendant(of: gearCount, matching: find.byIcon(LucideIcons.plus)), 'Gear count +');
  // The editor flags a count that differs from the app's; take its offer.
  await cut.tap(find.text(l10n.useGearCount(MyWhoosh().virtualGearAmount)), 'Use MyWhoosh gear count');
  await cut.swipe(const Offset(190, 640), const Offset(190, 300), 'Scroll to presets');
  await cut.tap(find.text(l10n.presetCompact), 'Compact preset');
  await cut.tap(find.byIcon(LucideIcons.arrowLeft), 'Back');

  // (b) Direct gear changes: two Ride shifts land on the gear card.
  cut.chapter('direct-gear-changes');
  final gearCard = find.byType(GearHeroCard);
  await cut.hardwarePress(ride, RideButtonMask.SHFT_UP_R_BTN, ZwiftButtons.shiftUpRight, 'Ride button: Shift up',
      reactsAt: gearCard);
  await cut.hardwarePress(ride, RideButtonMask.SHFT_UP_R_BTN, ZwiftButtons.shiftUpRight, 'Ride button: Shift up again',
      reactsAt: gearCard);

  // (c) SIM & ERG: the card's own mode switch.
  cut.chapter('sim-erg');
  await cut.tap(find.descendant(of: gearCard, matching: find.byWidgetPredicate((w) => w is Switch)), 'ERG');
  await cut.tap(find.descendant(of: gearCard, matching: find.byWidgetPredicate((w) => w is Switch)), 'SIM');

  await _unbridge(tester, stage, peripheral.deviceId);
  return (onboarding: rec.capture, cutaway: cut.capture);
}

/// Unmounts (cancelling the wizard's timers) and unbridges, so the next take
/// finds the trainer — and MyWhoosh — the way this one did. None of this is on
/// film.
Future<void> _unbridge(WidgetTester tester, _Stage stage, String peripheralId) async {
  final trainer = stage.trainer;
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  // Parts of a disconnect complete on the real event loop (stream
  // cancellations), so it is driven by letting real time and fake time pass
  // in turn until it has finished.
  final definition = trainer.fitnessBike;
  var unbridged = false;
  unawaited(core.connection
      .disconnect(trainer, forget: true, persistForget: false)
      .whenComplete(() => unbridged = true));
  for (var i = 0; i < 100 && !unbridged; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(unbridged, isTrue, reason: 'the trainer should have disconnected');
  // Disconnecting detaches the trainer's definition from the emulator but does
  // not dispose it, which leaves its 1 s notify timer running; stop it here.
  definition?.dispose();
  ftmsEmulator.isConnected.value = false;
  core.obpMdnsEmulator.stopServer();
  await tester.pump(const Duration(seconds: 1));
  stage.machine.ble.removePeripheral(peripheralId);
}

List<String> _frameHashes(_Capture c) => [for (final f in c.frames) sha256.convert(f).toString()];

String _sequenceHash(_Capture c) => sha256.convert(utf8.encode(_frameHashes(c).join())).toString();

(int, int) _pngSize(Uint8List png) {
  // IHDR: width and height are big-endian u32 at bytes 16 and 20.
  final d = ByteData.sublistView(png);
  return (d.getUint32(16), d.getUint32(20));
}

void _writeScene(String scene, _Capture capture) {
  final dir = Directory('build/video_frames/$scene');
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);
  for (var i = 0; i < capture.frames.length; i++) {
    File('${dir.path}/${i.toString().padLeft(6, '0')}.png').writeAsBytesSync(capture.frames[i]);
  }
  File('${dir.path}/taps.json').writeAsStringSync(capture.tapsJson);
  File('${dir.path}/chapters.json').writeAsStringSync(capture.chaptersJson);
}

void _expectWellFormed(_Capture capture, {required Set<String> unsettledTaps}) {
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
    expect(_bytesEqual(capture.frames[b], capture.frames[b - 1]), isTrue,
        reason: 'boundary into "${chapters[i].name}" (frame $b) must be settled');
  }
  expect(chapters.last.end, capture.frames.length - 1);
  expect(_bytesEqual(capture.frames.last, capture.frames[capture.frames.length - 2]), isTrue,
      reason: 'the take ends on a settled frame');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A connected Zwift Ride, staged the way screenshot_test.dart stages its
  // controllers: the real device class over a hand-made scan result. Added to
  // the device list only for the controller take.
  final ride = ZwiftRide(BleDevice(name: 'Zwift Ride', deviceId: '00:11:22:33:44:55'))
    ..firmwareVersion = '1.2.0'
    ..isConnected = true
    ..rssi = -51
    ..batteryLevel = 81;
  late _Stage stage;

  // In setUpAll rather than main(): under the fake-clock binding, Supabase's
  // initialisation inside Settings.init() needs to run in a test zone.
  setUpAll(() async {
    await ensureSnapshotAppState();
    _pristinePrefs = {for (final k in core.settings.prefs.getKeys()) k: core.settings.prefs.get(k)!};
    stage = _Stage(OfflineMachine.install(httpFixtures: _guideFixtures), ride);
  });

  setUp(() {
    // Keep the plumbing pinned (see the header) but let the wizard move.
    screenshotMode = true;
    debugOnboardingAnimatesInScreenshotMode = true;
    debugVirtualShiftingStageOpeningScene = _vsStageOpeningScene;
    addTearDown(() {
      debugOnboardingAnimatesInScreenshotMode = false;
      debugVirtualShiftingStageOpeningScene = null;
    });
  });

  const linkAndDone = [
    ('tap', _trainerName),
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

  testWidgets('captures the MyWhoosh takes and the gearing cutaway as 30 fps frame sequences', (tester) async {
    final watch = Stopwatch()..start();
    final withController = await _captureMyWhoosh(tester, stage, withController: true);
    final controllerMs = watch.elapsedMilliseconds;
    final trainerOnly = (await _captureMyWhoosh(tester, stage, withController: false)).onboarding;
    watch.stop();
    final onboarding = withController.onboarding;
    final cutaway = withController.cutaway!;
    _writeScene(_onboardingScene, onboarding);
    _writeScene(_trainerOnlyScene, trainerOnly);
    _writeScene(_cutawayScene, cutaway);

    expect(onboarding.taps.map((t) => (t.kind, t.label)), [
      ('tap', 'MyWhoosh tile'),
      ('tap', 'Continue with MyWhoosh'),
      ('tap', 'This Device'),
      ('tap', 'Continue to controller'),
      ('hardware', 'Ride button: Shift up'),
      ('hardware', 'Ride button: Steer left'),
      ('hardware', 'Ride button: Shift down'),
      ('tap', 'Continue to trainer'),
      ...linkAndDone,
    ]);
    expect(onboarding.chapters.map((c) => (c.name, c.cut)), [
      ('app', false),
      ('where', false),
      ('controller', false),
      ('trainer', false),
      ('link-app', false),
      ('done', false),
    ]);
    _expectWellFormed(onboarding, unsettledTaps: {_trainerName});

    expect(trainerOnly.taps.map((t) => (t.kind, t.label)), [
      ('tap', 'MyWhoosh tile'),
      ('tap', 'Continue with MyWhoosh'),
      ('tap', 'This Device'),
      ('tap', 'Continue to controller'),
      ('tap', "Can't find my controller"),
      ('tap', 'Set up later'),
      ...linkAndDone,
    ]);
    expect(trainerOnly.chapters.map((c) => (c.name, c.cut)), [
      ('app', false),
      ('where', false),
      ('controller', true),
      ('trainer', false),
      ('link-app', false),
      ('done', false),
    ]);
    // The scan animation never rests, so the way out of it can't wait for it.
    _expectWellFormed(trainerOnly, unsettledTaps: {_trainerName, "Can't find my controller"});

    expect(cutaway.taps.map((t) => (t.kind, t.label)), [
      ('tap', 'Gear settings'),
      ('tap', 'Front derailleur'),
      ('tap', 'Gear count +'),
      ('tap', 'Use MyWhoosh gear count'),
      ('swipe', 'Scroll to presets'),
      ('tap', 'Compact preset'),
      ('tap', 'Back'),
      ('hardware', 'Ride button: Shift up'),
      ('hardware', 'Ride button: Shift up again'),
      ('tap', 'ERG'),
      ('tap', 'SIM'),
    ]);
    expect(cutaway.chapters.map((c) => c.name), ['gearing', 'direct-gear-changes', 'sim-erg']);
    _expectWellFormed(cutaway, unsettledTaps: const {});

    // A controller press visibly reacts: on the contour in the wizard, on the
    // gear card in the cutaway. So does MyWhoosh connecting.
    for (final capture in [onboarding, trainerOnly, cutaway]) {
      for (final t in capture.taps.where((t) => t.kind == 'hardware' || t.label == 'MyWhoosh connects')) {
        final before = capture.frames[t.frame - 1];
        final reacting = [for (var i = t.frame; i < t.frame + _pressHoldFrames + _hold; i++) capture.frames[i]]
            .where((f) => !_bytesEqual(f, before))
            .length;
        expect(reacting, greaterThan(3), reason: '"${t.label}" should visibly react on film');
      }
    }

    expectStepChangesAnimate(
        onboarding, ['app step reveal', 'Continue with MyWhoosh', 'Continue to controller', 'Continue to connection']);
    expectStepChangesAnimate(trainerOnly, ['app step reveal', 'Continue with MyWhoosh', 'Continue to connection']);
    expect(trainerOnly.transitionFrames['Continue to controller'], 60);
    expectStagePlays(onboarding, 'Continue to trainer');
    expectStagePlays(trainerOnly, 'Set up later');

    // ignore: avoid_print
    print('video capture: controller take ${onboarding.frames.length} frames '
        '(${(onboarding.frames.length / _fps).toStringAsFixed(2)} s) + cutaway ${cutaway.frames.length} frames '
        '(${(cutaway.frames.length / _fps).toStringAsFixed(2)} s) in $controllerMs ms; '
        'trainer-only take ${trainerOnly.frames.length} frames '
        '(${(trainerOnly.frames.length / _fps).toStringAsFixed(2)} s) in ${watch.elapsedMilliseconds - controllerMs} ms\n'
        'controller chapters: ${onboarding.chaptersJson}\n'
        'trainer-only chapters: ${trainerOnly.chaptersJson}\n'
        'cutaway chapters: ${cutaway.chaptersJson}\n'
        'controller taps: ${onboarding.tapsJson}\n'
        'trainer-only taps: ${trainerOnly.tapsJson}\n'
        'cutaway taps: ${cutaway.tapsJson}');
  });

  testWidgets('two captures are byte-identical, frame for frame', (tester) async {
    final a = await _captureMyWhoosh(tester, stage, withController: true);
    final aTrainer = (await _captureMyWhoosh(tester, stage, withController: false)).onboarding;
    final b = await _captureMyWhoosh(tester, stage, withController: true);
    final bTrainer = (await _captureMyWhoosh(tester, stage, withController: false)).onboarding;

    for (final (name, ca, cb) in [
      (_onboardingScene, a.onboarding, b.onboarding),
      (_trainerOnlyScene, aTrainer, bTrainer),
      (_cutawayScene, a.cutaway!, b.cutaway!),
    ]) {
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
  });
}
