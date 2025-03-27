import 'dart:io';

import 'package:flutter/foundation.dart';

import '../keymap/keymap.dart';
import 'android.dart';
import 'desktop.dart';

abstract class BaseActions {
  Keymap? get keymap => null;

  void init(Keymap? keymap) {}
  void increaseGear();
  void decreaseGear();
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

class ActionHandler {
  late BaseActions actions;

  ActionHandler() {
    if (kIsWeb) {
      actions = StubActions();
    } else if (Platform.isAndroid) {
      actions = AndroidActions();
    } else {
      actions = DesktopActions();
    }
  }

  Keymap? get keymap => actions.keymap;

  void init(Keymap? keymap) {
    actions.init(keymap);
  }

  void increaseGear() {
    actions.increaseGear();
  }

  void decreaseGear() {
    actions.decreaseGear();
  }
}
