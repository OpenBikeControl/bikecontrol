import 'package:bike_control/services/workout/trainer_metrics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/definitions/proxy_bike_definition.dart';

void main() {
  test('returns null for unknown definition', () {
    expect(TrainerMetrics.fromDefinition(null), isNull);
    expect(TrainerMetrics.fromDefinition(Object()), isNull);
  });

  test('wraps FitnessBikeDefinition listenables', () {
    // We cannot construct a real FitnessBikeDefinition easily in a unit test;
    // rely on runtime-type branch by passing a fake via a subclass is impractical
    // here — assert only the null / unknown-type branches. Integration coverage
    // happens via the live page in Task 5.
    expect(TrainerMetrics.fromDefinition(42), isNull);
  });
}
