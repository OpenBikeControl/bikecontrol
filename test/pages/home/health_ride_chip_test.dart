// The home-screen chip while an automatic ride is being recorded, with
// "Finish now" and "Discard" actions.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/health/fake_health_workout_channel.dart';
import 'package:bike_control/services/health/health_ride_preferences.dart';
import 'package:bike_control/services/health/health_ride_service.dart';
import 'package:bike_control/services/workout/trainer_metrics.dart';
import 'package:bike_control/services/workout/workout_recorder.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/home/health_ride_chip.dart';
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

class _Trainer {
  final power = ValueNotifier<int?>(null);
  final cadence = ValueNotifier<int?>(null);
  late final metrics = TrainerMetrics(
    powerW: power,
    cadenceRpm: cadence,
    speedKph: ValueNotifier<double?>(null),
    heartRateBpm: ValueNotifier<int?>(null),
  );
}

Future<void> main() async {
  await ensureSnapshotHarness();

  late FakeHealthWorkoutChannel channel;
  late HealthRideService service;
  late WorkoutRecorder recorder;
  late _Trainer trainer;
  final fitSaves = <Object?>[];

  Future<void> buildService() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = HealthRidePreferences(await SharedPreferences.getInstance());
    await prefs.setExplicitChoice(true);
    channel = FakeHealthWorkoutChannel();
    trainer = _Trainer();
    recorder = WorkoutRecorder();
    service = HealthRideService(
      recorder: recorder,
      prefs: prefs,
      channel: channel,
      feedback: _NoFeedback(),
      isPlatformSupported: () => true,
      isPro: () => true,
      trainerApp: () => null,
      target: () => Target.thisDevice,
      connectedTrainer: () => trainer.metrics,
      saveFit: (result) async => fitSaves.add(result),
      onError: (_, _, _) {},
    );
    await service.start();
  }

  Future<void> pump(WidgetTester tester) async {
    await buildService();
    // Registered per-test (not a file-level tearDown): flutter_test checks
    // for pending timers as part of the test body itself, before a
    // file-level tearDown would ever run — the controller's 1 Hz ticker has
    // to be cancelled before that check, not after.
    addTearDown(() {
      service.dispose();
      recorder.dispose();
    });
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [
          ...ShadcnLocalizations.localizationsDelegates,
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(child: HealthRideChip(service: service)),
      ),
    );
    await tester.pump();
  }

  testWidgets('hidden until an automatic recording starts', (tester) async {
    await pump(tester);
    expect(find.text(AppLocalizations.current.healthRideChipLabel), findsNothing);

    trainer.power.value = 200;
    trainer.cadence.value = 90;
    await tester.pump(const Duration(seconds: 2));

    expect(find.text(AppLocalizations.current.healthRideChipLabel), findsOneWidget);
  });

  testWidgets('Finish now ends the ride and hides the chip', (tester) async {
    await pump(tester);
    trainer.power.value = 200;
    trainer.cadence.value = 90;
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(AppLocalizations.current.healthRideChipLabel), findsOneWidget);

    await tester.tap(find.text(AppLocalizations.current.healthRideFinishNow));
    await tester.pump();

    expect(find.text(AppLocalizations.current.healthRideChipLabel), findsNothing);
  });

  testWidgets('Discard asks for confirmation, then drops the ride without saving', (tester) async {
    await pump(tester);
    trainer.power.value = 200;
    trainer.cadence.value = 90;
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text(AppLocalizations.current.healthRideDiscard));
    await tester.pumpAndSettle();
    expect(find.text(AppLocalizations.current.healthRideDiscardConfirmTitle), findsOneWidget);

    await tester.tap(find.text(AppLocalizations.current.healthRideDiscardConfirmAction));
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizations.current.healthRideChipLabel), findsNothing);
    expect(fitSaves, isEmpty);
  });
}
