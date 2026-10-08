import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/services/workout/trainer_metrics.dart';
import 'package:bike_control/services/workout/workout_recorder.dart';
import 'package:bike_control/widgets/rides/ride_recording_line.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/ride_rig.dart';

Widget _app(Widget child, {bool reduceMotion = false}) => ShadcnApp(
  localizationsDelegates: const [
    ...ShadcnLocalizations.localizationsDelegates,
    OtherLocalizationsDelegate(),
    AppLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.delegate.supportedLocales,
  theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.7),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    ),
  ),
);

/// The recording dot pulses forever, so pumpAndSettle never would.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

TrainerMetrics _metrics() => TrainerMetrics(
  powerW: ValueNotifier<int?>(200),
  cadenceRpm: ValueNotifier<int?>(90),
  speedKph: ValueNotifier<double?>(null),
  heartRateBpm: ValueNotifier<int?>(null),
  sourceName: 'KICKR CORE',
);

void main() {
  late AppLocalizations l10n;
  setUpAll(() async => l10n = await AppLocalizations.load(const Locale('en')));

  group('RideRecordingLine', () {
    testWidgets('recording: label, moving time, how it started, Beenden', (tester) async {
      var finished = 0;
      await tester.pumpWidget(
        _app(
          RideRecordingLine(
            paused: false,
            elapsed: ValueNotifier(const Duration(minutes: 12, seconds: 34)),
            startedAutomatically: true,
            onFinish: () => finished++,
            onDiscard: () {},
          ),
        ),
      );
      expect(find.text(l10n.miniWorkoutRecording), findsOneWidget);
      expect(find.textContaining('12:34'), findsOneWidget);
      expect(find.textContaining(l10n.ridesAutoStarted), findsOneWidget);
      await tester.tap(find.text(l10n.miniWorkoutStop));
      expect(finished, 1);
    });

    testWidgets('paused: says how it resumes, no resume button', (tester) async {
      await tester.pumpWidget(
        _app(
          RideRecordingLine(
            paused: true,
            elapsed: ValueNotifier(const Duration(minutes: 12, seconds: 34)),
            startedAutomatically: true,
            onFinish: () {},
            onDiscard: () {},
          ),
        ),
      );
      expect(find.text(l10n.miniWorkoutPaused), findsOneWidget);
      expect(find.textContaining(l10n.ridesResumesOnPedal), findsOneWidget);
      expect(find.byType(Button), findsNWidgets(2), reason: 'Beenden and Verwerfen only: no resume button');
    });

    testWidgets('Verwerfen asks first; Abbrechen keeps the ride', (tester) async {
      var discarded = 0;
      await tester.pumpWidget(
        _app(
          RideRecordingLine(
            paused: false,
            elapsed: ValueNotifier(Duration.zero),
            startedAutomatically: false,
            onFinish: () {},
            onDiscard: () => discarded++,
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel(l10n.healthRideDiscard));
      await _settle(tester);
      expect(find.text(l10n.healthRideDiscardConfirmTitle), findsOneWidget);
      expect(find.text(l10n.ridesDiscardBody), findsOneWidget);
      await tester.tap(find.text(l10n.cancel));
      await _settle(tester);
      expect(discarded, 0);

      await tester.tap(find.bySemanticsLabel(l10n.healthRideDiscard));
      await _settle(tester);
      await tester.tap(find.text(l10n.healthRideDiscardConfirmAction));
      await _settle(tester);
      expect(discarded, 1);
    });

    testWidgets('the dot pulses, and stands still under reduced motion', (tester) async {
      Widget line({required bool reduce}) => _app(
        RideRecordingLine(
          paused: false,
          elapsed: ValueNotifier(Duration.zero),
          startedAutomatically: true,
          onFinish: () {},
          onDiscard: () {},
        ),
        reduceMotion: reduce,
      );
      await tester.pumpWidget(line(reduce: false));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpWidget(line(reduce: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('RideRecordingSlot', () {
    setUp(RideRig.reset);

    testWidgets('automatic recording on and no ride: nothing to show', (tester) async {
      await RideRig.install();
      await tester.pumpWidget(_app(const RideRecordingSlot()));
      expect(find.byType(RideRecordingLine), findsNothing);
      expect(find.text(l10n.miniWorkoutStart), findsNothing);
    });

    testWidgets('automatic recording off: a manual start that runs the same ride', (tester) async {
      RideRig.source = _metrics();
      final rig = await RideRig.install(prefs: {'rides_auto_record': false});
      await tester.pumpWidget(_app(const RideRecordingSlot()));
      expect(find.textContaining(l10n.ridesAutoOff), findsOneWidget);

      await tester.tap(find.text(l10n.miniWorkoutStart));
      await tester.pump();
      expect(rig.service.recorder.state.value, WorkoutState.recording);
      expect(find.byType(RideRecordingLine), findsOneWidget);
      expect(find.textContaining(l10n.ridesAutoStarted), findsNothing);

      rig.service.discard();
      await tester.pump();
    });

    testWidgets('automatic recording off and nothing to record from: start disabled, says why', (tester) async {
      await RideRig.install(prefs: {'rides_auto_record': false});
      await tester.pumpWidget(_app(const RideRecordingSlot()));
      expect(find.text(l10n.miniWorkoutNoTrainerConnected), findsOneWidget);
      final button = tester.widget<Button>(
        find.ancestor(of: find.text(l10n.miniWorkoutStart), matching: find.byType(Button)),
      );
      expect(button.onPressed, isNull);
    });
  });
}
