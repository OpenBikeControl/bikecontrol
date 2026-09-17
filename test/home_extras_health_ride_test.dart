// "Save rides to Apple Health" toggle in the home page's "More options"
// section: iOS/iPadOS with Health only, Pro-gated, and a hint under it when
// the selected trainer app may already save the ride itself.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/home/home_extras.dart';
import 'package:bike_control/services/health/fake_health_workout_channel.dart';
import 'package:bike_control/services/health/health_ride_preferences.dart';
import 'package:bike_control/services/health/health_ride_service.dart';
import 'package:bike_control/services/workout/workout_recorder.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_snapshot.dart';

class _NoFeedback implements HealthRideFeedback {
  @override
  void onSaved(HealthRideSaved ride) {}

  @override
  void onFailed({required bool denied}) {}
}

Future<void> main() async {
  await ensureSnapshotHarness();

  late FakeHealthWorkoutChannel channel;
  SupportedApp? app;
  bool platformSupported = true;

  Future<HealthRideService> buildService() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = HealthRidePreferences(await SharedPreferences.getInstance());
    channel = FakeHealthWorkoutChannel();
    final service = HealthRideService(
      recorder: WorkoutRecorder(),
      prefs: prefs,
      channel: channel,
      feedback: _NoFeedback(),
      isPlatformSupported: () => platformSupported,
      isPro: () => IAPManager.instance.isProEnabledForCurrentDevice,
      trainerApp: () => app,
      target: () => Target.thisDevice,
      connectedTrainer: () => null,
      saveFit: (_) async {},
      onError: (_, _, _) {},
    );
    await service.start();
    return service;
  }

  setUp(() {
    app = null;
    platformSupported = true;
  });

  tearDown(() {
    IAPManager.instance.setProForTesting(enabled: false);
    core.healthRide.dispose();
  });

  Future<void> pump(WidgetTester tester) async {
    core.healthRide = await buildService();
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [
          ...ShadcnLocalizations.localizationsDelegates,
          OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.7),
        home: SingleChildScrollView(child: HomeExtras(isMobile: false, onUpdate: () {})),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hidden when the platform/Health is unsupported', (tester) async {
    platformSupported = false;
    await pump(tester);

    expect(find.text(AppLocalizations.current.healthRideToggleTitle), findsNothing);
  });

  testWidgets('shown when supported, off by default without a decision', (tester) async {
    await pump(tester);

    expect(find.text(AppLocalizations.current.healthRideToggleTitle), findsOneWidget);
  });

  testWidgets('no duplicate hint for an app that does not write to Health itself', (tester) async {
    app = MyWhoosh();
    await pump(tester);

    expect(find.text(AppLocalizations.current.healthRideDuplicateHint('MyWhoosh')), findsNothing);
  });

  testWidgets('duplicate hint shown for Zwift, naming the app', (tester) async {
    app = Zwift();
    await pump(tester);

    expect(find.text(AppLocalizations.current.healthRideDuplicateHint('Zwift')), findsOneWidget);
  });

  testWidgets('Pro: flipping the switch on authorizes and stores the choice', (tester) async {
    IAPManager.instance.setProForTesting(enabled: true, registeredDevice: true);
    await pump(tester);
    // Undecided defaults to on with no duplicate-risk app selected — start
    // from an explicit off so the tap below is really a turn-on.
    await core.healthRide.prefs.setExplicitChoice(false);
    await tester.pump();

    await tester.tap(find.text(AppLocalizations.current.healthRideToggleTitle));
    await tester.pumpAndSettle();

    expect(channel.authorizeCalls, 1);
    expect(core.healthRide.isEnabled, isTrue);
  });

  testWidgets('not Pro: flipping the switch shows the paywall and changes nothing', (tester) async {
    IAPManager.instance.setProForTesting(enabled: false);
    await pump(tester);
    // Without Pro the toggle reads off no matter what the rider chose, so
    // the tap below attempts a turn-on — Pro gates it first.
    expect(core.healthRide.isEnabled, isFalse);

    await tester.tap(find.text(AppLocalizations.current.healthRideToggleTitle));
    await tester.pumpAndSettle();

    expect(channel.authorizeCalls, 0);
    expect(core.healthRide.prefs.explicitChoice, isNull);
  });
}
