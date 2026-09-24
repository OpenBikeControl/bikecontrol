// The frame-by-frame capture harness shared by the video captures
// (onboarding_video_capture_test.dart, feature_video_capture_test.dart): a
// recorder that drives the real app on the fake clock and grabs every frame,
// what it writes next to the frames (taps.json, chapters.json, scene.json),
// and the checks every take has to pass.
//
// See onboarding_video_capture_test.dart's header for the output format and
// for what keeps the frames deterministic.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/shimano/shimano_di2.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/bluetooth/emulation/emulated_peripherals.dart' show zwiftRideNotification;
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/utils/actions/base_actions.dart' show BaseActions;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart'; // tester.loadAssets()
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../widget_snapshot.dart';
import '../widget_to_png.dart';

/// The mobile shell (the desktop rail starts at 800).
const videoLogicalSize = Size(380, 824);

/// 3× gives 1140×2472 px. Placed as a phone in a 1080p frame the screen is
/// roughly 900–1000 px tall, so a full-phone shot is downsampled ~2.5×, and
/// the compositor's 2.2× punch-in still lands on native pixels (at 2× it
/// upscaled ~1.17× past them, softening the text).
const videoPixelRatio = 3.0;

const videoFps = 30;

/// Settled frames kept before and after every tap (~0.4 s).
const videoHold = 12;

/// How long a controller button is held down (~0.3 s) — long enough to read.
const videoPressHoldFrames = 9;

class VideoTap {
  VideoTap(this.frame, this.x, this.y, this.label, {required this.kind, required this.settledBefore});
  final int frame;
  final double x;
  final double y;
  final String label;

  /// `tap`, `swipe`, `hardware` or `event` — see the onboarding header.
  final String kind;

  /// Whether the [videoHold] frames before it were unchanged. Only a tap into
  /// a screen that never rests lacks it.
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

bool bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class VideoCapture {
  final frames = <Uint8List>[];
  final taps = <VideoTap>[];

  /// Frames each tap's consequence took to come to rest, keyed by tap label.
  final transitionFrames = <String, int>{};

  /// Chapter names and the frame each one starts on.
  final chapterStarts = <(String, int)>[];

  /// Chapters whose first frame is a cut in time (the clip skips ahead).
  final cutChapters = <String>{};

  /// Screens proven to be inside the captured boundary, and the frame each
  /// was first seen on — see [VideoRecorder.sighting].
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

  String get chaptersJson => const JsonEncoder.withIndent('  ').convert([
        for (final c in chapters)
          {'name': c.name, 'start': c.start, 'end': c.end, if (cutChapters.contains(c.name)) 'cut': true},
      ]);
}

/// Drives the app frame by frame, capturing every frame it pumps.
class VideoRecorder {
  VideoRecorder(this.tester, this.boundary);

  final WidgetTester tester;
  final GlobalKey boundary;
  final capture = VideoCapture();

  /// Frame n is shown at n/30 s. Deriving each pump from the absolute frame
  /// time keeps the sequence exactly 30 fps with no rounding drift.
  static int _timeUs(int frame) => (frame * Duration.microsecondsPerSecond / videoFps).round();

  List<Uint8List> get _frames => capture.frames;

  Future<void> _grab() async =>
      _frames.add(await encodeBoundaryToPng(tester, boundary, pixelRatio: videoPixelRatio));

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

  bool _lastTwoEqual() => _frames.length >= 2 && bytesEqual(_frames[_frames.length - 1], _frames[_frames.length - 2]);

  bool get settled {
    if (_frames.length <= videoHold) return false;
    final last = _frames.last;
    for (var i = _frames.length - videoHold; i < _frames.length - 1; i++) {
      if (!bytesEqual(_frames[i], last)) return false;
    }
    return true;
  }

  /// Starts the next chapter on the current (settled) frame. The previous
  /// chapter ends on the same frame, so the two share an invisible cut.
  /// [settled] false for a chapter that starts where something moves for good
  /// (the running chain in the cutaway) — there is no settled frame to take.
  void chapter(String name, {bool settled = true}) {
    if (settled) {
      expect(this.settled, isTrue, reason: 'chapter "$name" must start on a settled frame (frame ${_frames.length - 1})');
    }
    capture.chapterStarts.add((name, _frames.length - 1));
  }

  /// Skips [skip] of app time without filming it, then starts chapter [name]
  /// on the first frame after the jump. chapters.json marks it `cut: true`: a
  /// time cut the compositor shows as one. The frame clock carries on
  /// unbroken, so the film stays exactly 30 fps on either side.
  Future<void> cut(String name, Duration skip) async {
    await tester.pump(skip);
    await step();
    capture.chapterStarts.add((name, _frames.length - 1));
    capture.cutChapters.add(name);
  }

  /// Keeps capturing until [videoHold] consecutive frames are unchanged — the
  /// screen has visually finished moving and the compositor has a settled
  /// hold to work with. Returns how many frames that took.
  Future<int> untilStill({int maxFrames = 150}) async {
    final start = _frames.length;
    var still = 0;
    while (still < videoHold) {
      if (_frames.length - start >= maxFrames) {
        throw StateError('screen never settled within $maxFrames frames (from frame $start)');
      }
      await step();
      still = _lastTwoEqual() ? still + 1 : 0;
    }
    return _frames.length - start;
  }

  VideoTap _record(Offset pos, String label, String kind) {
    final tap = VideoTap(_frames.length, pos.dx * videoPixelRatio, pos.dy * videoPixelRatio, label,
        kind: kind, settledBefore: settled);
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
  /// and left to settle (the scroll view's own ballistics included), or
  /// captured for exactly [thenFrames] when what follows never rests.
  Future<void> swipe(Offset from, Offset to, String label, {int overFrames = 15, int? thenFrames}) async {
    final gesture = await tester.startGesture(from);
    final tap = _record(from, label, 'swipe');
    for (var i = 1; i <= overFrames; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / overFrames)!);
      await step();
    }
    tap
      ..endFrame = _frames.length - 1
      ..endX = to.dx * videoPixelRatio
      ..endY = to.dy * videoPixelRatio;
    await gesture.up();
    if (thenFrames != null) {
      await frames(thenFrames);
      capture.transitionFrames[label] = thenFrames;
    } else {
      capture.transitionFrames[label] = await untilStill();
    }
  }

  /// Types [text] into the focused field, one character a few frames apart,
  /// as a rider would. Recorded as one `event` at [at] (the keyboard is not on
  /// film), then left to settle.
  Future<void> type(String label, Finder at, String text, {int framesPerChar = 3}) async {
    expect(at, findsOneWidget, reason: '"$label" needs a spot on screen');
    final pos = tester.getCenter(at);
    _record(pos, label, 'event');
    for (var i = 1; i <= text.length; i++) {
      tester.testTextInput.updateEditingValue(TextEditingValue(
        text: text.substring(0, i),
        selection: TextSelection.collapsed(offset: i),
      ));
      await frames(framesPerChar);
    }
    capture.transitionFrames[label] = await untilStill();
  }

  /// Something the app hears from outside, not a touch — [happen] makes it so
  /// through the app's own entry point. Recorded as kind `event` at [at], on
  /// the first frame it can show, then left to settle, or captured for
  /// exactly [thenFrames] when what follows never rests.
  Future<void> event(String label, Finder at, FutureOr<void> Function() happen, {int? thenFrames}) async {
    expect(at, findsOneWidget, reason: '"$label" needs a spot on screen');
    final pos = tester.getCenter(at);
    final happening = happen();
    if (happening is Future<void>) await happening;
    _record(pos, label, 'event');
    if (thenFrames != null) {
      await frames(thenFrames);
      capture.transitionFrames[label] = thenFrames;
    } else {
      capture.transitionFrames[label] = await untilStill();
    }
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
    int holdFrames = videoPressHoldFrames,
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
  /// Play on firmware 2, a Click V2 puck) and releases it [holdFrames] later.
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
    int holdFrames = videoPressHoldFrames,
    int? thenFrames,
  }) =>
      hardware(
        label,
        at: reactsAt ?? find.byKey(ValueKey(button.name)),
        anchor: reactsAt == null ? 'contour-button' : 'reaction',
        press: () => ridePress(ride, [mask]),
        release: () => ridePress(ride, const []),
        holdFrames: holdFrames,
        thenFrames: thenFrames,
      );
}

/// The raw keypad notification a Ride-protocol controller sends with [pressed]
/// held down (none: everything released), through the device's own decoder.
Future<void> ridePress(ZwiftRide ride, List<RideButtonMask> pressed) => ride.processCharacteristic(
      ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
      Uint8List.fromList(zwiftRideNotification(pressed: pressed)),
    );

/// The real action pipeline — keymap, pro guard, trainer routing — without any
/// platform key or touch output: a Ride shift lands on the bridged trainer.
class FilmActions extends BaseActions {
  FilmActions() : super(supportedModes: const []);

  @override
  void cleanup() {}
}

/// Prefs as they stood before any capture ran, so each capture starts from the
/// same stored state. `Settings.reset()` would also re-run `Settings.init()` —
/// Supabase, IAP and window-manager steps whose timeouts would outlive the
/// test.
late final Map<String, Object> _pristinePrefs;

/// Snapshots the stored prefs. Call once, after the app state is bootstrapped.
void rememberPristinePrefs() {
  _pristinePrefs = {for (final k in core.settings.prefs.getKeys()) k: core.settings.prefs.get(k)!};
}

/// Puts the stored prefs back to the [rememberPristinePrefs] snapshot.
Future<void> restorePristinePrefs() async {
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
}

/// Lets real time and fake time pass in turn until [done] completes: parts of
/// a disconnect complete on the real event loop (stream cancellations), which
/// the fake clock never waits for. Never on film.
Future<void> driveUntil(WidgetTester tester, Future<void> done, String what) async {
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
T stageConnected<T extends BaseDevice>(T device) {
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

/// Forwards [device]'s presses to the app the way Connection does for a
/// device it connected. A staged controller is never BLE-connected, so that
/// one forwarding line is done here. Not awaited on cancel: a broadcast
/// subscription's cancel() completes on the real event loop, and awaiting it
/// would take the test body off the fake clock for good.
StreamSubscription<BaseNotification> forwardPresses(BaseDevice device) =>
    device.actionStream.listen(core.connection.signalNotification);

/// Removes a staged controller from the device list.
Future<void> unstageStaged(WidgetTester tester, BaseDevice device) async {
  device.isConnected = false;
  await driveUntil(tester, core.connection.disconnect(device, forget: true, persistForget: false),
      '${device.runtimeType} should have been removed');
}

/// Sizes the test view to the mobile shell at [videoPixelRatio].
void useVideoView(WidgetTester tester, {Size logicalSize = videoLogicalSize}) {
  tester.view.physicalSize = logicalSize * videoPixelRatio;
  tester.view.devicePixelRatio = videoPixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// The app shell the film is taken in: the real theme and delegates, with the
/// captured boundary around the whole app so overlays (sheets, popovers,
/// dialogs) hosted by it are on film.
Widget videoApp(GlobalKey boundary, Widget home, {GlobalKey<NavigatorState>? navigatorKey}) => RepaintBoundary(
      key: boundary,
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
        theme: snapshotTheme(Brightness.light),
        materialTheme: m.ThemeData(),
        home: home,
      ),
    );

/// Loads every bundled font family, not just the ones the first screen
/// happens to use: later screens draw Material and other icon glyphs, which
/// would otherwise be tofu. Needs a widget tree already pumped.
Future<void> loadAllVideoFonts(WidgetTester tester) async {
  // (loadString, not loadStructuredData: that caches the parsed result under
  // the same key loadAssets later reads the manifest from.)
  final manifest = await tester.runAsync(() => rootBundle.loadString('FontManifest.json', cache: false));
  final bundledFonts = [for (final f in jsonDecode(manifest!) as List) (f as Map)['family'] as String];
  await tester.loadAssets(alsoLoadTheseFonts: bundledFonts, searchWidgetTreeForImages: false);
}

/// An FTMS Indoor Bike Data packet: instantaneous speed (always present),
/// cadence (0.5 rpm units) and power, as a trainer notifies it.
List<int> indoorBikeData({required int cadenceRpm, required int powerW}) {
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

List<String> frameHashes(VideoCapture c) => [for (final f in c.frames) sha256.convert(f).toString()];

String sequenceHash(VideoCapture c) => sha256.convert(utf8.encode(frameHashes(c).join())).toString();

(int, int) pngSize(Uint8List png) {
  // IHDR: width and height are big-endian u32 at bytes 16 and 20.
  final d = ByteData.sublistView(png);
  return (d.getUint32(16), d.getUint32(20));
}

/// Writes the frames, taps.json, chapters.json and scene.json of [capture] to
/// build/video_frames/[scene]. [extra] is appended to scene.json.
void writeScene(
  String scene,
  VideoCapture capture, {
  Map<String, Object> extra = const {},
  Size logicalSize = videoLogicalSize,
}) {
  final dir = Directory('build/video_frames/$scene');
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);
  for (var i = 0; i < capture.frames.length; i++) {
    File('${dir.path}/${i.toString().padLeft(6, '0')}.png').writeAsBytesSync(capture.frames[i]);
  }
  File('${dir.path}/taps.json').writeAsStringSync(capture.tapsJson);
  File('${dir.path}/chapters.json').writeAsStringSync(capture.chaptersJson);
  final (width, height) = pngSize(capture.frames.first);
  File('${dir.path}/scene.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
    'pixelRatio': videoPixelRatio,
    'width': width,
    'height': height,
    'logicalWidth': logicalSize.width,
    'logicalHeight': logicalSize.height,
    'fps': videoFps,
    'frames': capture.frames.length,
    ...extra,
  }));
}

void expectWellFormed(
  VideoCapture capture, {
  required Set<String> unsettledTaps,
  bool settledCuts = true,
  Size logicalSize = videoLogicalSize,
}) {
  final (width, height) = pngSize(capture.frames.first);
  expect((width, height), ((logicalSize.width * videoPixelRatio).round(), (logicalSize.height * videoPixelRatio).round()));
  for (final f in capture.frames) {
    expect(pngSize(f), (width, height), reason: 'every frame must share one size');
  }
  for (final t in capture.taps) {
    expect(t.x, inInclusiveRange(0, width), reason: t.label);
    expect(t.y, inInclusiveRange(0, height), reason: t.label);
    expect(t.frame, inExclusiveRange(0, capture.frames.length), reason: t.label);
    // A settled hold precedes every tap, except into a screen that never rests.
    expect(t.settledBefore, !unsettledTaps.contains(t.label), reason: 'hold before "${t.label}"');
  }
  // Every cut between chapters is on a settled frame (a time cut excepted).
  final chapters = capture.chapters;
  for (var i = 1; i < chapters.length; i++) {
    final b = chapters[i].start;
    expect(chapters[i - 1].end, b);
    if (settledCuts && !capture.cutChapters.contains(chapters[i].name)) {
      expect(bytesEqual(capture.frames[b], capture.frames[b - 1]), isTrue,
          reason: 'boundary into "${chapters[i].name}" (frame $b) must be settled');
    }
  }
  expect(chapters.last.end, capture.frames.length - 1);
  if (settledCuts) {
    expect(bytesEqual(capture.frames.last, capture.frames[capture.frames.length - 2]), isTrue,
        reason: 'the take ends on a settled frame');
  }
}

/// How many of the frames from [t]'s on differ from the one before it.
int reactingFrames(VideoCapture capture, VideoTap t, {int holdFrames = videoPressHoldFrames}) {
  final before = capture.frames[t.frame - 1];
  final end = (t.frame + holdFrames + videoHold).clamp(0, capture.frames.length);
  return [for (var i = t.frame; i < end; i++) capture.frames[i]].where((f) => !bytesEqual(f, before)).length;
}

/// Both runs of a take, frame for frame.
void expectIdentical(String name, VideoCapture ca, VideoCapture cb) {
  final ha = frameHashes(ca);
  final hb = frameHashes(cb);
  // ignore: avoid_print
  print('determinism $name: run A ${ha.length} frames, sequence sha256 ${sequenceHash(ca)}\n'
      'determinism $name: run B ${hb.length} frames, sequence sha256 ${sequenceHash(cb)}');
  expect(hb.length, ha.length, reason: '$name: both runs must produce the same number of frames');
  final differing = [for (var i = 0; i < ha.length; i++) if (ha[i] != hb[i]) i];
  expect(differing, isEmpty, reason: '$name: frames that differ between the two runs');
  expect(cb.tapsJson, ca.tapsJson);
  expect(cb.chaptersJson, ca.chaptersJson);
}

void reportCapture(String scene, VideoCapture capture, Duration took) {
  // ignore: avoid_print
  print('video capture: $scene ${capture.frames.length} frames '
      '(${(capture.frames.length / videoFps).toStringAsFixed(2)} s) in ${took.inMilliseconds} ms, '
      'sequence sha256 ${sequenceHash(capture)}\n'
      '$scene chapters: ${capture.chaptersJson}\n'
      '$scene taps: ${capture.tapsJson}');
}
