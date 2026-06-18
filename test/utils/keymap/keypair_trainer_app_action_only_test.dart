import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Offset;
import 'package:flutter_test/flutter_test.dart';

/// [KeyPair.isTrainerAppActionOnly] decides whether a press whose delivery
/// failed should be reported as "trainer app not connected" (issue #367)
/// instead of falling back to the keyboard / touch path.
void main() {
  KeyPair keyPair({
    PhysicalKeyboardKey? physicalKey,
    LogicalKeyboardKey? logicalKey,
    Offset touch = Offset.zero,
    InGameAction? inGameAction,
    String? command,
    String? screenshotPath,
  }) {
    return KeyPair(
      buttons: const [ControllerButton('a')],
      physicalKey: physicalKey,
      logicalKey: logicalKey,
      touchPosition: touch,
      inGameAction: inGameAction,
      command: command,
      screenshotPath: screenshotPath,
    );
  }

  test('a pure in-game gear shift is trainer-app-only', () {
    expect(keyPair(inGameAction: InGameAction.shiftUp).isTrainerAppActionOnly, isTrue);
    expect(keyPair(inGameAction: InGameAction.shiftDown).isTrainerAppActionOnly, isTrue);
  });

  test('an in-game action with a keyboard fallback is NOT trainer-app-only', () {
    // Zwift navigation maps to both an in-game action and an arrow key — the
    // keyboard must still fire when the trainer-app link is down.
    expect(
      keyPair(inGameAction: InGameAction.openActionBar, physicalKey: PhysicalKeyboardKey.arrowUp)
          .isTrainerAppActionOnly,
      isFalse,
    );
  });

  test('a touch or command fallback excludes it', () {
    expect(keyPair(inGameAction: InGameAction.shiftUp, touch: const Offset(50, 50)).isTrainerAppActionOnly, isFalse);
    expect(keyPair(inGameAction: InGameAction.shiftUp, command: 'echo hi').isTrainerAppActionOnly, isFalse);
    expect(keyPair(inGameAction: InGameAction.shiftUp, screenshotPath: '/tmp').isTrainerAppActionOnly, isFalse);
  });

  test('outside-trainer-app actions (headwind / trainer-control) are excluded', () {
    // These target a proxy / accessory and are handled — with their own
    // errors — before the trainer-app delivery path.
    expect(keyPair(inGameAction: InGameAction.trainerSwitchMode).isTrainerAppActionOnly, isFalse);
    expect(keyPair(inGameAction: InGameAction.headwindSpeed).isTrainerAppActionOnly, isFalse);
  });

  test('a plain keyboard key with no in-game action is excluded', () {
    expect(keyPair(physicalKey: PhysicalKeyboardKey.space).isTrainerAppActionOnly, isFalse);
  });

  test('an empty keypair is excluded', () {
    expect(keyPair().isTrainerAppActionOnly, isFalse);
  });
}
