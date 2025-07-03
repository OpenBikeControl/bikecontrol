import 'package:flutter/services.dart';
import 'package:keypress_simulator_platform_interface/src/keypress_simulator_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

abstract class KeyPressSimulatorPlatform extends PlatformInterface {
  /// Constructs a KeyPressSimulatorPlatform.
  KeyPressSimulatorPlatform() : super(token: _token);

  static final Object _token = Object();

  static KeyPressSimulatorPlatform _instance = MethodChannelKeyPressSimulator();

  /// The default instance of [KeyPressSimulatorPlatform] to use.
  ///
  /// Defaults to [MethodChannelKeyPressSimulator].
  static KeyPressSimulatorPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [KeyPressSimulatorPlatform] when
  /// they register themselves.
  static set instance(KeyPressSimulatorPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<bool> isAccessAllowed() {
    throw UnimplementedError('isAccessAllowed() has not been implemented.');
  }

  Future<void> requestAccess({
    bool onlyOpenPrefPane = false,
  }) {
    throw UnimplementedError('requestAccess() has not been implemented.');
  }

  Future<void> simulateKeyPress({
    KeyboardKey? key,
    List<ModifierKey> modifiers = const [],
    bool keyDown = true,
  }) {
    throw UnimplementedError('simulateKeyPress() has not been implemented.');
  }

  Future<void> simulateKeyPressToWindow({
    KeyboardKey? key,
    List<ModifierKey> modifiers = const [],
    bool keyDown = true,
    String? processName,
    String? windowTitle,
  }) {
    throw UnimplementedError('simulateKeyPressToWindow() has not been implemented.');
  }

  Future<void> simulateMouseClick(Offset position) {
    throw UnimplementedError('simulateKeyPress() has not been implemented.');
  }
}
