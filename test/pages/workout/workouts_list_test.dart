import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/workout/workouts_list_page.dart';
import 'package:bike_control/services/workout/past_workout.dart';
import 'package:bike_control/services/workout/workout_repository.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/ride_rig.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

class _FakeRepository extends WorkoutRepository {
  _FakeRepository(this.items);
  final List<PastWorkout> items;

  @override
  Future<List<PastWorkout>> list() async => items;
}

Future<void> main() async {
  await ensureSnapshotHarness();

  testWidgets('a long history scrolls inside the sheet, and rows are not dead buttons', (tester) async {
    await RideRig.install();
    core.rides.repository = _FakeRepository([
      for (var i = 0; i < 30; i++)
        PastWorkout(file: File('/tmp/w$i.fit'), startedAt: DateTime(2026, 9, 1 + (i % 28), 7, i), sizeBytes: 1000),
    ]);

    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        // The bottom sheet: bounded height, no scroll view of its own.
        home: const Scaffold(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(height: 300, child: WorkoutsList(showHeader: true)),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull, reason: 'the list must not overflow the sheet');
    expect(find.text('w0.fit'), findsOneWidget);
    expect(
      find.ancestor(of: find.text('w0.fit'), matching: find.byType(Button)),
      findsNothing,
      reason: 'a row that does nothing when tapped must not present itself as a button',
    );

    await tester.dragUntilVisible(find.text('w29.fit'), find.byType(Scrollable).first, const Offset(0, -200));
    expect(find.text('w29.fit'), findsOneWidget);
  });

  testWidgets('opens in the real bottom sheet without a layout error', (tester) async {
    await RideRig.install();
    core.rides.repository = _FakeRepository([
      for (var i = 0; i < 30; i++)
        PastWorkout(file: File('/tmp/w$i.fit'), startedAt: DateTime(2026, 9, 1, 7, i), sizeBytes: 1000),
    ]);

    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          child: Builder(
            builder: (context) => Button.primary(
              onPressed: () => openSheet(
                context: context,
                draggable: true,
                position: OverlayPosition.bottom,
                builder: (_) => const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: WorkoutsList(showHeader: true),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('w0.fit'), findsOneWidget);
  });
}
