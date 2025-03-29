import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:swift_control/utils/actions/base_actions.dart';

import '../keymap/keymap.dart';

class DesktopActions extends BaseActions {
  Keymap? _keymap;

  @override
  Keymap? get keymap => _keymap;

  @override
  void init(Keymap? keymap) {
    _keymap = keymap;
  }

  @override
  void decreaseGear() {
    if (keymap == null) {
      throw Exception('Keymap is not set');
    }
    keyPressSimulator.simulateKeyDown(_keymap!.decrease);
    //keyPressSimulator.simulateKeyUp(_keymap!.decrease);
  }

  @override
  void increaseGear() {
    if (keymap == null) {
      throw Exception('Keymap is not set');
    }
    keyPressSimulator.simulateKeyDown(_keymap!.increase);
    //keyPressSimulator.simulateKeyUp(_keymap!.increase);
  }
}
