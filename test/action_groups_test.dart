import 'package:bike_control/utils/keymap/action_groups.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every action belongs to a group', () {
    for (final action in InGameAction.values) {
      expect(() => ActionGroup.of(action), returnsNormally, reason: '$action');
    }
  });

  test('an action offered by two connections is listed once', () {
    final groups = groupActions([
      // Trainer direct control …
      InGameAction.shiftUp, InGameAction.shiftDown, InGameAction.trainerSwitchMode,
      // … and the trainer app over OpenBikeControl.
      InGameAction.shiftUp, InGameAction.shiftDown, InGameAction.up, InGameAction.select,
    ]);
    final all = groups.expand((g) => g.actions).toList();
    expect(all.where((a) => a == InGameAction.shiftUp), hasLength(1));
    expect(all.where((a) => a == InGameAction.shiftDown), hasLength(1));
  });

  test('groups come in a fixed order and skip empty ones', () {
    final groups = groupActions([
      InGameAction.select,
      InGameAction.cameraAngle,
      InGameAction.trainerIntensityUp,
      InGameAction.shiftUp,
    ]);
    expect(groups.map((g) => g.group), [
      ActionGroup.gears,
      ActionGroup.trainer,
      ActionGroup.navigate,
      ActionGroup.view,
    ]);
  });

  test('navigation reads like a d-pad: up, down, left, right, select, back', () {
    final groups = groupActions([
      InGameAction.back,
      InGameAction.navigateRight,
      InGameAction.select,
      InGameAction.down,
      InGameAction.navigateLeft,
      InGameAction.up,
    ]);
    expect(groups.single.actions, [
      InGameAction.up,
      InGameAction.down,
      InGameAction.navigateLeft,
      InGameAction.navigateRight,
      InGameAction.select,
      InGameAction.back,
    ]);
  });

  test('interval controls are a workout, not the trainer', () {
    final groups = groupActions([InGameAction.skipInterval, InGameAction.trainerSwitchMode, InGameAction.lap]);
    expect(groups.map((g) => g.group), [ActionGroup.trainer, ActionGroup.workout]);
    expect(groups.last.actions, [InGameAction.skipInterval, InGameAction.lap]);
  });

  test('shifting and the chainring sit together under gears', () {
    final groups = groupActions([InGameAction.frontShift, InGameAction.shiftDown, InGameAction.shiftUp]);
    expect(groups.single.group, ActionGroup.gears);
    expect(groups.single.actions, [InGameAction.shiftUp, InGameAction.shiftDown, InGameAction.frontShift]);
  });
}
