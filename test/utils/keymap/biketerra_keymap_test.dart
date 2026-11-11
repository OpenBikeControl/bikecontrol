import 'package:bike_control/bluetooth/devices/elite/elite_square.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/utils/keymap/apps/biketerra.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Biketerra is reached over OpenBikeControl Bluetooth, and
/// `BaseActions._handleDirectConnect` only forwards a [KeyPair] that carries an
/// [InGameAction]. A default that maps a shifter to a keyboard key only can
/// never leave the phone on iOS/Android, so every press ended as
/// "No connection method active".
void main() {
  final app = Biketerra();

  test('every default key pair carries the in-game action of its buttons', () {
    for (final keyPair in app.keymap.keyPairs) {
      for (final button in keyPair.buttons) {
        expect(
          keyPair.inGameAction,
          button.action,
          reason: '${button.name} can never reach Biketerra over OpenBikeControl',
        );
      }
    }
  });

  test('Elite Square shifters shift over OpenBikeControl', () {
    InGameAction? actionFor(ControllerButton button) =>
        app.keymap.getKeyPair(button, trigger: ButtonTrigger.singleClick)?.inGameAction;

    expect(actionFor(EliteSquareButtons.rightShift1), InGameAction.shiftUp);
    expect(actionFor(EliteSquareButtons.leftShift1), InGameAction.shiftUp);
    expect(actionFor(ZwiftButtons.shiftUpRight), InGameAction.shiftUp);
    expect(actionFor(ZwiftButtons.shiftDownLeft), InGameAction.shiftDown);
  });

  test('the keyboard shortcuts stay as the fallback', () {
    final shiftUp = app.keymap.getKeyPair(ZwiftButtons.shiftUpRight, trigger: ButtonTrigger.singleClick)!;
    expect(shiftUp.physicalKey, PhysicalKeyboardKey.keyW);
    final shiftDown = app.keymap.getKeyPair(ZwiftButtons.shiftDownLeft, trigger: ButtonTrigger.singleClick)!;
    expect(shiftDown.physicalKey, PhysicalKeyboardKey.keyS);
  });
}
