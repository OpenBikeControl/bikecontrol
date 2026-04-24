import 'package:bike_control/services/workout/trainer_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns null for unknown definition', () {
    expect(TrainerMetrics.fromDefinition(null), isNull);
    expect(TrainerMetrics.fromDefinition(Object()), isNull);
  });

  test('returns null for non-definition values', () {
    expect(TrainerMetrics.fromDefinition(42), isNull);
  });
}
