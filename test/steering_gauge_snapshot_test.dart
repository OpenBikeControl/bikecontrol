@Tags(['screenshots'])
library;

import 'package:bike_control/widgets/controller/steering_gauge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'widget_snapshot.dart';

/// Renders the horizontal steering gauge at a fixed 8° tilt (past the default
/// 5° threshold, so the LEFT zone glows). Run:
/// `flutter test --run-skipped test/steering_gauge_snapshot_test.dart`
Future<void> main() async {
  await ensureSnapshotHarness();

  final angle = ValueNotifier<double>(8.0);
  final calibrated = ValueNotifier<bool>(true);

  Widget gauge() => SteeringGauge(
        angle: angle,
        calibrated: calibrated,
        threshold: 5,
        leftAction: 'Steer Left',
        rightAction: 'Steer Right',
      );

  testWidgets('SteeringGauge (active left) → PNG light/dark', (tester) async {
    await captureWidget(
      tester,
      name: 'steering_gauge_light',
      width: 360,
      locales: const ['en', 'de'],
      builder: (context) => gauge(),
    );
    await captureWidget(
      tester,
      name: 'steering_gauge_dark',
      width: 360,
      brightness: Brightness.dark,
      builder: (context) => gauge(),
    );
  });

  testWidgets('SteeringGauge (calibrating) → PNG', (tester) async {
    calibrated.value = false;
    angle.value = 0.0;
    await captureWidget(
      tester,
      name: 'steering_gauge_calibrating',
      width: 360,
      settle: false,
      builder: (context) => gauge(),
    );
  });
}
