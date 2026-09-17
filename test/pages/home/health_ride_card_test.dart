// The one-time home offer: "we noticed a ride, want it saved to Apple
// Health from now on?" — shown once, Pro-gated, dismissible for good.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/health/fake_health_workout_channel.dart';
import 'package:bike_control/services/health/health_ride_preferences.dart';
import 'package:bike_control/services/health/health_ride_service.dart';
import 'package:bike_control/services/workout/workout_recorder.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/home/health_ride_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widget_snapshot.dart';

class _NoFeedback implements HealthRideFeedback {
  @override
  void onSaved(HealthRideSaved ride) {}

  @override
  void onFailed({required bool denied}) {}
}

Future<void> main() async {
  await ensureSnapshotHarness();

  late FakeHealthWorkoutChannel channel;
  late HealthRideService service;

  Future<void> buildService() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = HealthRidePreferences(await SharedPreferences.getInstance());
    channel = FakeHealthWorkoutChannel();
    service = HealthRideService(
      recorder: WorkoutRecorder(),
      prefs: prefs,
      channel: channel,
      feedback: _NoFeedback(),
      isPlatformSupported: () => true,
      isPro: () => IAPManager.instance.isProEnabledForCurrentDevice,
      trainerApp: () => null,
      target: () => Target.thisDevice,
      connectedTrainer: () => null,
      saveFit: (_) async {},
      onError: (_, _, _) {},
    );
    await service.start();
    await service.prefs.setRideDetected();
  }

  tearDown(() {
    IAPManager.instance.setProForTesting(enabled: false);
    service.dispose();
  });

  Future<void> pump(WidgetTester tester) async {
    await buildService();
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [
          ...ShadcnLocalizations.localizationsDelegates,
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(child: HealthRideCard(service: service)),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the offer once a ride with a connected trainer happened', (tester) async {
    await pump(tester);

    expect(find.text(AppLocalizations.current.healthRideCardTitle), findsOneWidget);
  });

  testWidgets('Pro: Enable authorizes, stores the choice and hides the card', (tester) async {
    IAPManager.instance.setProForTesting(enabled: true, registeredDevice: true);
    await pump(tester);

    await tester.tap(find.text(AppLocalizations.current.healthRideCardEnable));
    await tester.pumpAndSettle();

    expect(channel.authorizeCalls, 1);
    expect(service.prefs.explicitChoice, isTrue);
    expect(find.text(AppLocalizations.current.healthRideCardTitle), findsNothing);
  });

  testWidgets('not Pro: Enable shows the paywall and changes nothing', (tester) async {
    IAPManager.instance.setProForTesting(enabled: false);
    await pump(tester);

    await tester.tap(find.text(AppLocalizations.current.healthRideCardEnable));
    await tester.pumpAndSettle();

    expect(channel.authorizeCalls, 0);
    expect(service.prefs.explicitChoice, isNull);
  });

  testWidgets('Not now dismisses the offer for good', (tester) async {
    await pump(tester);

    await tester.tap(find.text(AppLocalizations.current.healthRideCardDismiss));
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizations.current.healthRideCardTitle), findsNothing);
    expect(service.prefs.promptDismissed, isTrue);
    expect(service.prefs.explicitChoice, isFalse);
  });
}
