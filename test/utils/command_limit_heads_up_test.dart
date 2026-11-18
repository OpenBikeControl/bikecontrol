import 'package:bike_control/utils/iap/command_limit_heads_up.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final morning = DateTime(2026, 11, 18, 8);
  final evening = DateTime(2026, 11, 18, 20);
  final tomorrow = DateTime(2026, 11, 19, 8);

  test('warns once when the presses left drop to the threshold', () {
    final headsUp = CommandLimitHeadsUp();
    expect(headsUp.shouldWarn(remaining: CommandLimitHeadsUp.threshold + 1, now: morning), isFalse);
    expect(headsUp.shouldWarn(remaining: CommandLimitHeadsUp.threshold, now: morning), isTrue);
    expect(headsUp.shouldWarn(remaining: CommandLimitHeadsUp.threshold - 1, now: morning), isFalse);
    expect(headsUp.shouldWarn(remaining: 3, now: evening), isFalse);
  });

  test('warns again the next day', () {
    final headsUp = CommandLimitHeadsUp();
    expect(headsUp.shouldWarn(remaining: 5, now: morning), isTrue);
    expect(headsUp.shouldWarn(remaining: 5, now: tomorrow), isTrue);
  });

  test('no warning when unlimited (-1) or already out (the limit alert covers 0)', () {
    final headsUp = CommandLimitHeadsUp();
    expect(headsUp.shouldWarn(remaining: -1, now: morning), isFalse);
    expect(headsUp.shouldWarn(remaining: 0, now: morning), isFalse);
  });
}
