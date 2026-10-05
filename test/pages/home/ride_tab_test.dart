// The Ride tab: the ready banner, the virtual shifting card and "Your
// buttons". The setup chain's cards live on Devices now (HomeView.setup); Ride
// keeps the banner that points at them.
import 'package:bike_control/widgets/drivetrain/drivetrain_view.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_play.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, screenshotMode;
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/pages/home/home_page.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/services/workout/trainer_metrics.dart';
import 'package:bike_control/widgets/rides/ride_recording_line.dart';
import 'package:bike_control/pages/settings/overlay_settings_page.dart';
import 'package:bike_control/pages/settings/virtual_shifting_settings_page.dart';
import 'package:bike_control/pages/shell/app_shell.dart' show ShellTabBar;
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:bike_control/utils/requirements/multi.dart' show Target;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/widgets/home/chain_card.dart';
import 'package:bike_control/widgets/home/virtual_shifting_card.dart';
import 'package:bike_control/widgets/home/your_buttons.dart' show ControllerButtonsCard, LastPressStrip;
import 'package:bike_control/widgets/ui/animated_button_widget.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show StandardMessageCodec;
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart' show loadAppFonts;
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/transporter/network_transporter.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../helpers/fake_overlay_controller.dart';
import '../../helpers/ride_rig.dart';
import '../../helpers/shell_harness.dart';
import '../../helpers/touch_targets.dart';
import '../../widget_snapshot.dart';

/// A bridged smart trainer reporting 250 W at 90 rpm, in gear 12 of 24.
({ProxyDevice proxy, FitnessBikeDefinition definition}) liveTrainer() {
  final proxy =
      ProxyDevice(
          BleDevice(
            name: 'KICKR CORE',
            deviceId: 'ride-tab-kickr',
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
  proxy.debugSetTrainerAppConnected(true);
  proxy.debugAttachFitnessBike(definition);
  core.connection.devices.add(proxy);
  addTearDown(() {
    proxy.debugAttachFitnessBike(null);
    proxy.debugSetTrainerAppConnected(false);
  });
  return (proxy: proxy, definition: definition);
}

ZwiftPlay connectedPlay() {
  final play =
      ZwiftPlay(
          BleDevice(name: 'Zwift Play', deviceId: 'ride-tab-play'),
          deviceType: ZwiftDeviceType.playLeft,
        )
        ..isConnected = true
        ..batteryLevel = 81;
  core.connection.devices.add(play);
  core.actionHandler.init(MyWhoosh());
  return play;
}

Future<void> pumpRide(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  List<NavigatorObserver> observers = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ShadcnApp(
      localizationsDelegates: [
        ...ShadcnLocalizations.localizationsDelegates,
        const OtherLocalizationsDelegate(),
        AppLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      navigatorObservers: observers,
      theme: BkTheme.build(Brightness.dark),
      home: Scaffold(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: HomePage(isMobile: true, onUpdate: () {}),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> main() async {
  await ensureSnapshotHarness();
  // Real font metrics: the fallback test font draws every glyph as a wide
  // box, which would push a one-row offer onto many rows and the first-screen
  // checks below off the screen.
  setUpAll(loadAppFonts);
  late AppLocalizations l;

  setUp(() {
    l = AppLocalizations.current;
    core.appConnectionLatch.reset();
    core.settings.setTrainerApp(MyWhoosh());
    core.settings.setKeyMap(MyWhoosh());
  });

  tearDown(() {
    core.connection.devices.clear();
  });

  group('virtual shifting card', () {
    testWidgets('shows the gear, the gear count and the live numbers', (tester) async {
      liveTrainer();
      await pumpRide(tester);

      expect(find.byType(VirtualShiftingCard), findsOneWidget);
      final card = find.byType(VirtualShiftingCard);
      expect(find.descendant(of: card, matching: find.text(l.rideVirtualShifting)), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('12')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(l.gearOfMax('24'))), findsOneWidget);
      expect(find.descendant(of: card, matching: find.textContaining('250', findRichText: true)), findsOneWidget);
      expect(find.descendant(of: card, matching: find.textContaining('90', findRichText: true)), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(l.rideRatio)), findsOneWidget);
      // SIM is the mode on screen.
      expect(find.descendant(of: card, matching: find.text(l.simMode)), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(l.ergMode)), findsOneWidget);
    });

    testWidgets('SIM | ERG switches the trainer, like the Switch ERG/SIM button action', (tester) async {
      final (:proxy, :definition) = liveTrainer();
      await pumpRide(tester);
      final handle = tester.ensureSemantics();

      final erg = find.bySemanticsLabel(l.ergMode);
      final sim = find.bySemanticsLabel(l.simMode);
      expect(tester.getSemantics(sim).flagsCollection.isSelected, Tristate.isTrue);
      expect(tester.getSemantics(erg).flagsCollection.isSelected, Tristate.isFalse);
      expect(tester.getSemantics(erg).flagsCollection.isButton, isTrue);
      expect(tester.getSize(erg).height, greaterThanOrEqualTo(48));

      await tester.tap(erg);
      await tester.pump();
      expect(definition.trainerMode.value, TrainerMode.ergMode);
      expect(definition.ergTargetPower.value, isNotNull);
      expect(tester.getSemantics(find.bySemanticsLabel(l.ergMode)).flagsCollection.isSelected, Tristate.isTrue);

      await tester.tap(find.bySemanticsLabel(l.simMode));
      await tester.pump();
      expect(definition.trainerMode.value, TrainerMode.simMode);
      handle.dispose();
    });

    testWidgets('+ and − shift the trainer, like the old drivetrain buttons', (tester) async {
      final (:proxy, :definition) = liveTrainer();
      await pumpRide(tester);

      await tester.tap(find.bySemanticsLabel(l.actionShiftUp));
      await tester.pump();
      expect(definition.currentGear.value, 13);
      expect(find.descendant(of: find.byType(VirtualShiftingCard), matching: find.text('13')), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(l.actionShiftDown));
      await tester.tap(find.bySemanticsLabel(l.actionShiftDown));
      await tester.pump();
      expect(definition.currentGear.value, 11);
    });

    testWidgets('the shift buttons are at least 48 dp', (tester) async {
      liveTrainer();
      await pumpRide(tester);
      for (final label in [l.actionShiftUp, l.actionShiftDown]) {
        final size = tester.getSize(find.bySemanticsLabel(label));
        expect(size.width, greaterThanOrEqualTo(48), reason: label);
        expect(size.height, greaterThanOrEqualTo(48), reason: label);
      }
    });

    testWidgets('in ERG the big number is the target power, and ± steps it', (tester) async {
      final (:proxy, :definition) = liveTrainer();
      definition.setManualErgPower(200);
      await pumpRide(tester);

      final card = find.byType(VirtualShiftingCard);
      expect(find.descendant(of: card, matching: find.text('200')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(l.gearOfMax('24'))), findsNothing);

      await tester.tap(find.bySemanticsLabel(l.a11yIncrease));
      await tester.pump();
      expect(definition.ergTargetPower.value, 205);
      expect(find.descendant(of: card, matching: find.text('205')), findsOneWidget);
    });

    testWidgets('"Virtual shifting ›" opens Settings → Virtual shifting', (tester) async {
      liveTrainer();
      await pumpRide(tester);

      await tester.tap(find.byKey(const ValueKey('ride-vs-settings-link')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(VirtualShiftingSettingsPage), findsOneWidget);
    });

    testWidgets('a settings line sums up virtual shifting and opens its settings', (tester) async {
      final (:proxy, :definition) = liveTrainer();
      await pumpRide(tester);

      final line = find.byKey(const ValueKey('ride-vs-settings-line'));
      expect(line, findsOneWidget);
      expect(find.descendant(of: find.byType(VirtualShiftingCard), matching: line), findsOneWidget);
      expect(find.descendant(of: line, matching: find.textContaining(l.gearsCount(24))), findsOneWidget);
      expect(tester.getSize(line).height, greaterThanOrEqualTo(48));

      await tester.ensureVisible(line);
      await tester.pump();
      await tester.tap(line);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(VirtualShiftingSettingsPage), findsOneWidget);
    });

    testWidgets('the trainer name opens the trainer page', (tester) async {
      liveTrainer();
      await pumpRide(tester);

      await tester.tap(find.descendant(of: find.byType(VirtualShiftingCard), matching: find.text('KICKR CORE')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ProxyDeviceDetailsPage), findsOneWidget);
    });

    testWidgets('the two header links are separate 48 dp touch targets', (tester) async {
      liveTrainer();
      await pumpRide(tester);

      final settingsLink = find.byKey(const ValueKey('ride-vs-settings-link'));
      final trainerLink = find.byKey(const ValueKey('ride-vs-trainer-link'));
      expect(targetsBelowAndroidMinimum(tester, [settingsLink, trainerLink]), isEmpty);
      final settings = tester.getRect(settingsLink);
      final trainer = tester.getRect(trainerLink);
      expect(settings.bottom, lessThanOrEqualTo(trainer.top), reason: 'no overlap');
    });

    testWidgets('the taller targets barely move the header: the two lines stay close together', (tester) async {
      liveTrainer();
      await pumpRide(tester);

      final card = tester.getRect(find.byType(VirtualShiftingCard));
      final title = tester.getRect(
        find.descendant(
          of: find.byKey(const ValueKey('ride-vs-settings-link')),
          matching: find.text(l.rideVirtualShifting),
        ),
      );
      final trainer = tester.getRect(
        find.descendant(of: find.byKey(const ValueKey('ride-vs-trainer-link')), matching: find.text('KICKR CORE')),
      );
      expect(title.top - card.top, lessThanOrEqualTo(24), reason: 'the title keeps its place at the top of the card');
      expect(trainer.top - title.bottom, lessThanOrEqualTo(12), reason: 'the trainer name sits right under the title');
    });

    testWidgets('no speed and no chip strip on Ride: an indoor trainer has nowhere to go', (tester) async {
      final (:proxy, :definition) = liveTrainer();
      definition.setExternalHeartRate(142);
      await pumpRide(tester);
      expect(find.byKey(const ValueKey('ride-live-chips')), findsNothing);
      expect(find.byKey(const ValueKey('ride-chip-speed')), findsNothing);
      expect(find.byKey(const ValueKey('ride-chip-heart')), findsNothing);
      expect(find.text(l.sensorQuantitySpeed), findsNothing);
    });

    testWidgets('heart rate joins the card\'s readings only while a source reports one', (tester) async {
      final (:proxy, :definition) = liveTrainer();
      await pumpRide(tester);
      final card = find.byType(VirtualShiftingCard);
      Finder heartLabel() => find.descendant(of: card, matching: find.text(l.sensorQuantityHeartRate));
      expect(heartLabel(), findsNothing, reason: 'no heart-rate source');

      definition.setExternalHeartRate(0);
      await tester.pump();
      expect(heartLabel(), findsNothing, reason: 'never a 0 bpm reading');

      definition.setExternalHeartRate(142);
      await tester.pump();
      expect(heartLabel(), findsOneWidget);
      final reading = find.byKey(const ValueKey('ride-stat-heart'));
      expect(find.descendant(of: reading, matching: find.textContaining('142', findRichText: true)), findsOneWidget);
      expect(find.descendant(of: reading, matching: find.textContaining('bpm', findRichText: true)), findsOneWidget);
      // One row with power, cadence and the ratio.
      final power = tester.getRect(find.descendant(of: card, matching: find.text(l.sensorQuantityPower)));
      expect((tester.getRect(heartLabel()).top - power.top).abs(), lessThan(1), reason: 'the same metrics row');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a recording ride shows its status line right under Virtual shifting', (tester) async {
      final (proxy: _, :definition) = liveTrainer();
      connectedPlay();
      RideRig.reset();
      RideRig.source = TrainerMetrics.fromDefinition(definition)!.named('KICKR CORE');
      final rig = await RideRig.install();
      await pumpRide(tester);
      expect(find.byType(RideRecordingLine), findsNothing, reason: 'automatic and idle: nothing to show');

      rig.service.startManual();
      await tester.pump();
      final line = find.byType(RideRecordingLine);
      expect(line, findsOneWidget);
      final vs = tester.getRect(find.byType(VirtualShiftingCard));
      expect(tester.getTopLeft(line).dy, closeTo(vs.bottom + 12, 1));
      expect(tester.getTopLeft(line).dy, lessThan(tester.getTopLeft(find.text(l.rideYourButtons.toUpperCase())).dy));
      expect(find.text(l.miniWorkout.toUpperCase()), findsNothing, reason: 'the old record card is gone');

      rig.service.discard();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('automatic recording off: the manual start takes the same slot', (tester) async {
      final (proxy: _, :definition) = liveTrainer();
      RideRig.reset();
      RideRig.source = TrainerMetrics.fromDefinition(definition);
      await RideRig.install(prefs: {'rides_auto_record': false});
      await pumpRide(tester);

      final start = find.text(l.miniWorkoutStart);
      expect(start, findsOneWidget);
      final vs = tester.getRect(find.byType(VirtualShiftingCard));
      expect(tester.getTopLeft(find.byType(RideManualStartCard)).dy, closeTo(vs.bottom + 12, 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('without a trainer, Ride invites the rider to connect one', (tester) async {
      await pumpRide(tester);

      expect(find.byType(VirtualShiftingCard), findsNothing);
      expect(find.text(l.rideVsInviteBody), findsOneWidget);
    });
  });

  group('overlay offer', () {
    late FakeOverlayController overlay;

    setUp(() async {
      // Store renders never carry an open offer; this is the real app.
      screenshotMode = false;
      addTearDown(() => screenshotMode = true);
      overlay = FakeOverlayController();
      TrainerOverlayService.setForTest(overlay);
      TrainerOverlayService.debugSupportedPlatform = true;
      await core.settings.setLastTarget(Target.thisDevice);
      await core.settings.setOverlayEnabled(false);
      await core.settings.setOverlayDeclined(false);
    });

    tearDown(() {
      TrainerOverlayService.resetForTest();
      TrainerOverlayService.debugSupportedPlatform = null;
    });

    Finder inCard(Finder f) => find.descendant(of: find.byType(VirtualShiftingCard), matching: f);

    Finder notNow() => find.bySemanticsLabel(l.chainStepOverlayDecline);

    testWidgets('off: one short line, "Show overlay" and a "Not now" close button', (tester) async {
      liveTrainer();
      await pumpRide(tester);

      expect(inCard(find.text(l.rideOverlayOfferNote('MyWhoosh'))), findsOneWidget);
      expect(inCard(find.text(l.rideOverlayOfferShow)), findsOneWidget);
      expect(notNow(), findsOneWidget);
    });

    testWidgets('off: the offer is one compact row with 48 dp targets', (tester) async {
      liveTrainer();
      await pumpRide(tester);

      final offer = find.byKey(const ValueKey('ride-overlay-offer'));
      // One row: the old note-over-buttons stack stood over 200 tall. (The
      // phone-scaled shell below pins the two-line height.)
      expect(
        tester.getSize(offer).height,
        lessThanOrEqualTo(72),
        reason: 'one row, not a paragraph and a button stack',
      );
      final note = tester.getRect(inCard(find.text(l.rideOverlayOfferNote('MyWhoosh'))));
      final show = tester.getRect(find.byKey(const ValueKey('ride-overlay-show')));
      final close = tester.getRect(notNow());
      expect(show.left, greaterThan(note.left), reason: 'the button trails the text');
      expect(close.left, greaterThanOrEqualTo(show.right), reason: 'the close button trails the button');
      expect((show.center.dy - close.center.dy).abs(), lessThan(2), reason: 'on the same row');
      expect(
        targetsBelowAndroidMinimum(tester, [find.byKey(const ValueKey('ride-overlay-show')), notNow()]),
        isEmpty,
      );
    });

    testWidgets('"Show overlay" turns it on and the notice becomes one line', (tester) async {
      liveTrainer();
      await pumpRide(tester);

      // The banner above lists what setup still needs; the card is below it.
      await tester.ensureVisible(inCard(find.text(l.rideOverlayOfferShow)));
      await tester.pump();
      await tester.tap(inCard(find.text(l.rideOverlayOfferShow)));
      await tester.pump();
      await tester.pump();
      expect(overlay.shows, 1);
      expect(core.settings.getOverlayEnabled(), isTrue);
      expect(inCard(find.text(l.chainStepOverlayDone)), findsOneWidget);
      expect(inCard(find.text(l.rideOverlayOfferShow)), findsNothing);
    });

    testWidgets('"Not now" leaves one quiet line that opens the Overlay page', (tester) async {
      liveTrainer();
      await pumpRide(tester);

      await tester.ensureVisible(notNow());
      await tester.pump();
      await tester.tap(notNow());
      await tester.pump();
      await tester.pump();
      expect(core.settings.getOverlayDeclined(), isTrue);
      expect(inCard(find.text(l.rideOverlayOfferNote('MyWhoosh'))), findsNothing);
      expect(inCard(find.text(l.rideOverlayOff)), findsOneWidget);

      await tester.tap(inCard(find.text(l.rideOverlayOff)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(OverlaySettingsPage), findsOneWidget);
    });

    testWidgets('on: "Gear overlay is on · Overlay ›"', (tester) async {
      await core.settings.setOverlayEnabled(true);
      liveTrainer();
      await pumpRide(tester);

      expect(inCard(find.text(l.chainStepOverlayDone)), findsOneWidget);
      expect(inCard(find.text(l.overlaySection)), findsOneWidget);
    });

    testWidgets('not offered where the trainer app is on another device', (tester) async {
      await core.settings.setLastTarget(Target.otherDevice);
      liveTrainer();
      await pumpRide(tester);

      expect(inCard(find.text(l.rideOverlayOfferShow)), findsNothing);
      expect(inCard(find.text(l.rideOverlayOff)), findsNothing);
      expect(inCard(find.text(l.chainStepOverlayDone)), findsNothing);
    });
  });

  group('your buttons', () {
    testWidgets('shows the controller with its action badges and the hint', (tester) async {
      final play = connectedPlay();
      await pumpRide(tester);

      expect(find.text(l.rideYourButtons.toUpperCase()), findsOneWidget);
      expect(find.text(l.rideEditButtons), findsOneWidget);
      expect(find.text(l.rideTapButtonHint), findsOneWidget);
      expect(find.byType(AnimatedButtonWidget), findsNWidgets(play.availableButtons.length));
      // Ride is not the setup chain.
      expect(find.byType(ChainCard), findsNothing);
    });

    testWidgets('"Edit buttons" opens the controller page', (tester) async {
      connectedPlay();
      await pumpRide(tester);

      await tester.tap(find.text(l.rideEditButtons));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ControllerSettingsPage), findsOneWidget);
    });

    testWidgets('a press shows up on the last-press strip', (tester) async {
      final play = connectedPlay();
      await pumpRide(tester);
      final button = play.availableButtons.first;
      expect(find.text(l.rideJustPressed(button.displayName), findRichText: true), findsNothing);

      core.connection.signalNotification(ButtonNotification(device: play, buttonsClicked: [button]));
      await tester.pump();

      expect(
        find.textContaining(l.rideJustPressed(button.displayName), findRichText: true),
        findsOneWidget,
      );
      expect(find.text(l.rideChange), findsOneWidget);
    });

    testWidgets('without a controller, Ride invites the rider to pair one', (tester) async {
      await pumpRide(tester);
      expect(find.text(l.rideNoControllerTitle), findsOneWidget);
      expect(find.byType(AnimatedButtonWidget), findsNothing);
    });
  });

  group('layout', () {
    setUp(quietShellEnvironment);

    Future<void> pumpShellWithRide(WidgetTester tester, Size size) async {
      liveTrainer();
      connectedPlay();
      await pumpShell(tester, size);
    }

    Rect rectOf(WidgetTester tester, Finder finder) => tester.getRect(finder.first);

    testWidgets('phone: one column, the shifting card and the buttons both in the first screen', (tester) async {
      await pumpShellWithRide(tester, const Size(390, 844));
      expect(tester.takeException(), isNull);

      final vs = rectOf(tester, find.byType(VirtualShiftingCard));
      final buttons = rectOf(tester, find.text(l.rideYourButtons.toUpperCase()));
      expect(buttons.top, greaterThan(vs.bottom), reason: 'buttons sit under the shifting card');
      expect(buttons.bottom, lessThan(844), reason: 'the buttons header is in the first screen');
      await disposeShell(tester);
    });

    testWidgets('phone with the overlay offer open: "Your buttons" still in the first screen', (tester) async {
      screenshotMode = false;
      addTearDown(() => screenshotMode = true);
      TrainerOverlayService.setForTest(FakeOverlayController());
      TrainerOverlayService.debugSupportedPlatform = true;
      addTearDown(() {
        TrainerOverlayService.resetForTest();
        TrainerOverlayService.debugSupportedPlatform = null;
      });
      // With screenshotMode off Ride keeps the screen awake; no plugin here.
      const wakelock = 'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle';
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMessageHandler(
        wakelock,
        (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
      );
      addTearDown(() => messenger.setMockMessageHandler(wakelock, null));
      await core.settings.setLastTarget(Target.thisDevice);
      await core.settings.setOverlayEnabled(false);
      await core.settings.setOverlayDeclined(false);
      // Mid-ride, MyWhoosh receiving: the overlay is all that is left, so the
      // banner is one line. (Outstanding setup lists its steps and rightly
      // takes the room.)
      core.settings.setObpMdnsEnabled(true);
      core.obpMdnsEmulator.isStarted.value = true;
      core.obpMdnsEmulator.isConnected.value = true;
      addTearDown(() {
        core.obpMdnsEmulator.isConnected.value = false;
        core.obpMdnsEmulator.isStarted.value = false;
        core.settings.setObpMdnsEnabled(false);
      });
      await pumpShellWithRide(tester, const Size(390, 844));
      expect(tester.takeException(), isNull);
      final offer = find.byKey(const ValueKey('ride-overlay-offer'));
      expect(offer, findsOneWidget);
      expect(tester.getSize(offer).height, lessThanOrEqualTo(56), reason: 'at most two lines beside its buttons');

      final buttons = rectOf(tester, find.text(l.rideYourButtons.toUpperCase()));
      final tabBar = rectOf(tester, find.byType(ShellTabBar));
      expect(buttons.bottom, lessThanOrEqualTo(tabBar.top), reason: 'the buttons header clears the tab bar');
      await disposeShell(tester);
    });

    testWidgets('iPad portrait (820): one wide column, the gear still the largest thing', (tester) async {
      await pumpShellWithRide(tester, const Size(820, 1180));
      expect(tester.takeException(), isNull);

      final vs = rectOf(tester, find.byType(VirtualShiftingCard));
      final buttons = rectOf(tester, find.text(l.rideYourButtons.toUpperCase()));
      expect(buttons.top, greaterThan(vs.bottom), reason: 'one column below 840');
      final gear = tester.getSize(find.descendant(of: find.byType(VirtualShiftingCard), matching: find.text('12')));
      final picture = tester.getSize(
        find.descendant(of: find.byType(VirtualShiftingCard), matching: find.byType(DrivetrainView)),
      );
      expect(picture.height, lessThanOrEqualTo(gear.height * 1.3), reason: 'the drivetrain does not outgrow the gear');
      await disposeShell(tester);
    });

    testWidgets('1000 wide: shifting on the left, buttons on the right', (tester) async {
      await pumpShellWithRide(tester, const Size(1000, 800));
      expect(tester.takeException(), isNull);

      final vs = rectOf(tester, find.byType(VirtualShiftingCard));
      final buttons = rectOf(tester, find.text(l.rideYourButtons.toUpperCase()));
      expect(buttons.left, greaterThan(vs.right), reason: 'two columns');
      await disposeShell(tester);
    });

    for (final size in const [Size(1280, 800), Size(1000, 800)]) {
      testWidgets('${size.width.toInt()} wide: every button and its whole action listed with the pods', (
        tester,
      ) async {
        await pumpShellWithRide(tester, size);
        expect(tester.takeException(), isNull);

        final list = find.byKey(const ValueKey('ride-button-list'));
        expect(list, findsOneWidget);
        final play = core.connection.controllerDevices.single;
        for (final button in play.availableButtons) {
          expect(find.descendant(of: list, matching: find.text(button.displayName)), findsOneWidget);
        }
        final cut = find.descendant(of: list, matching: find.byType(RichText)).evaluate().where((e) {
          final paragraph = e.renderObject! as RenderParagraph;
          return paragraph.didExceedMaxLines;
        });
        expect(cut, isEmpty, reason: 'no name or action is cut off');
        await disposeShell(tester);
      });
    }

    for (final size in const [Size(1300, 800), Size(1440, 900)]) {
      testWidgets('${size.width.toInt()} wide: two columns like a tablet, the last press under the pods', (
        tester,
      ) async {
        await pumpShellWithRide(tester, size);
        expect(tester.takeException(), isNull);

        final vs = rectOf(tester, find.byType(VirtualShiftingCard));
        final buttons = rectOf(tester, find.text(l.rideYourButtons.toUpperCase()));
        expect(buttons.left, greaterThan(vs.right), reason: 'two columns');
        expect(find.byKey(const ValueKey('activity-column')), findsNothing);
        expect(
          find.descendant(of: find.byType(ControllerButtonsCard), matching: find.byType(LastPressStrip)),
          findsOneWidget,
          reason: 'no activity column lists the presses, so the strip stays',
        );
        await disposeShell(tester);
      });
    }
  });
}
