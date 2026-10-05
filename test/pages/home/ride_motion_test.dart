// Ride while things connect. Right after launch the remembered trainer and
// controllers stand in as placeholders with their live cards' footprint, so
// when they connect the content swaps in place — nothing below moves. Every
// swap animates (a crossfade, rows growing in and out) and every one is
// instant under reduced motion.
//
// Runs on the fake clock, so a frame part-way through an animation is the
// same frame on every machine.
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_play.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/models/remembered_device.dart';
import 'package:bike_control/pages/home/home_page.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/widgets/home/ready_banner.dart';
import 'package:bike_control/widgets/home/your_buttons.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart' show loadAppFonts;
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/transporter/network_transporter.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../widget_snapshot.dart';

const _trainerId = 'motion-kickr';

ProxyDevice _trainer() =>
    ProxyDevice(
        BleDevice(
          name: 'KICKR CORE',
          deviceId: _trainerId,
          services: [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
        ),
      )
      ..services = [BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [])]
      ..isConnected = true;

/// Bridges [proxy]: a definition attached, the trainer app holding it.
void _bridge(ProxyDevice proxy) {
  final definition = FitnessBikeDefinition(
    connectedDevice: proxy.scanResult,
    connectedDeviceServices: proxy.services!,
    data: ValueNotifier(''),
  )..setDebugValues();
  proxy.emulator.debugSetTransporter(NetworkTransporter(definition: definition));
  proxy.debugSetTrainerAppConnected(true);
  proxy.debugAttachFitnessBike(definition);
  addTearDown(() {
    proxy.debugAttachFitnessBike(null);
    proxy.debugSetTrainerAppConnected(false);
  });
}

ZwiftPlay _play(String id) => ZwiftPlay(
  BleDevice(name: 'Zwift Play', deviceId: id),
  deviceType: ZwiftDeviceType.playLeft,
)..batteryLevel = 81;

/// Remembers a trainer from an earlier session, on auto-connect.
Future<void> _rememberTrainer() async {
  core.connection.rememberedTrainer = RememberedDevice(
    deviceId: _trainerId,
    name: 'KICKR CORE',
    kind: RememberedDeviceKind.trainer,
    lastConnected: DateTime(2026, 10, 4),
  );
  await core.settings.setAutoConnect('KICKR CORE', true);
}

Future<void> _pumpRide(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  bool reduce = false,
  HomeView view = HomeView.ride,
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
      theme: BkTheme.build(Brightness.dark),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
          child: Scaffold(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: HomePage(isMobile: true, view: view, onUpdate: () {}),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Tells Ride a device changed, as the connection stream would.
Future<void> _signal(WidgetTester tester, dynamic device) async {
  core.connection.signalChange(device);
  await tester.pump();
}

/// Closes the launch window before the test ends: its timer must not
/// outlive the test.
void _closeWindow() => core.connection.endStartupReconnect();

double _yourButtonsTop(WidgetTester tester) =>
    tester.getTopLeft(find.text(AppLocalizations.current.rideYourButtons)).dy;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await ensureSnapshotAppState();
    await loadAppFonts();
  });
  late AppLocalizations l;

  setUp(() {
    l = AppLocalizations.current;
    core.appConnectionLatch.reset();
    core.settings.setTrainerApp(MyWhoosh());
    core.settings.setKeyMap(MyWhoosh());
    core.actionHandler.init(MyWhoosh());
  });

  tearDown(() {
    core.connection.endStartupReconnect();
    core.connection.debugForgetOfflineControllers();
    core.connection.rememberedTrainer = null;
    core.connection.devices.clear();
  });

  group('startup placeholders', () {
    testWidgets('the remembered trainer and controller stand in, named, "Connecting…"', (tester) async {
      await _rememberTrainer();
      core.connection.debugRememberController(_play('motion-play'));
      core.connection.beginStartupReconnect();
      await _pumpRide(tester);

      final placeholder = find.byKey(const ValueKey('ride-vs-placeholder'));
      expect(placeholder, findsOneWidget);
      expect(find.descendant(of: placeholder, matching: find.textContaining('KICKR CORE')), findsOneWidget);
      expect(find.descendant(of: placeholder, matching: find.textContaining(l.chainStatusConnecting)), findsOneWidget);

      final buttons = find.byKey(const ValueKey('ride-buttons-motion-play'));
      expect(buttons, findsOneWidget);
      expect(find.descendant(of: buttons, matching: find.textContaining('Zwift Play')), findsOneWidget);
      expect(find.descendant(of: buttons, matching: find.textContaining(l.chainStatusConnecting)), findsOneWidget);
      expect(find.text(l.rideNoControllerTitle), findsNothing);
      _closeWindow();
    });

    testWidgets('the banner holds back the steps of devices on their way back', (tester) async {
      core.connection.debugRememberController(_play('motion-play'));
      core.connection.beginStartupReconnect(window: const Duration(seconds: 5));
      await _pumpRide(tester);
      ReadyBanner banner() => tester.widget<ReadyBanner>(find.byType(ReadyBanner));
      expect(banner().steps.where((s) => s.linkId.contains('motion-play')), isEmpty);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(
        banner().steps.where((s) => s.linkId.contains('motion-play')),
        isNotEmpty,
        reason: 'still away once the window is over: its step is news again',
      );
    });

    testWidgets('Devices: the remembered rows read "Connecting…" while they are on their way', (tester) async {
      await _rememberTrainer();
      core.connection.debugRememberController(_play('motion-play'));
      core.connection.beginStartupReconnect(window: const Duration(seconds: 5));
      await _pumpRide(tester, view: HomeView.setup);
      expect(find.text(l.chainStatusConnecting), findsNWidgets(2));
      expect(find.text(l.chainStatusOutOfRange), findsNothing);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text(l.chainStatusConnecting), findsNothing);
    });

    testWidgets('the window runs out: back to the plain not-connected states', (tester) async {
      await _rememberTrainer();
      core.connection.debugRememberController(_play('motion-play'));
      core.connection.beginStartupReconnect(window: const Duration(seconds: 5));
      await _pumpRide(tester);
      expect(find.byKey(const ValueKey('ride-vs-placeholder')), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ride-vs-placeholder')), findsNothing);
      expect(find.byKey(const ValueKey('ride-buttons-motion-play')), findsNothing);
      expect(find.text(l.rideNoControllerTitle), findsOneWidget);
      _closeWindow();
    });

    testWidgets('the placeholder trainer card has the live card\'s footprint', (tester) async {
      await _rememberTrainer();
      core.connection.beginStartupReconnect();
      await _pumpRide(tester);
      final slot = find.byKey(const ValueKey('ride-vs-slot'));
      final placeholder = tester.getSize(slot);
      // Measured from the card, not the screen: the banner above it has its
      // own news when a trainer arrives (and animates it).
      final buttonsBefore = _yourButtonsTop(tester) - tester.getRect(slot).bottom;

      final proxy = _trainer();
      core.connection.devices.add(proxy);
      _bridge(proxy);
      await _signal(tester, proxy);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ride-vs-live')), findsOneWidget);
      final live = tester.getSize(slot);
      expect(live.height, moreOrLessEquals(placeholder.height, epsilon: 1));
      expect(
        _yourButtonsTop(tester) - tester.getRect(slot).bottom,
        moreOrLessEquals(buttonsBefore, epsilon: 1),
        reason: 'nothing below moves',
      );
      _closeWindow();
    });

    testWidgets('a controller that connects swaps in place: the section below does not move', (tester) async {
      final play = _play('motion-play');
      core.connection.debugRememberController(play);
      core.connection.beginStartupReconnect();
      await _pumpRide(tester);
      final card = find.byKey(const ValueKey('ride-buttons-motion-play'));
      final header = _yourButtonsTop(tester);
      final before = tester.getRect(card);

      play.isConnected = true;
      core.connection.devices.add(play);
      core.connection.noteReconnected(play.uniqueId);
      await _signal(tester, play);
      await tester.pumpAndSettle();

      expect(_yourButtonsTop(tester), header);
      expect(tester.getRect(card).top, moreOrLessEquals(before.top, epsilon: 0.5));
      expect(tester.getRect(card).height, moreOrLessEquals(before.height, epsilon: 0.5));
      expect(find.descendant(of: card, matching: find.textContaining(l.chainStatusConnecting)), findsNothing);
      _closeWindow();
    });
  });

  group('transitions', () {
    testWidgets('trainer placeholder → live card crossfades', (tester) async {
      await _rememberTrainer();
      core.connection.beginStartupReconnect();
      await _pumpRide(tester);

      final proxy = _trainer();
      core.connection.devices.add(proxy);
      _bridge(proxy);
      await _signal(tester, proxy);
      await tester.pump(const Duration(milliseconds: 80));

      expect(find.byKey(const ValueKey('ride-vs-placeholder')), findsOneWidget, reason: 'fading out');
      expect(find.byKey(const ValueKey('ride-vs-live')), findsOneWidget, reason: 'fading in');
      final fade = tester.widget<FadeTransition>(
        find.ancestor(of: find.byKey(const ValueKey('ride-vs-live')), matching: find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, inExclusiveRange(0, 1));

      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ride-vs-placeholder')), findsNothing);
      _closeWindow();
    });

    testWidgets('no controller → a connected one: the prompt gives way, the card grows in', (tester) async {
      await _pumpRide(tester);
      expect(find.text(l.rideNoControllerTitle), findsOneWidget);
      final before = tester.getSize(find.byKey(const ValueKey('ride-your-buttons'))).height;

      final play = _play('motion-play')..isConnected = true;
      core.connection.devices.add(play);
      await _signal(tester, play);
      await tester.pump(const Duration(milliseconds: 60));
      final mid = tester.getSize(find.byKey(const ValueKey('ride-your-buttons'))).height;

      await tester.pumpAndSettle();
      final after = tester.getSize(find.byKey(const ValueKey('ride-your-buttons'))).height;
      expect(find.text(l.rideNoControllerTitle), findsNothing);
      expect(find.byType(ControllerButtonsCard), findsOneWidget);
      expect(mid, inExclusiveRange(before < after ? before : after, before < after ? after : before));
    });

    testWidgets('a second controller grows in under the first', (tester) async {
      final first = _play('motion-play')..isConnected = true;
      core.connection.devices.add(first);
      await _pumpRide(tester);
      final before = tester.getSize(find.byKey(const ValueKey('ride-your-buttons'))).height;

      final second = _play('motion-play-2')..isConnected = true;
      core.connection.devices.add(second);
      await _signal(tester, second);
      await tester.pump(const Duration(milliseconds: 60));
      final mid = tester.getSize(find.byKey(const ValueKey('ride-your-buttons'))).height;
      await tester.pumpAndSettle();
      final after = tester.getSize(find.byKey(const ValueKey('ride-your-buttons'))).height;

      expect(find.byType(ControllerButtonsCard), findsNWidgets(2));
      expect(mid, inExclusiveRange(before, after));
    });

    testWidgets('reduced motion: placeholder → live is instant', (tester) async {
      await _rememberTrainer();
      core.connection.beginStartupReconnect();
      await _pumpRide(tester, reduce: true);

      final proxy = _trainer();
      core.connection.devices.add(proxy);
      _bridge(proxy);
      await _signal(tester, proxy);
      await tester.pump();

      expect(find.byKey(const ValueKey('ride-vs-placeholder')), findsNothing);
      expect(find.byKey(const ValueKey('ride-vs-live')), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      _closeWindow();
    });

    testWidgets('reduced motion: a controller arriving is instant', (tester) async {
      await _pumpRide(tester, reduce: true);
      final play = _play('motion-play')..isConnected = true;
      core.connection.devices.add(play);
      await _signal(tester, play);
      await tester.pump();
      expect(find.text(l.rideNoControllerTitle), findsNothing);
      expect(find.byType(ControllerButtonsCard), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
