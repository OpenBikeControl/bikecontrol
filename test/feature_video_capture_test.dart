// Films BikeControl's features one at a time, as short deterministic 30 fps
// frame sequences for the website's 1:1 feature clips — the same capture
// harness as onboarding_video_capture_test.dart (test/helpers/video_capture.dart),
// the same output format, the same determinism guarantees. Each scene is one
// feature on one screen, 6–10 s of settled, readable action, held ~0.5 s at
// either end so the compositor can crop and loop it.
//
// Staging (all test-only, nothing in the product changes):
//
// * Pro. `IAPManager.setProForTesting` puts Pro on this device, so no Go-Pro
//   dialog, trial note or daily budget is ever on film.
// * MyWhoosh on this device, connected over the Network method: the app's own
//   OpenBikeControl server runs on the offline machine, and a MyWhoosh
//   client connects to it in memory and sends its app info over the socket.
//   Controller presses reach MyWhoosh through that socket, so the actions
//   they fire succeed for real.
// * A Zwift Ride staged as a connected controller, its presses going in
//   through the Ride's own decoder (see the onboarding capture).
// * Platform output is recorded, never performed: keyboard and media keys go
//   to a fake KeyPressSimulatorPlatform, a Shortcut launch to a fake
//   url_launcher, Android global actions to the accessibility plugin's
//   message channel, all answered in memory.
// * The Android build (`feature-android-control`, `feature-hands-free-steering`)
//   is staged with `debugHostPlatformOverride`; the desktop scenes set
//   `debugDefaultTargetPlatformOverride` to macOS, which the host already is.
// * The phone's motion sensors are a fake sensors_plus platform
//   (test/helpers/fake_sensors.dart), fed on the fake clock.
//
// Output (per scene): build/video_frames/<scene>/ as in the onboarding capture;
// scene.json adds {feature, loops}. taps.json kinds are the same: "tap",
// "swipe", "hardware" (a controller button, labelled with the gesture or the
// action it fires), "event" (something the app hears from outside, or typed
// text).
//
// Tagged `video` and skipped by default (see dart_test.yaml). Run with:
//   flutter test --run-skipped --tags video test/feature_video_capture_test.dart
@Tags(['video'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:bike_control/bluetooth/devices/elite/elite_sterzo.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/openbikecontrol_device.dart' show OpenBikeControlConstants;
import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart'
    show
        debugAnimatesInScreenshotMode,
        debugKeepsControllerNamesInScreenshotMode,
        debugShowsRealKeymapsInScreenshotMode,
        navigatorKey,
        screenshotLocale,
        screenshotMode;
import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/pages/button_simulator.dart';
import 'package:bike_control/utils/actions/android.dart';
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/services/screen_recording/screen_recording_service.dart';
import 'package:bike_control/pages/navigation.dart';
import 'package:bike_control/pages/sensors/sensors_page.dart';
import 'package:bike_control/services/sensors/broadcast_controller.dart';
import 'package:bike_control/services/sensors/fake_health_kit_channel.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/services/sensors/health_kit_sensor_source.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratio_presets.dart' show gearRatioEvenSteps;
import 'package:bike_control/pages/proxy_device_details/shifting_config_picker.dart';
import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/services/workout/workout_repository.dart';
import 'package:bike_control/services/workout/workout_summary.dart';
import 'package:bike_control/widgets/overlay/trainer_overlay_view.dart';
// ignore: depend_on_referenced_packages
import 'package:image/image.dart' as img;
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:bike_control/utils/trainer_connect.dart';
import 'package:bike_control/widgets/ui/setting_tile.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart' show ftmsEmulator;
import 'package:bike_control/bluetooth/emulation/emulated_peripherals.dart' show buildFtmsTrainer;
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:bike_control/utils/actions/desktop.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/custom_keymap_selector.dart' show HotKeyListenerDialog;
import 'package:bike_control/pages/overview.dart' show activityLogClock;
import 'package:bike_control/pages/proxy_device_details/mini_workout_card.dart' show debugHideMiniWorkoutCard;
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/tacx.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:bike_control/widgets/controller/steering_gauge.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import 'helpers/fake_platform_output.dart';
import 'helpers/fake_sensors.dart';
import 'helpers/offline_machine.dart';
import 'helpers/video_capture.dart';
import 'widget_snapshot.dart';

/// The take being filmed, so a take that fails can still be looked at.
VideoRecorder? _lastRecorder;

/// The hold at either end of a clip (~0.5 s).
const _endHold = 15;

/// What every feature scene shares: the offline machine, the fake sensors and
/// the in-memory MyWhoosh client of the current take.
class _Studio {
  _Studio(this.machine, this.sensors);

  final OfflineMachine machine;
  final FakeSensorsPlatform sensors;

  /// What the app did to the machine: keys, media keys, launches, actions.
  final output = PlatformOutput();

  /// MyWhoosh on the Network method, once [_connectMyWhoosh] ran.
  FakeTcpClient? myWhoosh;

  /// The KICKR CORE bridged by [_bridgeTrainer], and its fake peripheral.
  ProxyDevice? trainer;
  String? trainerPeripheralId;

  /// The trainer's Indoor Bike Data, once a second while the rider pedals.
  Timer? pedalling;

  /// Every Virtual Shifting definition the bridge has had: the emulator
  /// rebinds a new one when its transport restarts, and each keeps a notify
  /// timer until disposed.
  final definitions = <FitnessBikeDefinition>{};
}

/// One feature clip.
class _Scene {
  const _Scene({
    required this.id,
    required this.loops,
    required this.film,
    required this.check,
    this.unsettled = const {},
    this.logicalSize = videoLogicalSize,
    this.settles = true,
  });

  /// The scene's folder under build/video_frames, and scene.json's feature.
  final String id;

  /// Whether the clip ends on the frame it starts on, so it loops seamlessly.
  final bool loops;

  final Future<VideoCapture> Function(WidgetTester tester, _Studio studio) film;

  /// Scene-specific checks on a finished capture.
  final void Function(VideoCapture capture) check;

  /// Taps into a screen that never rests.
  final Set<String> unsettled;

  /// The captured area, in logical px.
  final Size logicalSize;

  /// Whether the clip ends on a still frame (a live readout never rests).
  final bool settles;
}

/// The fake clock's now: what everything on film is timed by.
DateTime _now() => (TestWidgetsFlutterBinding.instance as AutomatedTestWidgetsFlutterBinding).clock.now();

/// Every take starts from the same stored state: MyWhoosh on this device, the
/// Network method on, Pro, nothing connected.
Future<void> _resetApp() async {
  await restorePristinePrefs();
  // The trainer an earlier take bridged is remembered in memory too (the
  // home screen names it); every take starts from a machine that never met one.
  core.connection.rememberedTrainer = null;
  core.settings.trainerAppListenable.value = null;
  await core.shiftingConfigs.init();
  ProxyDevice.debugClearRememberedGears();
  IAPManager.instance.setProForTesting(enabled: true);
  await core.settings.setOnboardingState(Settings.onboardingStateCompleted);
  await core.settings.setVibrationEnabled(false);
  core.settings.setTrainerApp(MyWhoosh());
  await core.settings.setKeyMap(MyWhoosh());
  core.settings.setLastTarget(Target.thisDevice);
  core.settings.setObpMdnsEnabled(true);
  core.actionHandler = StubActions();
  screenshotLocale = const Locale('en');
  await AppLocalizations.load(const Locale('en'));
}

/// Starts the app's OpenBikeControl server (screenshotMode keeps the app from
/// starting it itself) and connects MyWhoosh to it: an in-memory client on
/// the LAN sends its app info over the socket, as MyWhoosh does. Not on film.
Future<void> _connectMyWhoosh(WidgetTester tester, _Studio studio) async {
  await driveUntil(tester, core.obpMdnsEmulator.startServer(), 'the Network method should have started');
  final client = studio.machine.connectTcpClient(OpenBikeControlConstants.TCP_PORT);
  client.send(OpenBikeProtocolParser.encodeAppInfo(
    appId: 'MyWhoosh',
    appVersion: '1.0',
    supportedButtons: MyWhoosh().defaultObpSupportedButtons,
  ));
  await tester.pump();
  expect(core.obpMdnsEmulator.isConnected.value, isTrue, reason: 'MyWhoosh should be connected');
  studio.myWhoosh = client;
}

/// Takes down everything a take connected, so the next starts clean. Not on
/// film.
Future<void> _wrapUp(WidgetTester tester, _Studio studio) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  studio.myWhoosh?.close();
  studio.myWhoosh = null;
  await tester.pump();
  core.obpMdnsEmulator.stopServer();
  studio.pedalling?.cancel();
  studio.pedalling = null;
  // Disconnecting detaches the trainer's definition from the emulator but does
  // not dispose it, which would leave its 1 s notify timer running.
  if (studio.trainer?.fitnessBike case final def?) studio.definitions.add(def);
  if (ftmsEmulator.fitnessBike case final def?) studio.definitions.add(def);
  final overlay = TrainerOverlayService.forCurrentPlatform();
  if (overlay.isShowing.value) await overlay.hide();
  for (final device in core.connection.devices.toList()) {
    device.isConnected = false;
    await driveUntil(tester, core.connection.disconnect(device, forget: true, persistForget: false),
        '${device.runtimeType} should have been removed');
  }
  // Whatever the shared emulator still carries is left over from this take.
  for (var def = ftmsEmulator.fitnessBike; def != null; def = ftmsEmulator.fitnessBike) {
    studio.definitions.add(def);
    await driveUntil(tester, ftmsEmulator.detachDefinition(def), 'the definition should detach');
  }
  for (final def in studio.definitions) {
    def.dispose();
  }
  studio.definitions.clear();
  ftmsEmulator.isConnected.value = false;
  if (studio.trainerPeripheralId case final id?) studio.machine.ble.removePeripheral(id);
  studio.trainer = null;
  studio.trainerPeripheralId = null;
  core.actionHandler = StubActions();
  await tester.pump(const Duration(seconds: 1));
  expect(core.connection.devices, isEmpty, reason: 'the next take starts with nothing connected');
  // The binding checks this is unset before the test's tear-downs run.
  debugDefaultTargetPlatformOverride = null;
}

/// Pumps [home] once off film, decodes every asset the scene shows, then
/// mounts it afresh, lets it settle and returns the recorder with frame 0 —
/// the settled screen — captured.
Future<VideoRecorder> _roll(
  WidgetTester tester,
  GlobalKey boundary,
  Widget Function() home, {
  List<String> svgAssets = const [],
  String chapter = 'feature',
  Future<void> Function()? before,
}) async {
  useVideoView(tester);
  Widget app(Widget child) => videoApp(boundary, child, navigatorKey: navigatorKey);
  await tester.pumpWidget(app(home()));
  await tester.pump();
  await loadAllVideoFonts(tester);
  final context = tester.element(find.byType(Navigator).first);
  await tester.runAsync(() async {
    await Future.wait([
      precacheImage(const AssetImage('icon.png'), context),
      for (final a in SupportedApp.supportedApps)
        if (a.logoAsset != null) precacheImage(AssetImage(a.logoAsset!), context),
      for (final svg in svgAssets) SvgAssetLoader(svg).loadBytes(context),
    ]);
  });
  await tester.pumpWidget(app(const SizedBox()));
  await tester.pump();
  // Mounted and left to come to rest off film: a clip opens on the screen
  // as the rider finds it, not on it appearing.
  final settle = _lastRecorder = VideoRecorder(tester, boundary);
  await tester.pumpWidget(app(home()));
  await settle.first(chapter);
  if (before == null) {
    await settle.untilStill(maxFrames: 300);
  } else {
    // The top of the page may never rest (a pedalling chain): give it time,
    // scroll away from it, and only then wait for stillness.
    await settle.frames(45);
    // Where the clip opens, set up off film (a page scrolled to its section).
    await before();
    await settle.untilStill(maxFrames: 300);
  }
  final rec = _lastRecorder = VideoRecorder(tester, boundary);
  await rec.first(chapter);
  return rec;
}

// ── 1. Steering ───────────────────────────────────────────────────────────

/// The Ride's steer buttons are plain presses: its card shows them on the
/// contour, not on a gauge. The gauge belongs to steering devices, so the
/// clip uses an Elite Sterzo, fed its real angle notifications.
Future<VideoCapture> _filmSteering(WidgetTester tester, _Studio studio) async {
  await _resetApp();
  final sterzo = stageConnected(EliteSterzo(BleDevice(name: 'STERZO', deviceId: 'film-sterzo')));
  core.connection.addDevices([sterzo]);
  core.actionHandler = FilmActions()..init(core.settings.getTrainerApp());
  await _connectMyWhoosh(tester, studio);
  final forward = forwardPresses(sterzo);

  // The Sterzo's angle notification: a little-endian float32, in degrees
  // (positive steers right).
  Future<void> angle(double degrees) {
    final bytes = ByteData(4)..setFloat32(0, degrees, Endian.little);
    return sterzo.processCharacteristic(SterzoConstants.MEASUREMENT_CHARACTERISTIC_UUID, bytes.buffer.asUint8List());
  }

  // Connected and calibrated before the clip: centred, still.
  for (var i = 0; i < SterzoConstants.CALIBRATION_SAMPLE_COUNT; i++) {
    await angle(0);
  }
  expect(sterzo.steeringCalibrated.value, isTrue);

  final boundary = GlobalKey();
  final rec = await _roll(tester, boundary, () => const Navigation());
  final gauge = find.byType(SteeringGauge);
  rec.sighting('steering-gauge', gauge);
  await rec.frames(_endHold);

  // One sweep: out to [peak] degrees and back to centre over 1.2 s, one
  // notification a frame (the Sterzo streams far faster; one a frame is all
  // the film can show).
  Future<void> sweep(String label, double peak) => rec.hardware(
        label,
        at: gauge,
        anchor: 'reaction',
        press: () => angle(0),
        holdFrames: 0,
        thenFrames: 0,
      ).then((_) async {
        const frames = 36;
        for (var i = 1; i <= frames; i++) {
          await angle(peak * math.sin(math.pi * i / frames));
          await rec.step();
        }
        await angle(0);
        await rec.untilStill();
      });

  await sweep('Sterzo: steer left', -25);
  await sweep('Sterzo: steer right', 25);
  await rec.frames(_endHold);
  unawaited(forward.cancel());
  await _wrapUp(tester, studio);
  return rec.capture;
}

void _checkSteering(VideoCapture c) {
  for (final t in c.taps.where((t) => t.kind == 'hardware')) {
    expect(reactingFrames(c, t, holdFrames: 36), greaterThan(20), reason: '"${t.label}" should move the gauge');
  }
}

// ── Shared staging ────────────────────────────────────────────────────────

/// A connected Zwift Ride, staged as in the onboarding capture, its presses
/// forwarded to the app. A fresh one per take.
ZwiftRide _stageRide() {
  final ride = stageConnected(ZwiftRide(BleDevice(name: 'Zwift Ride', deviceId: '00:11:22:33:44:55')));
  core.connection.addDevices([ride]);
  return ride;
}

/// Opens [button]'s trigger menu from the home screen's controller card and
/// picks [trigger]: the button editor opens in its drawer.
Future<void> _openEditor(VideoRecorder rec, ControllerButton button, ButtonTrigger trigger, String what) async {
  await rec.tap(find.byKey(ValueKey(button.name)), '$what: open ${button.name}');
  await rec.tap(find.text(trigger.title).hitTestable(), '$what: ${trigger.title}');
  expect(find.byType(ButtonEditPage), findsOneWidget, reason: 'the button editor should be open');
}

/// Taps a card in the open button editor, scrolling the editor to it first
/// if it is below the fold (filmed as a swipe).
Future<void> _tapEditorCard(VideoRecorder rec, WidgetTester tester, Finder card, String label) async {
  final editor = find.descendant(of: find.byType(ButtonEditPage), matching: find.byType(Scrollable)).first;
  for (var i = 0; i < 6 && card.hitTestable().evaluate().isEmpty; i++) {
    final box = tester.getRect(editor);
    // Mid-drawer: the bottom edge is where toasts sit.
    // A flick, so the list carries on by itself.
    await rec.swipe(Offset(box.center.dx, box.center.dy + 200), Offset(box.center.dx, box.center.dy - 200),
        'Scroll the editor', overFrames: 6);
  }
  await rec.tap(card, label);
}

Finder _card(String title) => find.ancestor(of: find.text(title), matching: find.byType(SelectableCard)).first;

/// Closes the button editor's drawer with a tap beside it, on the dimmed
/// screen (its ✕ has scrolled away by then).
Future<void> _closeEditor(VideoRecorder rec) async {
  await rec.tapAt(const Offset(20, 420), 'Close the editor');
  expect(find.byType(ButtonEditPage), findsNothing, reason: 'the editor should have closed');
}

/// Shows the Activity tab, where every fired action is logged.
Future<void> _showActivity(VideoRecorder rec) =>
    rec.tap(find.text(AppLocalizations.current.activity).hitTestable().first, 'Activity');

// ── 2. Full control ───────────────────────────────────────────────────────

/// A Ride button gets a keyboard key in the button editor; pressing it then
/// presses that key on this Mac. The app confirms a fired action in its
/// activity log ("Key clicked: …"), which is where the clip ends.
Future<VideoCapture> _filmFullControl(WidgetTester tester, _Studio studio) async {
  final ride = await _stageDesktop(tester, studio);
  final forward = forwardPresses(ride);

  final boundary = GlobalKey();
  final rec = await _roll(tester, boundary, () => const Navigation(), svgAssets: [ride.controllerLayout.svgAsset!]);
  await rec.frames(_endHold);

  await _openEditor(rec, ZwiftButtons.y, ButtonTrigger.singleClick, 'Y');
  await _tapEditorCard(rec, tester, _card(AppLocalizations.current.simulateKeyboardShortcut), 'Simulate keyboard shortcut');
  await rec.tap(find.text(AppLocalizations.current.customLabel).hitTestable(), 'Custom key');
  await rec.event('Key pressed: Arrow Up', find.byType(HotKeyListenerDialog), () async {
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
  });
  await rec.tap(find.text(AppLocalizations.current.ok).hitTestable(), 'OK');
  await _closeEditor(rec);

  await rec.hardwarePress(ride, RideButtonMask.Y_BTN, ZwiftButtons.y, 'Ride button Y → Arrow Up key');
  expect(studio.output.performed, ['key down Arrow Up', 'key up Arrow Up'],
      reason: 'the Y press should have pressed and released Arrow Up');
  await _showActivity(rec);
  await rec.frames(_endHold);
  unawaited(forward.cancel());
  await _wrapUp(tester, studio);
  return rec.capture;
}

/// The desktop build (the host is a Mac): a Ride, MyWhoosh on the Network
/// method, local control on, the real macOS action handler.
Future<ZwiftRide> _stageDesktop(WidgetTester tester, _Studio studio) async {
  await _resetApp();
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  core.settings.setLocalEnabled(true);
  final ride = _stageRide();
  core.actionHandler = DesktopActions()..init(core.settings.getTrainerApp());
  await _connectMyWhoosh(tester, studio);
  studio.output.performed.clear();
  return ride;
}

/// A Ride press as a gesture: one press (single), two quick ones (double),
/// or one held ~0.8 s, past the long-press delay (long).
Future<void> _gesture(VideoRecorder rec, ZwiftRide ride, RideButtonMask mask, ControllerButton button, ButtonTrigger trigger,
    String label) async {
  final at = find.byKey(ValueKey(button.name));
  switch (trigger) {
    case ButtonTrigger.singleClick:
      await rec.hardwarePress(ride, mask, button, label);
    case ButtonTrigger.doubleClick:
      await rec.hardware(
        label,
        at: at,
        anchor: 'contour-button',
        press: () => ridePress(ride, [mask]),
        holdFrames: 4,
        release: () async {
          await ridePress(ride, const []);
          await rec.frames(4);
          await ridePress(ride, [mask]);
          await rec.frames(4);
          await ridePress(ride, const []);
        },
      );
    case ButtonTrigger.longPress:
      await rec.hardwarePress(ride, mask, button, label, holdFrames: 25);
  }
}

/// A recorder that never touches the screen: records starts and stops.
class _FakeScreenRecorder implements ScreenRecorderBackend {
  final calls = <String>[];

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<bool> start() async {
    calls.add('start');
    return true;
  }

  @override
  Future<String?> stop() async {
    calls.add('stop');
    return '/Users/rider/Movies/BikeControl recording.mov';
  }
}

// ── 3. Customizability ────────────────────────────────────────────────────

/// Keymap profiles on the Ride's settings page. A's single click is remapped
/// to Steer Left: MyWhoosh's own profile can't be edited, so the app
/// duplicates it as "MyWhoosh (Copy)" first. The copy is renamed "Race day",
/// and the clip switches back to MyWhoosh, the frame it started on.
Future<VideoCapture> _filmCustomizability(WidgetTester tester, _Studio studio) async {
  final ride = await _stageDesktop(tester, studio);
  final forward = forwardPresses(ride);
  final l10n = AppLocalizations.current;

  final boundary = GlobalKey();
  final rec = await _roll(tester, boundary, () => ControllerSettingsPage(device: ride),
      svgAssets: [ride.controllerLayout.svgAsset!]);
  await rec.frames(_endHold);

  // A's single click, in the mapping table.
  await rec.tap(find.text(InGameAction.select.title).hitTestable().first, 'A: Single Click');
  expect(find.byType(ButtonEditPage), findsOneWidget);
  expect(core.actionHandler.supportedApp?.name, 'MyWhoosh (Copy)', reason: 'editing duplicates the profile');
  await rec.tap(_card(InGameAction.steerLeft.title), 'A → Steer Left');
  await _closeEditor(rec);
  expect(core.actionHandler.supportedApp!.keymap.getKeyPair(ZwiftButtons.a)?.inGameAction, InGameAction.steerLeft);

  final manage = find.ancestor(of: find.byIcon(Icons.settings), matching: find.byType(Button)).first;
  await rec.tap(manage, 'Profile menu');
  await rec.tap(find.text(l10n.rename).hitTestable(), 'Rename');
  await rec.type('Name: Race day', find.byType(TextField).last, 'Race day');
  await rec.tap(find.text(l10n.rename).hitTestable().last, 'Rename profile');
  expect(core.actionHandler.supportedApp?.name, 'Race day');

  // Back to the profile the clip opened on.
  await rec.tap(find.byType(Select<SupportedApp?>), 'Profiles');
  await rec.tap(find.text('MyWhoosh').hitTestable().last, 'MyWhoosh profile');
  expect(core.actionHandler.supportedApp, isA<MyWhoosh>());
  await rec.frames(_endHold);
  unawaited(forward.cancel());
  await _wrapUp(tester, studio);
  return rec.capture;
}

// ── 5. Button gestures ────────────────────────────────────────────────────

/// One Ride button, three actions: Z shifts up on a single press, down on a
/// double press, and steers left while held. Each gesture then fires its own
/// action, which the activity log lists.
Future<VideoCapture> _filmGestures(WidgetTester tester, _Studio studio) async {
  final ride = await _stageDesktop(tester, studio);
  final forward = forwardPresses(ride);

  final boundary = GlobalKey();
  final rec = await _roll(tester, boundary, () => const Navigation(), svgAssets: [ride.controllerLayout.svgAsset!]);
  await rec.frames(_endHold);

  const assignments = [
    (ButtonTrigger.singleClick, InGameAction.shiftUp),
    (ButtonTrigger.doubleClick, InGameAction.shiftDown),
    (ButtonTrigger.longPress, InGameAction.steerLeft),
  ];
  for (final (trigger, action) in assignments) {
    await _openEditor(rec, ZwiftButtons.z, trigger, 'Z');
    await rec.tap(_card(action.title), 'Z ${trigger.title} → ${action.title}');
    await _closeEditor(rec);
  }
  // The popup shows all three triggers assigned.
  await rec.tap(find.byKey(const ValueKey('z')), 'Z: show its triggers');
  final keymap = core.actionHandler.supportedApp!.keymap;
  for (final (trigger, action) in assignments) {
    expect(keymap.getKeyPair(ZwiftButtons.z, trigger: trigger)?.inGameAction, action);
    expect(find.text(trigger.title).hitTestable(), findsOneWidget, reason: '${trigger.title} is listed');
  }
  await rec.frames(45);
  await rec.tapAt(const Offset(20, 120), 'Close the menu');

  for (final (trigger, action) in assignments) {
    await _gesture(rec, ride, RideButtonMask.Z_BTN, ZwiftButtons.z, trigger,
        'Ride button Z, ${trigger.title.toLowerCase()} → ${action.title}');
  }
  await _showActivity(rec);
  await rec.frames(_endHold);
  unawaited(forward.cancel());
  await _wrapUp(tester, studio);
  return rec.capture;
}

// ── 6. Music ──────────────────────────────────────────────────────────────

/// Two Ride buttons become media keys: Z plays and pauses, Y skips to the
/// next track. Pressing them sends the media keys to the Mac.
Future<VideoCapture> _filmMusic(WidgetTester tester, _Studio studio) async {
  final ride = await _stageDesktop(tester, studio);
  final forward = forwardPresses(ride);
  final l10n = AppLocalizations.current;

  final boundary = GlobalKey();
  final rec = await _roll(tester, boundary, () => const Navigation(), svgAssets: [ride.controllerLayout.svgAsset!]);
  await rec.frames(_endHold);

  for (final (button, name, label) in [(ZwiftButtons.z, 'Z', l10n.playPause), (ZwiftButtons.y, 'Y', l10n.next)]) {
    await _openEditor(rec, button, ButtonTrigger.singleClick, name);
    await _tapEditorCard(rec, tester, _card(l10n.simulateMediaKey), 'Control music playback');
    await rec.tap(find.text(label).hitTestable(), '$name → $label');
    await _closeEditor(rec);
  }
  await rec.hardwarePress(ride, RideButtonMask.Z_BTN, ZwiftButtons.z, 'Ride button Z → Play/Pause');
  await rec.hardwarePress(ride, RideButtonMask.Y_BTN, ZwiftButtons.y, 'Ride button Y → Next track');
  expect(studio.output.performed, ['media Media Play Pause', 'media Media Track Next']);
  await _showActivity(rec);
  await rec.frames(_endHold);
  unawaited(forward.cancel());
  await _wrapUp(tester, studio);
  return rec.capture;
}

// ── 9. Screen recording ───────────────────────────────────────────────────

/// "Take Screenshot" saves into the working directory it finds on disk, which
/// on film would print this machine's paths; the clip films its sibling,
/// Screen Recording, instead: Z starts a recording and, pressed again, saves
/// it. The recorder behind it is a fake that records nothing.
Future<VideoCapture> _filmScreenRecording(WidgetTester tester, _Studio studio) async {
  final ride = await _stageDesktop(tester, studio);
  final recorder = _FakeScreenRecorder();
  final realRecording = core.screenRecording;
  core.screenRecording = ScreenRecordingService(backend: recorder);
  final forward = forwardPresses(ride);
  final l10n = AppLocalizations.current;

  final boundary = GlobalKey();
  final rec = await _roll(tester, boundary, () => const Navigation(), svgAssets: [ride.controllerLayout.svgAsset!]);
  await rec.frames(_endHold);

  await _openEditor(rec, ZwiftButtons.z, ButtonTrigger.singleClick, 'Z');
  await _tapEditorCard(rec, tester, _card(l10n.actionScreenRecording), 'Screen recording');
  await _closeEditor(rec);
  await rec.hardwarePress(ride, RideButtonMask.Z_BTN, ZwiftButtons.z, 'Ride button Z → start screen recording');
  await rec.frames(30);
  await rec.hardwarePress(ride, RideButtonMask.Z_BTN, ZwiftButtons.z, 'Ride button Z → save screen recording');
  expect(recorder.calls, ['start', 'stop']);
  await _showActivity(rec);
  await rec.frames(_endHold);
  unawaited(forward.cancel());
  core.screenRecording = realRecording;
  await _wrapUp(tester, studio);
  return rec.capture;
}

// ── 10. Launch a command ──────────────────────────────────────────────────

/// On a Mac a button can run a Shortcut: Z gets "Start stream", and pressing
/// it asks macOS to run that Shortcut (recorded, never run).
Future<VideoCapture> _filmLaunchCommand(WidgetTester tester, _Studio studio) async {
  final ride = await _stageDesktop(tester, studio);
  final forward = forwardPresses(ride);

  final boundary = GlobalKey();
  final rec = await _roll(tester, boundary, () => const Navigation(), svgAssets: [ride.controllerLayout.svgAsset!]);
  await rec.frames(_endHold);

  await _openEditor(rec, ZwiftButtons.z, ButtonTrigger.singleClick, 'Z');
  await _tapEditorCard(rec, tester, _card('Launch Shortcut'), 'Launch Shortcut');
  await rec.type('Shortcut: Start stream', find.byType(TextField).last, 'Start stream');
  await rec.tap(find.text('Save').hitTestable(), 'Save');
  await _closeEditor(rec);
  await rec.hardwarePress(ride, RideButtonMask.Z_BTN, ZwiftButtons.z, 'Ride button Z → run Shortcut "Start stream"');
  expect(studio.output.performed, ['launch shortcuts://run-shortcut?name=Start stream']);
  await _showActivity(rec);
  await rec.frames(_endHold);
  unawaited(forward.cancel());
  await _wrapUp(tester, studio);
  return rec.capture;
}

/// Swipes the screen's middle ([up]: content moves up) until [target] is on
/// screen and hittable.
Future<void> _scrollTo(VideoRecorder rec, Finder target, String label, {bool up = true, double by = 300}) async {
  for (var i = 0; i < 8 && target.hitTestable().evaluate().isEmpty; i++) {
    final from = Offset(190, up ? 560 : 260);
    await rec.swipe(from, from.translate(0, up ? -by : by), label);
  }
  expect(target.hitTestable(), findsWidgets, reason: '$label should bring it on screen');
}

/// Swipes down until the page's scroll view is back at its top.
Future<void> _scrollToTop(VideoRecorder rec, WidgetTester tester, String label) async {
  ScrollPosition position() => tester.state<ScrollableState>(find.byType(Scrollable).hitTestable().first).position;
  for (var i = 0; i < 8 && position().pixels > 0; i++) {
    await rec.swipe(const Offset(190, 260), const Offset(190, 660), label);
  }
  expect(position().pixels, 0, reason: '$label should reach the top');
}

// ── 4. Companion mode ─────────────────────────────────────────────────────

/// The on-screen buttons: tapping one sends that action to MyWhoosh, as a
/// controller button would.
Future<VideoCapture> _filmCompanion(WidgetTester tester, _Studio studio) async {
  await _resetApp();
  core.actionHandler = FilmActions()..init(core.settings.getTrainerApp());
  await _connectMyWhoosh(tester, studio);
  final sent = studio.myWhoosh!.received;

  final boundary = GlobalKey();
  final rec = await _roll(tester, boundary, () => const ButtonSimulator());
  await rec.frames(_endHold);
  for (final action in [InGameAction.shiftUp, InGameAction.shiftDown, InGameAction.steerLeft]) {
    final before = sent.length;
    final button = find.text(action.title);
    if (button.hitTestable().evaluate().isEmpty) await _scrollTo(rec, button, 'Scroll to steering');
    await rec.tap(button.hitTestable().first, 'Companion: ${action.title}');
    expect(sent.length, greaterThan(before), reason: '${action.title} should reach MyWhoosh');
  }
  // Back to the top, where the clip began.
  await _scrollToTop(rec, tester, 'Scroll back to shifting');
  // The scrollbar fades out a moment after the scroll ends.
  await rec.frames(30);
  await rec.untilStill();
  await rec.frames(_endHold);
  await _wrapUp(tester, studio);
  return rec.capture;
}

// ── 7. Android control ────────────────────────────────────────────────────

/// On Android, buttons can press the system's own keys through the
/// accessibility service: Y goes Home, Z goes Back.
Future<VideoCapture> _filmAndroidControl(WidgetTester tester, _Studio studio) async {
  await _resetApp();
  debugHostPlatformOverride = TargetPlatform.android;
  core.settings.setLocalEnabled(true);
  final ride = _stageRide();
  core.actionHandler = AndroidActions()..init(core.settings.getTrainerApp());
  await _connectMyWhoosh(tester, studio);
  studio.output.performed.clear();
  final forward = forwardPresses(ride);
  final l10n = AppLocalizations.current;

  final boundary = GlobalKey();
  final rec = await _roll(tester, boundary, () => const Navigation(), svgAssets: [ride.controllerLayout.svgAsset!]);
  await rec.frames(_endHold);

  const assignments = [
    (ZwiftButtons.y, RideButtonMask.Y_BTN, 'Y', AndroidSystemAction.home),
    (ZwiftButtons.z, RideButtonMask.Z_BTN, 'Z', AndroidSystemAction.back),
  ];
  for (final (button, _, name, action) in assignments) {
    await _openEditor(rec, button, ButtonTrigger.singleClick, name);
    await _tapEditorCard(rec, tester, _card(l10n.androidSystemAction), 'Android system action');
    await rec.tap(find.text(action.title).hitTestable().last, '$name → ${action.title}');
    await _closeEditor(rec);
  }
  for (final (button, mask, name, action) in assignments) {
    await rec.hardwarePress(ride, mask, button, 'Ride button $name → ${action.title}');
  }
  expect(studio.output.performed, ['global home', 'global back']);
  await _showActivity(rec);
  await rec.frames(_endHold);
  unawaited(forward.cancel());
  await _wrapUp(tester, studio);
  return rec.capture;
}

// ── 8. Hands-free steering ────────────────────────────────────────────────

/// On a phone on the bars, steering comes from its motion sensors: the rider
/// switches phone steering on, it calibrates while the bars are still, and
/// the gauge follows the bars turning left and right.
Future<VideoCapture> _filmHandsFreeSteering(WidgetTester tester, _Studio studio) async {
  await _resetApp();
  debugHostPlatformOverride = TargetPlatform.android;
  core.actionHandler = FilmActions()..init(core.settings.getTrainerApp());
  await _connectMyWhoosh(tester, studio);
  final l10n = AppLocalizations.current;

  // The phone's sensors at 50 Hz on the fake clock; [yaw] is how fast the
  // bars turn (rad/s, positive turns them left).
  var yaw = 0.0;
  final sensors = Timer.periodic(const Duration(milliseconds: 20), (_) => studio.sensors.turning(yaw, _now()));

  final boundary = GlobalKey();
  final rec = await _roll(tester, boundary, () => const Navigation());
  await rec.frames(_endHold);

  final toggle = find.text(l10n.enableSteeringWithPhone);
  await _scrollTo(rec, toggle, 'Scroll to phone steering');
  await rec.tap(toggle, 'Enable steering with the phone', thenFrames: 0);
  // What the connection queue does for a newly added device (it doesn't run
  // under screenshotMode): connect it. It then calibrates on its own.
  final phone = core.connection.gyroscopeDevices.single..nowFn = _now;
  await phone.connect();
  await rec.untilStill(maxFrames: 120);
  expect(phone.steeringCalibrated.value, isTrue, reason: 'it calibrates while the bars are still');

  final gauge = find.byType(SteeringGauge);
  await _scrollTo(rec, gauge, 'Scroll back to the controllers', up: false, by: 400);
  rec.sighting('phone-steering-gauge', gauge);

  Future<void> turn(String label, double rate) => rec.hardware(
        label,
        at: gauge,
        anchor: 'reaction',
        press: () async => yaw = rate,
        holdFrames: 15,
        release: () async => yaw = 0,
        thenFrames: 30,
      ).then((_) async {
        // …and back to the middle.
        yaw = -rate;
        await rec.frames(15);
        yaw = 0;
        await rec.untilStill();
      });
  await turn('Phone tilts left', 0.6);
  await turn('Phone tilts right', -0.6);
  expect(phone.steeringAngle.value.abs(), lessThan(1), reason: 'the bars are back in the middle');
  await rec.frames(_endHold);
  sensors.cancel();
  await _wrapUp(tester, studio);
  return rec.capture;
}

// ── Trainer staging ───────────────────────────────────────────────────────

/// A KICKR CORE found over the offline machine's Bluetooth and bridged the
/// way the trainer picker bridges it, then paired by MyWhoosh. Not on film.
Future<ProxyDevice> _bridgeTrainer(WidgetTester tester, _Studio studio) async {
  final peripheral = buildFtmsTrainer(deviceId: 'film-kickr', name: 'KICKR CORE');
  studio.machine.ble.addPeripheral(peripheral);
  final trainer = ProxyDevice(peripheral.scanResult);
  core.connection.addDevices([trainer]);
  studio
    ..trainer = trainer
    ..trainerPeripheralId = peripheral.deviceId;
  useVideoView(tester);
  await tester.pumpWidget(videoApp(GlobalKey(), const SizedBox()));
  final context = tester.element(find.byType(SizedBox).last);
  late bool bridged;
  await driveUntil(tester, connectTrainerFromPicker(context, trainer).then((ok) => bridged = ok),
      'the trainer should have been bridged');
  expect(bridged, isTrue);
  expect(trainer.fitnessBike, isNotNull, reason: 'the bridge carries Virtual Shifting');
  studio.definitions.add(trainer.fitnessBike!);
  // MyWhoosh picks up "KICKR CORE - BikeControl" as its trainer.
  ftmsEmulator.isConnected.value = true;
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  return trainer;
}

/// The rider pedals: the trainer notifies Indoor Bike Data once a second, at
/// [cadence] rpm and the power [watts] gives for each second.
void _pedal(_Studio studio, {int cadence = 90, int Function(int second)? watts}) {
  final trainer = studio.trainer!;
  var second = 0;
  void notify() => unawaited(trainer.processCharacteristic(
        FitnessBikeDefinition.INDOOR_BIKE_DATA_UUID,
        Uint8List.fromList(indoorBikeData(cadenceRpm: cadence, powerW: watts?.call(second++) ?? 250)),
      ));
  notify();
  studio.pedalling = Timer.periodic(const Duration(seconds: 1), (_) => notify());
}

/// Scrolls [target] into view before the clip starts (off film).
Future<void> _startAt(WidgetTester tester, Finder target, {double alignment = 0.0}) async {
  await tester.ensureVisible(target);
  await tester.pump();
  await Scrollable.ensureVisible(tester.element(target), alignment: alignment);
  await tester.pump(const Duration(seconds: 1));
}

// ── 11. Overlay ───────────────────────────────────────────────────────────

/// The gear overlay's settings on the trainer's page (this Mac's build): the
/// overlay is switched on, the gear ratio and the − / + controls are added to
/// it, it is faded to 75 %, and it is switched off again. The settings have
/// no position control: on a Mac the overlay is its own window and is placed
/// by dragging it.
Future<VideoCapture> _filmOverlaySettings(WidgetTester tester, _Studio studio) async {
  await _resetApp();
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  await core.settings.setOverlayFields({OverlayField.power, OverlayField.cadence});
  await core.settings.setOverlayOpacity(1.0);
  await _connectMyWhoosh(tester, studio);
  final trainer = await _bridgeTrainer(tester, studio);
  final l10n = AppLocalizations.current;

  final boundary = GlobalKey();
  final roll = await _roll(tester, boundary, () => ProxyDeviceDetailsPage(device: trainer),
      before: () => _startAt(tester, find.text(l10n.overlaySection), alignment: 0.15));
  await roll.frames(_endHold);

  Finder switchIn(String title) =>
      find.descendant(of: find.ancestor(of: find.text(title), matching: find.byType(Row)).first, matching: find.byType(Switch));
  final overlaySwitch = find.descendant(
    of: find.ancestor(of: find.text(l10n.overlayEnabled), matching: find.byType(SettingTile)).first,
    matching: find.byType(Switch),
  ).first;
  await roll.tap(overlaySwitch, 'Show the overlay');
  expect(TrainerOverlayService.forCurrentPlatform().isShowing.value, isTrue);
  await roll.tap(switchIn(l10n.overlayFieldGearRatio), 'Field: gear ratio');
  await roll.tap(switchIn(l10n.overlayFieldControls), 'Field: − / + controls');
  expect(core.settings.getOverlayFields(),
      {OverlayField.power, OverlayField.cadence, OverlayField.gearRatio, OverlayField.controls});

  final slider = find.byType(Slider);
  await _scrollTo(roll, slider, 'Scroll to opacity');
  final track = tester.getRect(slider);
  await roll.swipe(Offset(track.right - 8, track.center.dy), Offset(track.left + track.width * 0.62, track.center.dy),
      'Opacity: 75 %');
  expect(find.text('75%'), findsOneWidget, reason: 'the overlay is faded to 75 %');
  await roll.frames(30);

  await _scrollToTopOf(roll, tester, find.text(l10n.overlaySection), 'Scroll back');
  await roll.tap(overlaySwitch, 'Hide the overlay');
  await roll.frames(_endHold);
  await _wrapUp(tester, studio);
  return roll.capture;
}

/// Swipes down until [target] is back where [_startAt] put it (its top at
/// 15 % of the page), for a clip that loops.
Future<void> _scrollToTopOf(VideoRecorder rec, WidgetTester tester, Finder target, String label) async {
  for (var i = 0; i < 6 && target.hitTestable().evaluate().isEmpty; i++) {
    await rec.swipe(const Offset(190, 300), const Offset(190, 600), label);
  }
}

// ── 11b. The overlay itself ───────────────────────────────────────────────

/// The overlay's own size on film (logical px): Android's floating card at its
/// narrowest (no − / + controls), with a little transparent margin.
const _overlayViewSize = Size(176, 80);

/// The gear overlay alone, on a transparent background, for the compositor to
/// float over a trainer app. It is the Android overlay's card (the desktop
/// overlay window has a plain white window behind the same view). Its data is
/// live: the rider pedals (the power changes every second) and shifts on the
/// Ride, through the real action pipeline, onto the bridged trainer.
Future<VideoCapture> _filmOverlayView(WidgetTester tester, _Studio studio) async {
  await _resetApp();
  await _connectMyWhoosh(tester, studio);
  final ride = _stageRide();
  final trainer = await _bridgeTrainer(tester, studio);
  core.actionHandler = FilmActions()..init(core.settings.getTrainerApp());
  final forward = forwardPresses(ride);
  const watts = [248, 252, 257, 251, 246, 255, 262, 258, 250, 253, 249, 256];
  _pedal(studio, watts: (second) => watts[second % watts.length]);
  // Settle the bridge before reading its definition: MyWhoosh picking the
  // trainer up may rebind it.
  await tester.pump(const Duration(seconds: 1));
  final def = trainer.fitnessBike!;
  expect(ftmsEmulator.fitnessBike, same(def), reason: 'the bridge serves this definition');

  // What the overlay controllers push to their window, built from the same
  // notifiers on every change.
  const fields = {OverlayField.power, OverlayField.cadence};
  TrainerOverlayState read() => TrainerOverlayState(
        gear: def.currentGear.value,
        maxGear: def.maxGear,
        gearRatio: def.gearRatio.value,
        mode: def.trainerMode.value,
        powerW: def.powerW.value,
        cadenceRpm: def.cadenceRpm.value,
        ergTargetW: def.ergTargetPower.value,
        fields: fields,
        frontShiftEnabled: def.frontShiftEnabled,
        frontRingLarge: def.frontRing.value == FrontRing.large,
      );
  final state = ValueNotifier(read());
  final live = Listenable.merge([def.currentGear, def.gearRatio, def.trainerMode, def.powerW, def.cadenceRpm]);
  void update() => state.value = read();
  live.addListener(update);

  useVideoView(tester);
  final boundary = GlobalKey();
  Widget home() => Center(
        child: RepaintBoundary(
          key: boundary,
          child: SizedBox.fromSize(
            size: _overlayViewSize,
            child: Center(child: TrainerOverlayView(state: state)),
          ),
        ),
      );
  await tester.pumpWidget(videoApp(GlobalKey(), home()));
  await tester.pump();
  await loadAllVideoFonts(tester);
  await tester.runAsync(() => precacheImage(const AssetImage('icon.png'), tester.element(find.byType(TrainerOverlayView))));
  await tester.pump(const Duration(seconds: 1));
  final rec = _lastRecorder = VideoRecorder(tester, boundary);
  await rec.first('feature');
  await rec.frames(_endHold);

  final view = find.byType(TrainerOverlayView);
  for (final (mask, button, label) in [
    (RideButtonMask.SHFT_UP_R_BTN, ZwiftButtons.shiftUpRight, 'Ride: shift up'),
    (RideButtonMask.SHFT_UP_R_BTN, ZwiftButtons.shiftUpRight, 'Ride: shift up again'),
    (RideButtonMask.SHFT_DN_L_BTN, ZwiftButtons.shiftDownLeft, 'Ride: shift down'),
  ]) {
    final before = def.currentGear.value;
    await rec.hardwarePress(ride, mask, button, label, reactsAt: view, thenFrames: 45);
    expect(def.currentGear.value, isNot(before), reason: '"$label" should change the gear');
  }
  await rec.frames(60);
  live.removeListener(update);
  unawaited(forward.cancel());
  await _wrapUp(tester, studio);
  return rec.capture;
}

/// The overlay's frames keep their transparency around the card.
void _checkOverlayView(VideoCapture c) {
  final png = img.decodePng(c.frames.first)!;
  expect(png.numChannels, 4, reason: 'frames carry alpha');
  expect(png.getPixel(0, 0).a, 0, reason: 'outside the card is transparent');
  final centre = png.getPixel(png.width ~/ 2, png.height ~/ 2);
  expect(centre.a, greaterThan(0), reason: 'the card itself is drawn');
  // The power reading changes as the rider pedals; each shift changes the
  // gear.
  _checkPresses(c);
}

// ── 13. Mini workout ──────────────────────────────────────────────────────

/// A saved ride that goes nowhere: the summary dialog needs a file to share.
class _MemoryWorkoutRepository extends WorkoutRepository {
  final saved = <WorkoutSummary?>[];

  @override
  Future<File> save({required DateTime startedAt, required List<int> fitBytes, WorkoutSummary? summary}) async {
    saved.add(summary);
    return File('/Users/rider/Documents/workouts/BikeControl ride.fit');
  }
}

/// The Mini Workout card on the trainer's page: the rider starts a workout,
/// it records for a while (the clip cuts from its 3rd to its 11th second),
/// then stops it and gets the summary.
Future<VideoCapture> _filmMiniWorkout(WidgetTester tester, _Studio studio) async {
  await _resetApp();
  await _connectMyWhoosh(tester, studio);
  final trainer = await _bridgeTrainer(tester, studio);
  _pedal(studio);
  final realClock = core.workoutRecorder.nowProvider;
  core.workoutRecorder.nowProvider = _now;
  final realRepository = core.workoutRepository;
  final repository = core.workoutRepository = _MemoryWorkoutRepository();
  final l10n = AppLocalizations.current;

  final boundary = GlobalKey();
  final rec = await _roll(tester, boundary, () => ProxyDeviceDetailsPage(device: trainer),
      before: () => _startAt(tester, find.text(l10n.miniWorkout), alignment: 0.05));
  rec.sighting('mini-workout', find.text(l10n.miniWorkout));
  await rec.frames(_endHold);

  await rec.tap(find.text(l10n.miniWorkoutStart), 'Start workout', thenFrames: 100);
  await rec.cut('recording', const Duration(seconds: 8));
  await rec.frames(24);
  await rec.tap(find.byIcon(LucideIcons.square), 'Stop', thenFrames: 20);
  await rec.tap(find.text(l10n.miniWorkoutStop).hitTestable().last, 'Stop and save');
  expect(repository.saved, hasLength(1), reason: 'the ride is saved');
  rec.sighting('summary', find.text(l10n.miniWorkoutSummaryTitle));
  await rec.frames(60);

  core.workoutRecorder.nowProvider = realClock;
  core.workoutRepository = realRepository;
  await _wrapUp(tester, studio);
  return rec.capture;
}

// ── 14. Setting profiles ──────────────────────────────────────────────────

/// Named Virtual Shifting setups per trainer: the rider switches from
/// "Default" to "Climb" (easier gears, a lighter bike) and back; the gear
/// settings' ratio curve and summary change with it.
Future<VideoCapture> _filmSettingProfiles(WidgetTester tester, _Studio studio) async {
  await _resetApp();
  await _connectMyWhoosh(tester, studio);
  final trainer = await _bridgeTrainer(tester, studio);
  final base = core.shiftingConfigs.activeFor(trainer.trainerKey);
  await core.shiftingConfigs.upsert(base);
  await core.shiftingConfigs.upsert(base.copyWith(
    name: 'Climb',
    isActive: false,
    bikeWeightKg: 7.5,
    gearRatios: gearRatioEvenSteps(0.55, 3.2, base.maxGear),
  ));
  final def = trainer.fitnessBike!;

  final boundary = GlobalKey();
  final rec = await _roll(tester, boundary, () => ProxyDeviceDetailsPage(device: trainer),
      before: () => _startAt(tester, find.byType(ShiftingConfigPicker), alignment: 0.05));
  await rec.frames(_endHold);

  final picker = find.descendant(of: find.byType(ShiftingConfigPicker), matching: find.byType(Select<ShiftingConfig>));
  await rec.tap(picker, 'Setups');
  await rec.tap(find.text('Climb').hitTestable().last, 'Climb');
  expect(def.gearRatios.value.last, closeTo(3.2, 0.001), reason: 'Climb has easier gears');
  await rec.frames(45);
  await rec.tap(picker, 'Setups again');
  await rec.tap(find.text(base.name).hitTestable().last, base.name);
  expect(core.shiftingConfigs.activeFor(trainer.trainerKey).name, base.name);
  await rec.frames(_endHold);
  await _wrapUp(tester, studio);
  return rec.capture;
}

// ── 12. Heart rate ────────────────────────────────────────────────────────

/// The Sensors page with no trainer: the rider picks Apple Health as the
/// heart-rate source (AirPods Pro 3 or an Apple Watch feed it), shares it
/// over the network, and the reading ticks. HealthKit is the iPhone's: the
/// source is the app's own HealthKitSensorSource over a scripted channel
/// (FakeHealthKitChannel), which is how the app's tests stand HealthKit in;
/// the rest of the page is the macOS host's. The switch is the app's own
/// BroadcastController, wired to the connection's real source connect and
/// disconnect as at app start; only the advertising sink behind it is not
/// stood up (it reports itself running), like every other platform output
/// on these films.
Future<VideoCapture> _filmHeartRate(WidgetTester tester, _Studio studio) async {
  await _resetApp();
  final channel = FakeHealthKitChannel();
  final realSource = core.connection.healthKitSource;
  core.connection.healthKitSource = HealthKitSensorSource(channel: channel);
  core.sensors.isProEnabled = () => IAPManager.instance.isProEnabledForCurrentDevice;
  final realHubClock = core.sensors.now;
  core.sensors.now = _now;
  final broadcast = core.connection.broadcast = BroadcastController(
    hub: core.sensors,
    settings: core.settings,
    isBridgeRunning: ftmsEmulator.isStarted,
    isStandaloneRunning: () => true,
    connectSource: core.connection.connectSourceById,
    disconnectSource: core.connection.disconnectSourceById,
  )..start();
  // The hub ages its readings once a second, as the app's own timer does.
  final hubTick = Timer.periodic(const Duration(seconds: 1), (_) => core.sensors.tick());
  // The watch/AirPods feed: one sample a second.
  const bpm = [128, 129, 131, 132, 132, 134, 135, 133, 134, 136, 137, 136];
  var beat = 0;
  final heart = Timer.periodic(const Duration(seconds: 1), (_) {
    if (channel.startCalls > 0) channel.emitSample(bpm[beat++ % bpm.length], at: _now());
  });
  final l10n = AppLocalizations.current;

  final boundary = GlobalKey();
  final rec = await _roll(tester, boundary, () => const SensorsPage());
  await rec.frames(_endHold);

  Finder inHeart(String key) =>
      find.descendant(of: find.byKey(const Key('metric-card-heartRate')), matching: find.byKey(Key(key)));
  await rec.tap(inHeart('metric-card-source-picker'), 'Heart rate source');
  await rec.tap(find.byKey(const Key('metric-card-source-option-healthkit')).hitTestable().last,
      'Heart rate from Apple Health', thenFrames: 45);
  expect(core.sensors.selectionFor(SensorQuantity.heartRate), 'healthkit');
  await rec.tap(find.byKey(const Key('sensors-transport-network')), 'Share over Network', thenFrames: 30);
  await rec.tap(find.byKey(const Key('sensors-broadcast-switch')), 'Share sensors', thenFrames: 0);
  await driveUntil(tester, Future.doWhile(() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return !(core.connection.broadcast!.isOn.value);
  }), 'sharing should have come up');
  expect(channel.startCalls, greaterThan(0), reason: 'HealthKit is streaming');
  expect(find.text(l10n.sensorsBroadcastLive), findsOneWidget);
  // ~7 s of the reading ticking on the HEART tile, once a second.
  final shown = <String>{};
  for (var i = 0; i < 7; i++) {
    await rec.frames(30);
    final digits = find.descendant(
      of: find.byKey(const Key('metric-card-heartRate')),
      matching: find.byWidgetPredicate((w) => w is Text && RegExp(r'^\d{2,3}$').hasMatch(w.data ?? '')),
    );
    expect(digits, findsOneWidget, reason: 'the HEART tile shows a live reading');
    shown.add((tester.widget<Text>(digits)).data!);
  }
  expect(shown.length, greaterThanOrEqualTo(4), reason: 'the reading ticks: $shown');

  heart.cancel();
  hubTick.cancel();
  await driveUntil(tester, broadcast.turnOff(), 'sharing should have stopped');
  await driveUntil(tester, core.connection.disconnectHealthKit(forget: true), 'HealthKit should have stopped');
  core.sensors.select(SensorQuantity.heartRate, null);
  broadcast.dispose();
  core.connection.broadcast = null;
  core.connection.healthKitSource = realSource;
  core.sensors.now = realHubClock;
  await _wrapUp(tester, studio);
  return rec.capture;
}

// ── Base: workout intensity ───────────────────────────────────────────────

/// Base, not Pro: a controller button sends the trainer app's OWN intensity
/// command. MyWhoosh has none BikeControl can send (its OpenBikeControl set
/// has shifting, steering and navigation, no difficulty), so the clip uses
/// Tacx Training, whose keymap puts its own "Increase Difficulty" shortcut
/// (↑) on the Ride's D-pad up. The home screen's controller card shows the
/// Ride's contour with Tacx Training's badges; the press sends ↑ to Tacx
/// Training through local control (recorded, not performed). No trainer is
/// bridged: nothing of BikeControl's own trainer control is on screen.
Future<VideoCapture> _filmBaseIntensity(WidgetTester tester, _Studio studio) async {
  await _resetApp();
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  core.settings.setTrainerApp(Tacx());
  await core.settings.setKeyMap(Tacx());
  core.settings.setLastTarget(Target.thisDevice);
  core.settings.setLocalEnabled(true);
  final ride = _stageRide();
  core.actionHandler = DesktopActions()..init(core.settings.getTrainerApp());
  studio.output.performed.clear();
  final forward = forwardPresses(ride);
  final keyPair = core.actionHandler.supportedApp!.keymap.getKeyPair(ZwiftButtons.navigationUp);
  expect(keyPair?.inGameAction, InGameAction.increaseResistance, reason: "D-pad up is Tacx Training's own difficulty up");

  final boundary = GlobalKey();
  final rec = await _roll(tester, boundary, () => const Navigation(), svgAssets: [ride.controllerLayout.svgAsset!]);
  // ~1.5 s to take in the mapping, then two presses, each held to read.
  await rec.frames(45);
  for (final label in ['', ' again']) {
    await rec.hardwarePress(ride, RideButtonMask.UP_BTN, ZwiftButtons.navigationUp,
        'Ride D-pad up → ${InGameAction.increaseResistance.title} (Tacx Training)$label');
    await rec.frames(45);
  }
  expect(studio.output.performed, ['key down Arrow Up', 'key up Arrow Up', 'key down Arrow Up', 'key up Arrow Up'],
      reason: "each press sends Tacx Training's own shortcut");
  unawaited(forward.cancel());
  await _wrapUp(tester, studio);
  return rec.capture;
}

// ── The scenes ────────────────────────────────────────────────────────────

final _scenes = <_Scene>[
  _Scene(id: 'feature-steering', loops: true, film: _filmSteering, check: _checkSteering),
  _Scene(id: 'feature-full-control', loops: false, film: _filmFullControl, check: _checkPresses),
  _Scene(id: 'feature-customizability', loops: true, film: _filmCustomizability, check: _checkPresses),
  _Scene(id: 'feature-button-gestures', loops: false, film: _filmGestures, check: _checkPresses),
  _Scene(id: 'feature-music', loops: false, film: _filmMusic, check: _checkPresses),
  _Scene(id: 'feature-companion-mode', loops: true, film: _filmCompanion, check: _checkTaps),
  _Scene(id: 'feature-android-control', loops: false, film: _filmAndroidControl, check: _checkPresses),
  _Scene(id: 'feature-hands-free-steering', loops: false, film: _filmHandsFreeSteering, check: _checkSteering),
  _Scene(id: 'feature-overlay', loops: true, film: _filmOverlaySettings, check: _checkTaps),
  _Scene(
    id: 'feature-overlay-view',
    loops: false,
    film: _filmOverlayView,
    check: _checkOverlayView,
    logicalSize: _overlayViewSize,
    settles: false,
    unsettled: {'Ride: shift up again', 'Ride: shift down'},
  ),
  _Scene(
    id: 'feature-mini-workout',
    loops: false,
    film: _filmMiniWorkout,
    check: _checkTaps,
    unsettled: {'Stop'},
  ),
  _Scene(id: 'feature-setting-profiles', loops: true, film: _filmSettingProfiles, check: _checkTaps),
  _Scene(
    id: 'feature-heart-rate',
    loops: false,
    film: _filmHeartRate,
    check: (_) {},
    settles: false,
  ),
  _Scene(id: 'feature-base-intensity', loops: true, film: _filmBaseIntensity, check: _checkPresses),
  _Scene(id: 'feature-screenshots', loops: false, film: _filmScreenRecording, check: _checkPresses),
  _Scene(id: 'feature-launch-command', loops: false, film: _filmLaunchCommand, check: _checkPresses),
];

/// Every tap on film visibly reacts.
void _checkTaps(VideoCapture c) {
  for (final t in c.taps.where((t) => t.kind == 'tap')) {
    expect(reactingFrames(c, t, holdFrames: 3), greaterThan(1), reason: '"${t.label}" should visibly react on film');
  }
}

/// Every controller press on film visibly reacts.
void _checkPresses(VideoCapture c) {
  for (final t in c.taps.where((t) => t.kind == 'hardware')) {
    expect(reactingFrames(c, t), greaterThan(3), reason: '"${t.label}" should visibly react on film');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Studio studio;

  setUpAll(() async {
    await ensureSnapshotAppState();
    rememberPristinePrefs();
    studio = _Studio(OfflineMachine.install(), FakeSensorsPlatform.install());
    studio.output.install();
  });

  setUp(() {
    screenshotMode = true;
    debugAnimatesInScreenshotMode = true;
    debugKeepsControllerNamesInScreenshotMode = true;
    debugShowsRealKeymapsInScreenshotMode = true;
    activityLogClock = _now;
    addTearDown(() {
      debugAnimatesInScreenshotMode = false;
      debugKeepsControllerNamesInScreenshotMode = false;
      debugShowsRealKeymapsInScreenshotMode = false;
      debugHideMiniWorkoutCard = false;
      debugHostPlatformOverride = null;
      debugDefaultTargetPlatformOverride = null;
      activityLogClock = DateTime.now;
      IAPManager.instance.setProForTesting(enabled: false);
    });
  });

  for (final scene in _scenes) {
    testWidgets('films ${scene.id}', (tester) async {
      final watch = Stopwatch()..start();
      _lastRecorder = null;
      final failed = Directory('build/video_frames/${scene.id}-failed');
      if (failed.existsSync()) failed.deleteSync(recursive: true);
      final VideoCapture capture;
      try {
        capture = await scene.film(tester, studio);
      } catch (e) {
        // What was filmed up to the failure, to look at.
        final partial = _lastRecorder?.capture;
        if (partial != null && partial.frames.isNotEmpty) writeScene('${scene.id}-failed', partial);
        rethrow;
      }
      watch.stop();
      writeScene(scene.id, capture, extra: {'feature': scene.id, 'loops': scene.loops}, logicalSize: scene.logicalSize);
      expectWellFormed(capture,
          unsettledTaps: scene.unsettled, settledCuts: scene.settles, logicalSize: scene.logicalSize);
      final info = jsonDecode(File('build/video_frames/${scene.id}/scene.json').readAsStringSync()) as Map;
      expect(info['feature'], scene.id);
      expect(info['loops'], scene.loops);
      // Held still at either end, and a looping clip ends where it began.
      expect(capture.taps.first.frame, greaterThanOrEqualTo(_endHold), reason: 'hold the opening');
      expect(capture.frames.length - 1 - capture.taps.last.frame, greaterThanOrEqualTo(_endHold),
          reason: 'hold the ending');
      if (scene.loops) {
        expect(sha256.convert(capture.frames.last), sha256.convert(capture.frames.first),
            reason: 'a looping clip ends on its first frame');
      }
      scene.check(capture);
      reportCapture(scene.id, capture, watch.elapsed);
    });

    testWidgets('two ${scene.id} takes are byte-identical, frame for frame', (tester) async {
      final a = await scene.film(tester, studio);
      final b = await scene.film(tester, studio);
      expectIdentical(scene.id, a, b);
    });
  }
}
