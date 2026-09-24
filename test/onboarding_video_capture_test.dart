// Captures the onboarding wizard as a numbered 30 fps PNG sequence — the
// "screen layer" a video compositor later places in a 16:9 frame, with a
// synthetic pointer drawn from taps.json.
//
// Slice: MyWhoosh path, steps app → where → controller, driven through the
// real stateful OnboardingPage with a connected Zwift Ride staged.
//
// Output (per scene):
//   build/video_frames/<scene>/000000.png, 000001.png, …  760×1648 px
//   build/video_frames/<scene>/taps.json  [{frame, x, y, label}] in PNG pixels
//
// Tagged `video` and skipped by default (see dart_test.yaml). Run with:
//   flutter test --run-skipped --tags video test/onboarding_video_capture_test.dart
//
// Determinism
// -----------
// Every frame is a pure function of the script, which is what the second test
// proves byte for byte. Three things make that hold:
//
// * The fake-clock binding. The snapshot harness normally installs the
//   integration binding, under which `pump(duration)` waits wall-clock time
//   and frames are stamped by the real vsync — an animation's phase in a
//   captured frame would depend on how fast the machine rendered the previous
//   one. Here time only moves when the script pumps, exactly 1/30 s at a time.
// * Assets are decoded before the first recorded frame. Fonts, the app logos,
//   the header icon and the Ride contour SVG all load through real async I/O,
//   which the fake clock never waits for; left to load mid-recording they pop
//   in on whichever frame the machine got to them.
// * `screenshotMode` stays on. It pins everything this path would otherwise
//   read from the machine: the permission probe returns nothing (so the
//   controller step goes straight to its device list), no update check hits
//   the network, and no BLE scan or connection queue runs. The one thing it
//   also switches off — the onboarding reveal motion, which IS the step
//   transition the video needs — is switched back on through
//   [debugOnboardingRevealAnimatesInScreenshotMode]. App and controller names
//   on this path are not anonymised by screenshotMode, so the video shows the
//   real "MyWhoosh" and "Zwift Ride".
@Tags(['video'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, screenshotLocale, screenshotMode;
import 'package:bike_control/pages/onboarding/onboarding_page.dart';
import 'package:bike_control/pages/onboarding/steps/step_app.dart' show OnboardingAppTile;
import 'package:bike_control/pages/onboarding/widgets/onboarding_reveal.dart';
import 'package:bike_control/utils/actions/base_actions.dart' show StubActions;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart'; // tester.loadAssets()
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

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

const _scene = 'mywhoosh-controller';

class _Tap {
  _Tap(this.frame, this.x, this.y, this.label);
  final int frame;
  final double x;
  final double y;
  final String label;

  Map<String, Object> toJson() => {'frame': frame, 'x': x, 'y': y, 'label': label};
}

class _Capture {
  final frames = <Uint8List>[];
  final taps = <_Tap>[];

  /// Frames each tap's consequence took to come to rest, keyed by tap label.
  final transitionFrames = <String, int>{};

  String get tapsJson => const JsonEncoder.withIndent('  ').convert([for (final t in taps) t.toJson()]);
}

/// Drives the wizard frame by frame, capturing every frame it pumps.
class _Recorder {
  _Recorder(this.tester, this.boundary);

  final WidgetTester tester;
  final GlobalKey boundary;
  final capture = _Capture();

  /// Frame n is shown at n/30 s. Deriving each pump from the absolute frame
  /// time keeps the sequence exactly 30 fps with no rounding drift.
  static int _timeUs(int frame) => (frame * Duration.microsecondsPerSecond / _fps).round();

  List<Uint8List> get _frames => capture.frames;

  Future<void> _grab() async =>
      _frames.add(await encodeBoundaryToPng(tester, boundary, pixelRatio: _pixelRatio));

  /// Frame 0: what is on screen right now, no time advanced.
  Future<void> first() async {
    assert(_frames.isEmpty);
    await _grab();
  }

  /// Advances exactly one frame and captures it.
  Future<void> step() async {
    final n = _frames.length;
    await tester.pump(Duration(microseconds: _timeUs(n) - _timeUs(n - 1)));
    await _grab();
  }

  bool _lastTwoEqual() {
    if (_frames.length < 2) return false;
    final a = _frames[_frames.length - 1];
    final b = _frames[_frames.length - 2];
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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

  /// A finger press on [finder]'s centre: down, ~100 ms held (so the pressed
  /// state is on film), up — then capture until the result has settled.
  Future<void> tap(Finder finder, String label) async {
    expect(finder.hitTestable(), findsOneWidget, reason: 'tap target "$label" must be on screen and hittable');
    final pos = tester.getCenter(finder);
    final gesture = await tester.startGesture(pos);
    // The first frame that shows the finger down.
    capture.taps.add(_Tap(_frames.length, pos.dx * _pixelRatio, pos.dy * _pixelRatio, label));
    for (var i = 0; i < 3; i++) {
      await step();
    }
    await gesture.up();
    capture.transitionFrames[label] = await untilStill();
  }
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
  IAPManager.instance.isPurchased.value = true;
  // Straight into step 1: the slice starts at the app step, not the welcome
  // screen. Visually the shell is the same either way.
  await core.settings.setOnboardingState(Settings.onboardingStateCompleted);
  // No trainer app chosen yet — picking MyWhoosh is part of the film.
  core.actionHandler = StubActions();
  screenshotLocale = const Locale('en');
  await AppLocalizations.load(const Locale('en'));
}

Future<_Capture> _captureMyWhooshControllerSlice(WidgetTester tester, ZwiftRide ride) async {
  await _restoreAppState();

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

  // ── Warm-up (not recorded): decode every asset the slice shows. ──────────
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
    ]);
  });
  await tester.pumpWidget(app(const SizedBox()));
  await tester.pump();

  // ── Recording. Frame 0 is the app step's first frame. ─────────────────────
  final rec = _Recorder(tester, boundary);
  await tester.pumpWidget(app(const OnboardingPage()));
  await rec.first();
  rec.capture.transitionFrames['app step reveal'] = await rec.untilStill();

  // Step 1 — trainer app.
  await rec.tap(find.byWidgetPredicate((w) => w is OnboardingAppTile && w.app is MyWhoosh), 'MyWhoosh tile');
  await rec.tap(find.byType(PrimaryButton).last, 'Continue with MyWhoosh');

  // Step 2 — where. MyWhoosh runs on the PC/tablet, BikeControl on the phone.
  await rec.tap(find.byKey(const ValueKey('onboarding-where-otherDevice')), 'Another device');
  await rec.tap(find.byType(PrimaryButton).last, 'Continue');

  // Step 3 — controller: the connected Ride is listed with its contour.
  expect(find.text(ride.displayName(tester.element(find.byType(OnboardingPage)))), findsOneWidget,
      reason: 'should be on the controller step with the Ride listed');

  // Unmount: dispose() cancels the controller step's 15 s empty-scan timer,
  // which would otherwise still be pending when the test ends.
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  return rec.capture;
}

List<String> _frameHashes(_Capture c) => [for (final f in c.frames) sha256.convert(f).toString()];

String _sequenceHash(_Capture c) => sha256.convert(utf8.encode(_frameHashes(c).join())).toString();

(int, int) _pngSize(Uint8List png) {
  // IHDR: width and height are big-endian u32 at bytes 16 and 20.
  final d = ByteData.sublistView(png);
  return (d.getUint32(16), d.getUint32(20));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A connected Zwift Ride, staged the way screenshot_test.dart stages its
  // controllers: the real device class over a hand-made scan result.
  final ride = ZwiftRide(BleDevice(name: 'Zwift Ride', deviceId: '00:11:22:33:44:55'))
    ..firmwareVersion = '1.2.0'
    ..isConnected = true
    ..rssi = -51
    ..batteryLevel = 81;

  // In setUpAll rather than main(): under the fake-clock binding, Supabase's
  // initialisation inside Settings.init() needs to run in a test zone.
  setUpAll(() async {
    await ensureSnapshotAppState();
    _pristinePrefs = {for (final k in core.settings.prefs.getKeys()) k: core.settings.prefs.get(k)!};
    core.connection.addDevices([ride]);
  });

  setUp(() {
    // Keep the plumbing pinned (see the header) but let the wizard move.
    screenshotMode = true;
    debugOnboardingRevealAnimatesInScreenshotMode = true;
    addTearDown(() => debugOnboardingRevealAnimatesInScreenshotMode = false);
  });

  testWidgets('captures app → where → controller as a 30 fps frame sequence', (tester) async {
    final watch = Stopwatch()..start();
    final capture = await _captureMyWhooshControllerSlice(tester, ride);
    watch.stop();

    final dir = Directory('build/video_frames/$_scene');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    for (var i = 0; i < capture.frames.length; i++) {
      File('${dir.path}/${i.toString().padLeft(6, '0')}.png').writeAsBytesSync(capture.frames[i]);
    }
    File('${dir.path}/taps.json').writeAsStringSync(capture.tapsJson);

    final (width, height) = _pngSize(capture.frames.first);
    expect((width, height), ((_logicalSize.width * _pixelRatio).round(), (_logicalSize.height * _pixelRatio).round()));
    for (final f in capture.frames) {
      expect(_pngSize(f), (width, height), reason: 'every frame must share one size');
    }

    expect(capture.taps.map((t) => t.label), ['MyWhoosh tile', 'Continue with MyWhoosh', 'Another device', 'Continue']);
    for (final t in capture.taps) {
      expect(t.x, inInclusiveRange(0, width), reason: t.label);
      expect(t.y, inInclusiveRange(0, height), reason: t.label);
      expect(t.frame, inExclusiveRange(0, capture.frames.length), reason: t.label);
      // A settled hold precedes every tap: the frame before the finger lands
      // matches the ones before it.
      for (var i = t.frame - _hold; i < t.frame - 1; i++) {
        expect(capture.frames[i], capture.frames[t.frame - 1], reason: 'hold before "${t.label}" (frame $i)');
      }
    }

    // A step change is filmed as Flutter's own reveal, not a cut: the content
    // eases in over many distinct frames before the settled hold.
    for (final label in ['app step reveal', 'Continue with MyWhoosh', 'Continue']) {
      expect(capture.transitionFrames[label]! - _hold, greaterThan(20),
          reason: '"$label" should animate across frames, not cut');
    }

    // ignore: avoid_print
    print('video capture: ${capture.frames.length} frames '
        '(${(capture.frames.length / _fps).toStringAsFixed(2)} s at $_fps fps), ${width}x$height px, '
        'captured in ${watch.elapsed.inMilliseconds} ms wall clock → ${dir.path}\n'
        'transitions (frames incl. $_hold-frame hold): ${capture.transitionFrames}\n'
        'taps: ${capture.tapsJson}');
  });

  testWidgets('two captures of the slice are byte-identical, frame for frame', (tester) async {
    final a = await _captureMyWhooshControllerSlice(tester, ride);
    final b = await _captureMyWhooshControllerSlice(tester, ride);

    final ha = _frameHashes(a);
    final hb = _frameHashes(b);
    // ignore: avoid_print
    print('determinism: run A ${ha.length} frames, sequence sha256 ${_sequenceHash(a)}\n'
        'determinism: run B ${hb.length} frames, sequence sha256 ${_sequenceHash(b)}\n'
        'first/last frame A ${ha.first} / ${ha.last}\n'
        'first/last frame B ${hb.first} / ${hb.last}');

    expect(hb.length, ha.length, reason: 'both runs must produce the same number of frames');
    final differing = [for (var i = 0; i < ha.length; i++) if (ha[i] != hb[i]) i];
    expect(differing, isEmpty, reason: 'frames that differ between the two runs');
    expect(b.tapsJson, a.tapsJson);
  });
}
