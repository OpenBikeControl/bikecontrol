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
  Future<void> decreaseGear() async {
    if (keymap == null) {
      throw Exception('Keymap is not set');
    }
    await keyPressSimulator.simulateKeyDown(_keymap!.decrease);
    await keyPressSimulator.simulateKeyUp(_keymap!.decrease);
  }

  @override
  Future<void> increaseGear() async {
    if (keymap == null) {
      throw Exception('Keymap is not set');
    }
    await keyPressSimulator.simulateKeyDown(_keymap!.increase);
    await keyPressSimulator.simulateKeyUp(_keymap!.increase);
  }
}
