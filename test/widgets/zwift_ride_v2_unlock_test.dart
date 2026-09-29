// The Zwift Ride V2 screens: its unlock section (no Click V2 unlock modes, a
// way to support), the unlock page, and the one-time explainer.
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_unlock.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/unlock.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/unlock_toggle.dart';
import 'package:bike_control/widgets/zwift_ride_v2_unlock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

ZwiftRide _rideV2() => ZwiftRide(BleDevice(deviceId: 'ride-v2', name: 'Zwift Ride'))
  ..firmwareVersion = '1.3.0'
  ..isConnected = true;

ZwiftClickV2 _clickV2() => ZwiftClickV2(BleDevice(deviceId: 'click-v2', name: 'Zwift Click'))..isConnected = true;

const _supportLine = ValueKey('ride-v2-support-line');

Widget _host(Widget Function(BuildContext context) builder) => ShadcnApp(
  localizationsDelegates: const [AppLocalizations.delegate],
  supportedLocales: const [Locale('en')],
  home: Scaffold(
    child: SingleChildScrollView(
      child: SizedBox(width: 400, child: Builder(builder: builder)),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.actionHandler = StubActions();
    core.settings.prefs = await SharedPreferences.getInstance();
    propPrefs.initialize(core.settings.prefs);
    await AppLocalizations.load(const Locale('en'));
    await initializeDateFormatting();
  });

  group('device card', () {
    testWidgets('a Ride V2 shows its unlock state and the support line, without the unlock-mode toggle', (
      tester,
    ) async {
      final ride = _rideV2();
      await tester.pumpWidget(_host((context) => Column(children: ride.showAdditionalInformation(context))));
      await tester.pump();

      expect(find.byType(ZwiftRideV2UnlockSection), findsOneWidget);
      expect(find.byType(UnlockToggle), findsNothing);
      expect(find.byKey(_supportLine), findsOneWidget);
      expect(find.text(AppLocalizations.current.unlock_deviceIsCurrentlyLocked), findsOneWidget);
      expect(find.text(AppLocalizations.current.unlock_modeRestart), findsNothing);
    });

    testWidgets('a Ride V2 that was unlocked shows until when, with "Unlock again"', (tester) async {
      final ride = _rideV2();
      propPrefs.setZwiftClickV2LastUnlock('ride-v2', DateTime.now(), keyPrefix: ride.unlockKeyPrefix);
      await tester.pumpWidget(_host((context) => Column(children: ride.showAdditionalInformation(context))));
      await tester.pump();

      expect(find.textContaining('Unlocked until around'), findsOneWidget);
      expect(find.text(AppLocalizations.current.unlockAgain), findsOneWidget);
    });

    testWidgets('a Ride V1 shows no unlock section at all', (tester) async {
      final ride = _rideV2()..firmwareVersion = '1.2.0';
      await tester.pumpWidget(_host((context) => Column(children: ride.showAdditionalInformation(context))));
      await tester.pump();

      expect(find.byType(ZwiftRideV2UnlockSection), findsNothing);
      expect(find.byKey(_supportLine), findsNothing);
    });

    testWidgets('a Click V2 keeps its unlock-mode toggle and gets no support line', (tester) async {
      final click = _clickV2();
      await tester.pumpWidget(_host((context) => Column(children: click.showAdditionalInformation(context))));
      await tester.pump();

      expect(find.byType(UnlockToggle), findsOneWidget);
      expect(find.byKey(_supportLine), findsNothing);
      expect(find.text(AppLocalizations.current.unlock_deviceIsCurrentlyLocked), findsOneWidget);
    });
  });

  group('unlock page', () {
    setUp(() {
      // Already running, so the page does not start a real server.
      ftmsEmulator.isStarted.value = true;
    });
    tearDown(() {
      ftmsEmulator.isStarted.value = false;
    });

    Future<void> pumpUnlockPage(WidgetTester tester, ZwiftUnlock device) async {
      await tester.pumpWidget(_host((context) => UnlockPage(device: device)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('a Ride V2 offers the support line', (tester) async {
      await pumpUnlockPage(tester, _rideV2());
      expect(find.byKey(_supportLine), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a Click V2 does not', (tester) async {
      await pumpUnlockPage(tester, _clickV2());
      expect(find.byKey(_supportLine), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a Ride V2 with its Zwift service hidden starts on the manual Ride V2 steps', (tester) async {
      final ride = _rideV2();
      await ride.handleServices(const <BleService>[]);
      expect(ride.unlockServiceHidden, isTrue);
      await pumpUnlockPage(tester, ride);
      expect(find.text(AppLocalizations.current.rideV2Instructions), findsOneWidget);
      expect(find.text(AppLocalizations.current.clickV2Instructions), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('one-time explainer', () {
    testWidgets('shows once for the first connected Ride V2, never again', (tester) async {
      final ride = _rideV2();
      final shown = <bool>[];
      await tester.pumpWidget(
        _host(
          (context) => Button.primary(
            onPressed: () async => shown.add(await maybeShowZwiftRideV2Explainer(context, [ride])),
            child: const Text('go'),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byType(ZwiftRideV2ExplainerPage), findsOneWidget);
      expect(find.byKey(_supportLine), findsOneWidget);
      expect(core.settings.getRideV2ExplainerShown(), isTrue);

      await tester.tap(find.byKey(const ValueKey('ride-v2-explainer-got-it')));
      await tester.pumpAndSettle();
      expect(find.byType(ZwiftRideV2ExplainerPage), findsNothing);
      expect(shown, [true]);

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byType(ZwiftRideV2ExplainerPage), findsNothing);
      expect(shown, [true, false]);
    });

    testWidgets('does not show for a Ride V1 or a Click V2', (tester) async {
      bool? shown;
      final v1 = _rideV2()..firmwareVersion = '1.2.0';
      await tester.pumpWidget(
        _host(
          (context) => Button.primary(
            onPressed: () async => shown = await maybeShowZwiftRideV2Explainer(context, [v1, _clickV2()]),
            child: const Text('go'),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(shown, isFalse);
      expect(core.settings.getRideV2ExplainerShown(), isFalse);
    });
  });
}
