import 'package:bike_control/bluetooth/devices/elite/elite_square.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/utils/keymap/apps/training_peaks.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter_test/flutter_test.dart';

/// TrainingPeaks Virtual is reached over OpenBikeControl (BLE / DirCon), and
/// `BaseActions._handleDirectConnect` only forwards a [KeyPair] that carries an
/// [InGameAction]. A default that maps a button to a keyboard key or a touch
/// position *only* is therefore worse than shipping no default at all: it
/// shadows the action the button would otherwise inherit from
/// [ControllerButton.action] via [Keymap.addNewButtons], and the press can
/// never leave the phone.
void main() {
  final app = TrainingPeaks();
  final supportedActions = app.defaultObpSupportedButtons.mapNotNull((b) => b.action).toSet();

  test('every default key pair carries an in-game action', () {
    final actionless = app.keymap.keyPairs
        .where((k) => k.inGameAction == null)
        .expand((k) => k.buttons)
        .map((b) => b.name)
        .toList();

    expect(actionless, isEmpty, reason: 'these buttons can never reach TPV over OBP: $actionless');
  });

  test('every default in-game action is one TPV accepts over OBP', () {
    for (final keyPair in app.keymap.keyPairs) {
      expect(
        supportedActions,
        contains(keyPair.inGameAction),
        reason: '${keyPair.buttons.first.name} → ${keyPair.inGameAction} is not in defaultObpSupportedButtons',
      );
    }
  });

  test('navigation and face buttons keep their conventional actions', () {
    InGameAction? actionFor(ControllerButton button) =>
        app.keymap.getKeyPair(button, trigger: ButtonTrigger.singleClick)?.inGameAction;

    expect(actionFor(ZwiftButtons.navigationUp), InGameAction.up);
    // Steering only works while held: it sits on the long press.
    InGameAction? heldFor(ControllerButton button) =>
        app.keymap.getKeyPair(button, trigger: ButtonTrigger.longPress)?.inGameAction;
    expect(heldFor(ZwiftButtons.navigationLeft), InGameAction.steerLeft);
    expect(heldFor(ZwiftButtons.navigationRight), InGameAction.steerRight);
    expect(actionFor(ZwiftButtons.a), InGameAction.select);
    expect(actionFor(ZwiftButtons.b), InGameAction.back);
    expect(actionFor(ZwiftButtons.y), InGameAction.menu);
    expect(actionFor(ZwiftButtons.z), InGameAction.pause);

    // The Elite Square shares the face-button key pairs.
    expect(actionFor(EliteSquareButtons.a), InGameAction.select);
    expect(actionFor(EliteSquareButtons.y), InGameAction.menu);
  });

  test('navigation down inherits its default action instead of being shadowed', () {
    // Not in the profile at all — [Keymap.addNewButtons] seeds it from the
    // button itself when a controller connects. This is the behaviour the
    // explicit defaults above have to match.
    expect(app.keymap.getKeyPair(ZwiftButtons.navigationDown), isNull);
    expect(ZwiftButtons.navigationDown.action, InGameAction.down);
    expect(supportedActions, contains(InGameAction.down));
  });
}
