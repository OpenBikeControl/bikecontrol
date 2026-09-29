// The Ride tab: the ready banner, the virtual shifting card and "Your
// buttons". The setup chain's cards live on Devices now (HomeView.setup); Ride
// keeps the banner that points at them.
import 'package:bike_control/widgets/drivetrain/drivetrain_view.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_play.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/pages/home/home_page.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/widgets/home/chain_card.dart';
import 'package:bike_control/widgets/home/virtual_shifting_card.dart';
import 'package:bike_control/widgets/ui/animated_button_widget.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/transporter/network_transporter.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../helpers/shell_harness.dart';
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
  final play = ZwiftPlay(BleDevice(name: 'Zwift Play', deviceId: 'ride-tab-play'), deviceType: ZwiftDeviceType.playLeft)
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

class _PushRecorder extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushed.add(route);
}

Future<void> main() async {
  await ensureSnapshotHarness();
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
      // SIM is the mode on screen; the indicator only reports it.
      expect(find.descendant(of: card, matching: find.text(l.simMode)), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(l.ergMode)), findsOneWidget);
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

    testWidgets('the header opens the trainer', (tester) async {
      liveTrainer();
      final recorder = _PushRecorder();
      await pumpRide(tester, observers: [recorder]);
      final pushedBefore = recorder.pushed.length;

      await tester.tap(find.descendant(of: find.byType(VirtualShiftingCard), matching: find.text('KICKR CORE')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(recorder.pushed.length, pushedBefore + 1);
    });

    testWidgets('without a trainer, Ride invites the rider to connect one', (tester) async {
      await pumpRide(tester);

      expect(find.byType(VirtualShiftingCard), findsNothing);
      expect(find.text(l.rideVsInviteBody), findsOneWidget);
    });
  });

  group('your buttons', () {
    testWidgets('shows the controller with its action badges and the hint', (tester) async {
      final play = connectedPlay();
      await pumpRide(tester);

      expect(find.text(l.rideYourButtons), findsOneWidget);
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
      final buttons = rectOf(tester, find.text(l.rideYourButtons));
      expect(buttons.top, greaterThan(vs.bottom), reason: 'buttons sit under the shifting card');
      expect(buttons.bottom, lessThan(844), reason: 'the buttons header is in the first screen');
      await disposeShell(tester);
    });

    testWidgets('iPad portrait (820): one wide column, the gear still the largest thing', (tester) async {
      await pumpShellWithRide(tester, const Size(820, 1180));
      expect(tester.takeException(), isNull);

      final vs = rectOf(tester, find.byType(VirtualShiftingCard));
      final buttons = rectOf(tester, find.text(l.rideYourButtons));
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
      final buttons = rectOf(tester, find.text(l.rideYourButtons));
      expect(buttons.left, greaterThan(vs.right), reason: 'two columns');
      await disposeShell(tester);
    });

    testWidgets('1300 wide: one column beside the activity column', (tester) async {
      await pumpShellWithRide(tester, const Size(1300, 800));
      expect(tester.takeException(), isNull);

      final vs = rectOf(tester, find.byType(VirtualShiftingCard));
      final buttons = rectOf(tester, find.text(l.rideYourButtons));
      expect(buttons.top, greaterThan(vs.bottom));
      expect(find.byKey(const ValueKey('activity-column')), findsOneWidget);
      await disposeShell(tester);
    });
  });
}
