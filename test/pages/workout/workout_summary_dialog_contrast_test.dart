import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/workout/workout_summary_dialog.dart';
import 'package:bike_control/services/workout/workout_summary.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/contrast.dart';
import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  final summary = WorkoutSummary(
    startedAt: DateTime(2026, 9, 1),
    activeDuration: const Duration(minutes: 42),
    avgPowerW: 210,
    maxPowerW: 480,
    avgCadenceRpm: 88,
    avgSpeedKph: 31.2,
    distanceKm: 21.8,
    avgHeartRateBpm: 142,
    maxHeartRateBpm: 171,
    sampleCount: 2520,
  );

  for (final brightness in Brightness.values) {
    testWidgets('$brightness: summary tiles are legible, icons included', (tester) async {
      tester.view.physicalSize = const Size(600, 1000) * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final theme = BkTheme.build(brightness);
      await tester.pumpWidget(
        ShadcnApp(
          localizationsDelegates: [
            ...ShadcnLocalizations.localizationsDelegates,
            const OtherLocalizationsDelegate(),
            AppLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          theme: theme,
          home: Builder(
            builder: (context) => Button.primary(
              onPressed: () => showWorkoutSummaryDialog(context: context, summary: summary, fitFile: File('/tmp/x.fit')),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expectLegibleText(tester, find.byType(AlertDialog), pageBackground: theme.colorScheme.popover);
    });
  }
}
