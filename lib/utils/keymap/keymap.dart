import 'dart:convert';
import 'dart:ui';

import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

class Keymap {
  static Keymap custom = Keymap(keyPairs: []);

  List<KeyPair> keyPairs;

  Keymap({required this.keyPairs});

  @override
  String toString() {
    return keyPairs.joinToString(
      separator: ('\n---------\n'),
      transform:
          (k) =>
              '''Button: ${k.buttons.joinToString(transform: (e) => e.name)}\nKeyboard key: ${k.logicalKey?.keyLabel ?? 'Not assigned'}\nAction: ${k.buttons.firstOrNull?.action}${k.touchPosition != Offset.zero ? '\nTouch Position: ${k.touchPosition.toString()}' : ''}${k.isLongPress ? '\nLong Press: Enabled' : ''}''',
    );
  }

  PhysicalKeyboardKey? getPhysicalKey(ZwiftButton action) {
    // get the key pair by in game action
    return keyPairs.firstOrNullWhere((element) => element.buttons.contains(action))?.physicalKey;
  }

  KeyPair? getKeyPair(ZwiftButton action) {
    // get the key pair by in game action
    return keyPairs.firstOrNullWhere((element) => element.buttons.contains(action));
  }

  void reset() {
    keyPairs = [];
  }
}

class KeyPair {
  final List<ZwiftButton> buttons;
  PhysicalKeyboardKey? physicalKey;
  LogicalKeyboardKey? logicalKey;
  Offset touchPosition;
  bool isLongPress;

  KeyPair({
    required this.buttons,
    required this.physicalKey,
    required this.logicalKey,
    this.touchPosition = Offset.zero,
    this.isLongPress = false,
  });

  bool get isSpecialKey =>
      physicalKey == PhysicalKeyboardKey.mediaPlayPause ||
      physicalKey == PhysicalKeyboardKey.mediaTrackNext ||
      physicalKey == PhysicalKeyboardKey.mediaTrackPrevious ||
      physicalKey == PhysicalKeyboardKey.mediaStop ||
      physicalKey == PhysicalKeyboardKey.audioVolumeUp ||
      physicalKey == PhysicalKeyboardKey.audioVolumeDown;

  @override
  String toString() {
    return logicalKey?.keyLabel ??
        switch (physicalKey) {
          PhysicalKeyboardKey.mediaPlayPause => 'Play/Pause',
          PhysicalKeyboardKey.mediaTrackNext => 'Next Track',
          PhysicalKeyboardKey.mediaTrackPrevious => 'Previous Track',
          PhysicalKeyboardKey.mediaStop => 'Stop',
          PhysicalKeyboardKey.audioVolumeUp => 'Volume Up',
          PhysicalKeyboardKey.audioVolumeDown => 'Volume Down',
          _ => 'Not assigned',
        };
  }

  String encode() {
    // encode to save in preferences
    // Always store as percentages for better compatibility across devices
    final Map<String, double> touchPosData;
    
    if (touchPosition == Offset.zero) {
      // Special case: zero position means no touch (e.g., keyboard shortcut only)
      touchPosData = {
        'x_percent': 0.0,
        'y_percent': 0.0,
      };
    } else {
      // Get screen size for conversion
      Size? screenSize;
      try {
        final view = WidgetsBinding.instance.platformDispatcher.views.first;
        screenSize = view.physicalSize / view.devicePixelRatio;
      } catch (e) {
        // Fallback: if no screen size available, use a reasonable default (1920x1080)
        screenSize = null;
      }
      
      if (screenSize != null) {
        // Normal case: convert pixels to percentages
        touchPosData = {
          'x_percent': touchPosition.dx / screenSize.width,
          'y_percent': touchPosition.dy / screenSize.height,
        };
      } else {
        // Fallback to default screen size
        touchPosData = {
          'x_percent': touchPosition.dx / 1920.0,
          'y_percent': touchPosition.dy / 1080.0,
        };
      }
    }
    
    return jsonEncode({
      'actions': buttons.map((e) => e.name).toList(),
      'logicalKey': logicalKey?.keyId.toString() ?? '0',
      'physicalKey': physicalKey?.usbHidUsage.toString() ?? '0',
      'touchPosition': touchPosData,
      'isLongPress': isLongPress,
    });
  }

  static KeyPair? decode(String data) {
    // decode from preferences
    final decoded = jsonDecode(data);
    if (decoded['actions'] == null || decoded['logicalKey'] == null || decoded['physicalKey'] == null) {
      return null;
    }
    
    // Support both percentage-based (new) and pixel-based (old) formats for backward compatibility
    final touchPosData = decoded['touchPosition'];
    final Offset touchPosition;
    
    if (touchPosData.containsKey('x_percent') && touchPosData.containsKey('y_percent')) {
      // New percentage-based format - convert to pixels
      Size? screenSize;
      try {
        final view = WidgetsBinding.instance.platformDispatcher.views.first;
        screenSize = view.physicalSize / view.devicePixelRatio;
      } catch (e) {
        screenSize = null;
      }
      
      if (screenSize != null) {
        touchPosition = Offset(
          touchPosData['x_percent'] * screenSize.width,
          touchPosData['y_percent'] * screenSize.height,
        );
      } else {
        // Fallback if no screen size available
        touchPosition = Offset.zero;
      }
    } else {
      // Old pixel-based format - read the pixels directly
      // These will be converted to percentages when saved next time
      touchPosition = Offset(
        (touchPosData['x'] as num).toDouble(),
        (touchPosData['y'] as num).toDouble(),
      );
    }
    
    return KeyPair(
      buttons:
          decoded['actions']
              .map<ZwiftButton>((e) => ZwiftButton.values.firstWhere((element) => element.name == e))
              .toList(),
      logicalKey: int.parse(decoded['logicalKey']) != 0 ? LogicalKeyboardKey(int.parse(decoded['logicalKey'])) : null,
      physicalKey:
          int.parse(decoded['physicalKey']) != 0 ? PhysicalKeyboardKey(int.parse(decoded['physicalKey'])) : null,
      touchPosition: touchPosition,
      isLongPress: decoded['isLongPress'] ?? false,
    );
  }
}
