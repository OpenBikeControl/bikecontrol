import 'package:accessibility/accessibility.dart';
import 'package:flutter/services.dart';
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
    await keyPressSimulator.simulateKeyDown(_keymap!.decrease?.physicalKey);
    await keyPressSimulator.simulateKeyUp(_keymap!.decrease?.physicalKey);
  }

  @override
  Future<void> increaseGear() async {
    if (keymap == null) {
      throw Exception('Keymap is not set');
    }
    await keyPressSimulator.simulateKeyDown(_keymap!.increase?.physicalKey);
    await keyPressSimulator.simulateKeyUp(_keymap!.increase?.physicalKey);
  }

  @override
  Future<void> controlMedia(MediaAction action) async {
    final key = switch (action) {
      MediaAction.playPause => PhysicalKeyboardKey.mediaPlayPause,
      MediaAction.next => PhysicalKeyboardKey.mediaTrackNext,
      MediaAction.volumeUp => PhysicalKeyboardKey.audioVolumeUp,
      MediaAction.volumeDown => PhysicalKeyboardKey.audioVolumeDown,
    };
    await keyPressSimulator.simulateKeyDown(key);
    await keyPressSimulator.simulateKeyUp(key);
  }
}
