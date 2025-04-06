import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:keypress_simulator_platform_interface/keypress_simulator_platform_interface.dart';

class KeyPressSimulator {
  KeyPressSimulator._();

  /// The shared instance of [KeyPressSimulator].
  static final KeyPressSimulator instance = KeyPressSimulator._();

  KeyPressSimulatorPlatform get _platform => KeyPressSimulatorPlatform.instance;

  Future<bool> isAccessAllowed() {
    return _platform.isAccessAllowed();
  }

  Future<void> requestAccess({bool onlyOpenPrefPane = false}) {
    return _platform.requestAccess(onlyOpenPrefPane: onlyOpenPrefPane);
  }

  Future<void> simulateMouseClick(Offset position) {
    return _platform.simulateMouseClick(position);
  }

  /// Simulate key down.
  Future<void> simulateKeyDown(PhysicalKeyboardKey? key, [List<ModifierKey> modifiers = const []]) {
    return _platform.simulateKeyPress(key: key, modifiers: modifiers, keyDown: true);
  }

  /// Simulate key up.
  Future<void> simulateKeyUp(PhysicalKeyboardKey? key, [List<ModifierKey> modifiers = const []]) {
    return _platform.simulateKeyPress(key: key, modifiers: modifiers, keyDown: false);
  }

  @Deprecated('Please use simulateKeyDown & simulateKeyUp methods.')
  Future<void> simulateCtrlCKeyPress() async {
    const key = PhysicalKeyboardKey.keyC;
    final modifiers = Platform.isMacOS ? [ModifierKey.metaModifier] : [ModifierKey.controlModifier];
    await simulateKeyDown(key, modifiers);
    await simulateKeyUp(key, modifiers);
  }

  @Deprecated('Please use simulateKeyDown & simulateKeyUp methods.')
  Future<void> simulateCtrlVKeyPress() async {
    const key = PhysicalKeyboardKey.keyV;
    final modifiers = Platform.isMacOS ? [ModifierKey.metaModifier] : [ModifierKey.controlModifier];
    await simulateKeyDown(key, modifiers);
    await simulateKeyUp(key, modifiers);
  }
}

final keyPressSimulator = KeyPressSimulator.instance;
