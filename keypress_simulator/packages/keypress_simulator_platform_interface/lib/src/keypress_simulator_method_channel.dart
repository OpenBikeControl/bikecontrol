import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:keypress_simulator_platform_interface/src/keypress_simulator_platform_interface.dart';
import 'package:uni_platform/uni_platform.dart';

/// An implementation of [KeyPressSimulatorPlatform] that uses method channels.
class MethodChannelKeyPressSimulator extends KeyPressSimulatorPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel(
    'dev.leanflutter.plugins/keypress_simulator',
  );

  @override
  Future<bool> isAccessAllowed() async {
    if (UniPlatform.isMacOS) {
      return await methodChannel.invokeMethod('isAccessAllowed');
    }
    return true;
  }

  @override
  Future<void> requestAccess({
    bool onlyOpenPrefPane = false,
  }) async {
    if (UniPlatform.isMacOS) {
      final Map<String, dynamic> arguments = {
        'onlyOpenPrefPane': onlyOpenPrefPane,
      };
      await methodChannel.invokeMethod('requestAccess', arguments);
    }
  }

  @override
  Future<void> simulateKeyPress({
    KeyboardKey? key,
    List<ModifierKey> modifiers = const [],
    bool keyDown = true,
  }) async {
    PhysicalKeyboardKey? physicalKey = key is PhysicalKeyboardKey ? key : null;
    if (key is LogicalKeyboardKey) {
      physicalKey = key.physicalKey;
    }
    if (key != null && physicalKey == null) {
      throw UnsupportedError('Unsupported key: $key.');
    }
    final Map<Object?, Object?> arguments = {
      'keyCode': physicalKey?.keyCode,
      'modifiers': modifiers.map((e) => e.name).toList(),
      'keyDown': keyDown,
    }..removeWhere((key, value) => value == null);
    await methodChannel.invokeMethod('simulateKeyPress', arguments);
  }

  @override
  Future<void> simulateMouseClick(Offset position) async {
    final Map<String, double> arguments = {
      'x': position.dx,
      'y': position.dy,
    };
    await methodChannel.invokeMethod('simulateMouseClick', arguments);
  }
}
