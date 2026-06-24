import 'package:flutter_test/flutter_test.dart';
import 'package:bike_control/models/shifting_config.dart';

void main() {
  test('defaults: front shift off, 34/50 chainrings', () {
    final c = ShiftingConfig.defaults(trainerKey: 'k');
    expect(c.frontShiftEnabled, isFalse);
    expect(c.smallChainringTeeth, 34);
    expect(c.largeChainringTeeth, 50);
  });

  test('round-trips through JSON', () {
    final c = ShiftingConfig.defaults(trainerKey: 'k').copyWith(
      frontShiftEnabled: true,
      smallChainringTeeth: 36,
      largeChainringTeeth: 52,
    );
    final back = ShiftingConfig.fromJson(c.toJson());
    expect(back.frontShiftEnabled, isTrue);
    expect(back.smallChainringTeeth, 36);
    expect(back.largeChainringTeeth, 52);
    expect(back, c);
  });

  test('fromJson falls back to defaults when keys absent', () {
    final back = ShiftingConfig.fromJson({'trainerKey': 'k'});
    expect(back.frontShiftEnabled, isFalse);
    expect(back.smallChainringTeeth, 34);
    expect(back.largeChainringTeeth, 50);
  });
}
