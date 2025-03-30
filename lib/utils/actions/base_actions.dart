import 'dart:ui';

import 'package:accessibility/accessibility.dart';

import '../keymap/keymap.dart';

abstract class BaseActions {
  Keymap? get keymap => null;
  Offset? get gearUpTouchPosition => null;
  Offset? get gearDownTouchPosition => null;

  void init(Keymap? keymap) {}
  void increaseGear();
  void decreaseGear();

  void controlMedia(MediaAction action) {
    throw UnimplementedError();
  }

  void updateTouchPositions(Offset gearUp, Offset gearDown) {}
}

class StubActions extends BaseActions {
  @override
  void decreaseGear() {
    print('Decrease gear');
  }

  @override
  void increaseGear() {
    print('Increase gear');
  }
}
