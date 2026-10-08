// Settings → During the ride: "Record rides automatically" (on by default,
// every platform), then "Save rides to Apple Health / Health Connect" only
// where the store exists, never Pro-gated, with a hint under it when the
// selected trainer app may already save the ride itself. Then the optional
// FTP and max heart rate the ride details' zones are based on.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/settings/settings_page.dart';
import 'package:bike_control/services/health/health_workout_channel.dart';
import 'package:bike_control/services/rides/ride_format.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/ride_rig.dart';
import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  setUp(RideRig.reset);
  tearDown(() => IAPManager.instance.setProForTesting(enabled: false));

  Future<void> pump(WidgetTester tester, {double? width}) async {
    // The harness's live binding leaves the fake keyboard off; the FTP and
    // max heart rate fields are typed into and submitted with it.
    if (!tester.testTextInput.isRegistered) {
      tester.testTextInput.register();
      addTearDown(tester.testTextInput.unregister);
    }
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [
          ...ShadcnLocalizations.localizationsDelegates,
          OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.7),
        home: SingleChildScrollView(
          child: width == null
              ? const DuringRideSection()
              : Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(width: width, child: const DuringRideSection()),
                ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String toggle(HealthStore store) => AppLocalizations.current.ridesHealthToggle(healthStoreName(store));
  final apple = HealthStore.appleHealth;

  group('Record rides automatically', () {
    testWidgets('on by default, everywhere (no Health needed)', (tester) async {
      final rig = await RideRig.install(store: null);
      await pump(tester);

      expect(find.text(AppLocalizations.current.ridesAutoRecordTitle), findsOneWidget);
      expect(find.text(AppLocalizations.current.ridesAutoRecordSubtitle), findsOneWidget);
      expect(rig.service.autoRecord, isTrue);
    });

    testWidgets('turning it off says where the manual start is', (tester) async {
      final rig = await RideRig.install(store: null);
      await pump(tester);

      await tester.tap(find.text(AppLocalizations.current.ridesAutoRecordTitle));
      await tester.pumpAndSettle();
      expect(rig.service.autoRecord, isFalse);
      expect(find.text(AppLocalizations.current.ridesAutoRecordOffFooter), findsOneWidget);
    });

    testWidgets('comes first in During the ride', (tester) async {
      await RideRig.install();
      await pump(tester);
      final auto = tester.getTopLeft(find.text(AppLocalizations.current.ridesAutoRecordTitle)).dy;
      expect(auto, lessThan(tester.getTopLeft(find.text(toggle(apple))).dy));
    });
  });

  testWidgets('hidden where there is no Health store', (tester) async {
    await RideRig.install(store: null);
    await pump(tester);

    expect(find.text(toggle(apple)), findsNothing);
    expect(find.text(toggle(HealthStore.healthConnect)), findsNothing);
  });

  testWidgets('shown where Health exists, off until the rider says yes', (tester) async {
    final rig = await RideRig.install();
    await pump(tester);

    expect(find.text(toggle(apple)), findsOneWidget);
    expect(find.text(AppLocalizations.current.ridesHealthOnlyRecorded), findsOneWidget);
    expect(rig.service.savesToHealth, isFalse);
  });

  testWidgets('no duplicate hint for an app that does not write to Health itself', (tester) async {
    RideRig.app = MyWhoosh();
    await RideRig.install();
    await pump(tester);

    expect(find.textContaining('MyWhoosh'), findsNothing);
  });

  testWidgets('duplicate hint shown for Zwift, naming the app', (tester) async {
    RideRig.app = Zwift();
    await RideRig.install();
    await pump(tester);

    expect(
      find.text(AppLocalizations.current.ridesHealthDuplicateHint('Zwift', healthStoreName(apple))),
      findsOneWidget,
    );
  });

  testWidgets('without Pro: flipping the switch on authorizes and stores the choice, no paywall', (tester) async {
    IAPManager.instance.setProForTesting(enabled: false);
    final rig = await RideRig.install(store: HealthStore.healthConnect);
    await pump(tester);

    await tester.tap(find.text(toggle(HealthStore.healthConnect)));
    await tester.pumpAndSettle();

    expect(rig.channel!.authorizeCalls, 1);
    expect(rig.service.savesToHealth, isTrue);
  });

  testWidgets('Health Connect not installed: the row offers the install', (tester) async {
    final rig = await RideRig.install(
      store: HealthStore.healthConnect,
      availability: HealthAvailability.notInstalled,
    );
    await pump(tester);

    expect(find.text(AppLocalizations.current.ridesHealthConnectNotInstalled), findsOneWidget);
    await tester.tap(find.text(toggle(HealthStore.healthConnect)));
    await tester.pumpAndSettle();
    expect(rig.channel!.openInstallCalls, 1);
    expect(rig.channel!.authorizeCalls, 0);
  });

  group('FTP and max heart rate', () {
    Finder field(String row) =>
        find.descendant(of: find.byKey(ValueKey(row)), matching: find.byKey(const ValueKey('ride-zone-value-field')));
    String text(WidgetTester tester, String row) => tester.widget<TextField>(field(row)).controller!.text;
    Finder error(String row) =>
        find.descendant(of: find.byKey(ValueKey(row)), matching: find.byKey(const ValueKey('ride-zone-value-error')));

    testWidgets('edited right in the row, empty until the rider gives them', (tester) async {
      await RideRig.install(store: null);
      await pump(tester);

      expect(field('settings-ftp'), findsOneWidget);
      expect(field('settings-max-heart-rate'), findsOneWidget);
      expect(text(tester, 'settings-ftp'), isEmpty);
      expect(text(tester, 'settings-max-heart-rate'), isEmpty);
      // What the dialog used to explain now sits under the row's title.
      expect(find.text(AppLocalizations.current.ridesFtpBody), findsOneWidget);
      expect(find.text(AppLocalizations.current.ridesMaxHeartRateBody), findsOneWidget);
    });

    testWidgets('a stored value is in its field', (tester) async {
      await RideRig.install(store: null, prefs: {'rides_ftp_watts': 240, 'rides_max_heart_rate_bpm': 185});
      await pump(tester);

      expect(text(tester, 'settings-ftp'), '240');
      expect(text(tester, 'settings-max-heart-rate'), '185');
    });

    testWidgets('next to the recording setting, before anything about the ride itself', (tester) async {
      await RideRig.install();
      await pump(tester);
      final health = tester.getTopLeft(find.text(toggle(apple))).dy;
      final ftp = tester.getTopLeft(find.byKey(const ValueKey('settings-ftp'))).dy;
      final hr = tester.getTopLeft(find.byKey(const ValueKey('settings-max-heart-rate'))).dy;
      expect(ftp, greaterThan(health));
      expect(hr, greaterThan(ftp));
    });

    testWidgets('FTP: entered and submitted, saved and kept; emptied, unset again', (tester) async {
      final rig = await RideRig.install(store: null);
      await pump(tester);

      await tester.enterText(field('settings-ftp'), '250');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(rig.prefs.ftpWatts, 250);
      expect(text(tester, 'settings-ftp'), '250');

      await tester.enterText(field('settings-ftp'), '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(rig.prefs.ftpWatts, isNull);
    });

    testWidgets('leaving the field saves it too', (tester) async {
      final rig = await RideRig.install(store: null);
      await pump(tester);

      await tester.enterText(field('settings-max-heart-rate'), '190');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(rig.prefs.maxHeartRateBpm, 190);
    });

    testWidgets('an impossible FTP is not saved; the row says the range', (tester) async {
      final rig = await RideRig.install(store: null);
      await pump(tester);

      await tester.enterText(field('settings-ftp'), '20');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(rig.prefs.ftpWatts, isNull);
      expect(error('settings-ftp'), findsOneWidget);

      await tester.enterText(field('settings-ftp'), '1001');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(rig.prefs.ftpWatts, isNull);
      expect(error('settings-ftp'), findsOneWidget);

      await tester.enterText(field('settings-ftp'), '280');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(rig.prefs.ftpWatts, 280);
      expect(error('settings-ftp'), findsNothing);
    });

    testWidgets('max heart rate keeps its own range', (tester) async {
      final rig = await RideRig.install(store: null);
      await pump(tester);

      await tester.enterText(field('settings-max-heart-rate'), '250');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(rig.prefs.maxHeartRateBpm, isNull);
      expect(error('settings-max-heart-rate'), findsOneWidget);
    });

    testWidgets('Escape puts the stored value back, nothing saved', (tester) async {
      final rig = await RideRig.install(store: null, prefs: {'rides_ftp_watts': 240});
      await pump(tester);

      await tester.enterText(field('settings-ftp'), '300');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(rig.prefs.ftpWatts, 240);
      expect(text(tester, 'settings-ftp'), '240');
    });

    group('in a narrow column', () {
      testWidgets('the row shows the value; the field and its explanation wait in a dialog', (tester) async {
        await RideRig.install(store: null, prefs: {'rides_ftp_watts': 240});
        await pump(tester, width: 360);

        expect(field('settings-ftp'), findsNothing);
        expect(find.byKey(const ValueKey('ride-zone-value-field')), findsNothing);
        expect(find.text(AppLocalizations.current.ridesFtpBody), findsNothing);
        expect(find.descendant(of: find.byKey(const ValueKey('settings-ftp')), matching: find.text('240 W')), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('settings-ftp')));
        await tester.pumpAndSettle();
        expect(find.text(AppLocalizations.current.ridesFtpBody), findsOneWidget);
        expect(find.byKey(const ValueKey('ride-zone-value-field')), findsOneWidget);
      });

      testWidgets('entered in the dialog: saved, the dialog closes, the row shows it', (tester) async {
        final rig = await RideRig.install(store: null);
        await pump(tester, width: 360);

        await tester.tap(find.byKey(const ValueKey('settings-max-heart-rate')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const ValueKey('ride-zone-value-field')), '188');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(rig.prefs.maxHeartRateBpm, 188);
        expect(find.byKey(const ValueKey('ride-zone-value-field')), findsNothing, reason: 'dialog closed');
        expect(find.byType(DuringRideSection), findsOneWidget, reason: 'only the dialog closed');
        expect(
          find.descendant(of: find.byKey(const ValueKey('settings-max-heart-rate')), matching: find.text('188 bpm')),
          findsOneWidget,
        );
      });

      testWidgets('an impossible value keeps the dialog open with the range', (tester) async {
        final rig = await RideRig.install(store: null);
        await pump(tester, width: 360);

        await tester.tap(find.byKey(const ValueKey('settings-ftp')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const ValueKey('ride-zone-value-field')), '5');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(rig.prefs.ftpWatts, isNull);
        expect(find.byKey(const ValueKey('ride-zone-value-error')), findsOneWidget);
      });
    });

    testWidgets('only digits go in', (tester) async {
      await RideRig.install(store: null);
      await pump(tester);

      await tester.enterText(field('settings-ftp'), '2a5-0');
      expect(text(tester, 'settings-ftp'), '250');
    });
  });
}
