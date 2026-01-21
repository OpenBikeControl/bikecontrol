// OpenBikeControl Protocol Parser (Dart)

// This file is a translation of the Python `protocol_parser.py` example into Dart.
// It provides simple encoding/decoding utilities for the OpenBikeControl message
// types used in the Python example. This is intentionally a small, focused
// module that mirrors the original Python API.

import 'dart:convert';
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/zwift/ftms_mdns_emulator.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:dartx/dartx.dart';

class ProtocolParseException implements Exception {
  final String message;
  final Uint8List? raw;
  ProtocolParseException(this.message, [this.raw]);

  @override
  String toString() => 'ProtocolParseException: $message${raw != null ? ' raw=${bytesToReadableHex(raw!)}' : ''}';
}

class OpenBikeProtocolParser {
  // Button ID to name mapping (based on PROTOCOL.md in Python example)
  static const Map<int, ControllerButton> BUTTON_NAMES = {
    // Gear Shifting (0x01-0x0F)
    0x01: ControllerButton('Shift Up', identifier: 0x01, action: InGameAction.shiftUp),
    0x02: ControllerButton('Shift Down', identifier: 0x02, action: InGameAction.shiftDown),
    0x03: ControllerButton('Gear Set', identifier: 0x03),
    // Navigation (0x10-0x1F)
    0x10: ControllerButton('Up', identifier: 0x10, action: InGameAction.up),
    0x11: ControllerButton('Down', identifier: 0x11, action: InGameAction.down),
    0x12: ControllerButton('Left/Look Left', identifier: 0x12, action: InGameAction.navigateLeft),
    0x13: ControllerButton('Right/Look Right', identifier: 0x13, action: InGameAction.navigateRight),
    0x14: ControllerButton('Select/Confirm', identifier: 0x14, action: InGameAction.select),
    0x15: ControllerButton('Back/Cancel', identifier: 0x15, action: InGameAction.back),
    0x16: ControllerButton('Menu', identifier: 0x16, action: InGameAction.menu),
    0x17: ControllerButton('Home', identifier: 0x17, action: InGameAction.home),
    0x18: ControllerButton('Steer Left', identifier: 0x18, action: InGameAction.steerLeft),
    0x19: ControllerButton('Steer Right', identifier: 0x19, action: InGameAction.steerRight),
    // Social/Emotes (0x20-0x2F)
    0x20: ControllerButton('Emote', identifier: 0x20, action: InGameAction.emote),
    0x21: ControllerButton('Push to Talk', identifier: 0x21),
    // Training Controls (0x30-0x3F)
    0x30: ControllerButton('ERG Up', identifier: 0x30, action: InGameAction.increaseResistance),
    0x31: ControllerButton('ERG Down', identifier: 0x31, action: InGameAction.decreaseResistance),
    0x32: ControllerButton('Skip Interval', identifier: 0x32),
    0x33: ControllerButton('Pause', identifier: 0x33),
    0x34: ControllerButton('Resume', identifier: 0x34),
    0x35: ControllerButton('Lap', identifier: 0x35),
    // View Controls (0x40-0x4F)
    0x40: ControllerButton('Camera Angle', identifier: 0x40, action: InGameAction.cameraAngle),
    0x41: ControllerButton('Camera 1', identifier: 0x41, action: InGameAction.cameraAngle),
    0x42: ControllerButton('Camera 2', identifier: 0x42, action: InGameAction.cameraAngle),
    0x43: ControllerButton('Camera 3', identifier: 0x43, action: InGameAction.cameraAngle),
    0x44: ControllerButton('HUD Toggle', identifier: 0x44, action: InGameAction.toggleUi),
    0x45: ControllerButton('Map Toggle', identifier: 0x45),
    // Power-ups (0x50-0x5F)
    0x50: ControllerButton('Power-up 1', identifier: 0x50, action: InGameAction.usePowerUp),
    0x51: ControllerButton('Power-up 2', identifier: 0x51, action: InGameAction.usePowerUp),
    0x52: ControllerButton('Power-up 3', identifier: 0x52, action: InGameAction.usePowerUp),
  };

  // Haptic feedback patterns
  static const Map<String, int> HAPTIC_PATTERNS = {
    'none': 0x00,
    'short': 0x01,
    'double': 0x02,
    'triple': 0x03,
    'long': 0x04,
    'success': 0x05,
    'warning': 0x06,
    'error': 0x07,
  };

  // Message types (for TCP/mDNS protocol)
  static const int MSG_TYPE_BUTTON_STATE = 0x01;
  static const int MSG_TYPE_DEVICE_STATUS = 0x02;
  static const int MSG_TYPE_HAPTIC_FEEDBACK = 0x03;
  static const int MSG_TYPE_APP_INFO = 0x04;

  /// Parse button state data from binary format.
  /// Data format: [Message_Type, Button_ID_1, State_1, Button_ID_2, State_2, ...]
  static List<ButtonState> parseButtonState(Uint8List data) {
    final buttons = <ButtonState>[];

    if (data.isEmpty) return buttons;

    if (data[0] != MSG_TYPE_BUTTON_STATE) return buttons;

    for (var i = 1; i < data.length; i += 2) {
      if (i + 1 < data.length) {
        final buttonId = data[i];
        final state = data[i + 1];
        if (BUTTON_NAMES[buttonId] != null) {
          buttons.add(ButtonState(BUTTON_NAMES[buttonId]!, state));
        } else {
          throw ProtocolParseException('Unknown button ID: 0x${buttonId.toRadixString(16).padLeft(2, '0')}', data);
        }
      }
    }

    return buttons;
  }

  static Uint8List encodeButtonState(List<ButtonState> buttons) {
    final bytes = BytesBuilder();
    bytes.addByte(MSG_TYPE_BUTTON_STATE);
    for (final b in buttons) {
      bytes.addByte(b.button.identifier!);
      bytes.addByte(b.state);
    }
    return bytes.toBytes();
  }

  static DeviceStatus parseDeviceStatus(Uint8List data) {
    if (data.length < 3) {
      throw ProtocolParseException('Device status message too short', data);
    }
    if (data[0] != MSG_TYPE_DEVICE_STATUS) {
      throw ProtocolParseException('Invalid message type: ${data[0]}, expected $MSG_TYPE_DEVICE_STATUS', data);
    }
    final battery = data[1] == 0xFF ? null : data[1];
    final connected = data[2] == 0x01;
    return DeviceStatus(battery: battery, connected: connected);
  }

  static Uint8List encodeDeviceStatus({int? battery, bool connected = true}) {
    final batteryByte = battery == null ? 0xFF : (battery & 0xFF);
    final connectedByte = connected ? 0x01 : 0x00;
    return Uint8List.fromList([MSG_TYPE_DEVICE_STATUS, batteryByte, connectedByte]);
  }

  static Uint8List encodeHapticFeedback({String pattern = 'short', int duration = 0, int intensity = 0}) {
    final patternByte = HAPTIC_PATTERNS[pattern] ?? HAPTIC_PATTERNS['short']!;
    final bytes = Uint8List(4);
    bytes[0] = MSG_TYPE_HAPTIC_FEEDBACK;
    bytes[1] = patternByte;
    bytes[2] = duration & 0xFF;
    bytes[3] = intensity & 0xFF;
    return bytes;
  }

  static HapticFeedbackMessage parseHapticFeedback(Uint8List data) {
    if (data.length < 4) {
      throw ProtocolParseException('Haptic feedback message too short', data);
    }
    if (data[0] != MSG_TYPE_HAPTIC_FEEDBACK) {
      throw ProtocolParseException('Invalid message type: ${data[0]}', data);
    }
    final patternByte = data[1];
    final duration = data[2];
    final intensity = data[3];
    String patternName = 'unknown';
    HAPTIC_PATTERNS.forEach((name, value) {
      if (value == patternByte) patternName = name;
    });

    return HapticFeedbackMessage(
      pattern: patternName,
      patternByte: patternByte,
      duration: duration,
      intensity: intensity,
    );
  }

  static Uint8List encodeAppInfo({
    required String appId,
    required String appVersion,
    required List<ControllerButton> supportedButtons,
  }) {
    final appIdBytes = utf8.encode(appId).take(32).toList();
    final appVersionBytes = utf8.encode(appVersion).take(32).toList();

    final builder = BytesBuilder();
    builder.addByte(MSG_TYPE_APP_INFO);
    builder.addByte(0x01); // Version
    builder.addByte(appIdBytes.length);
    builder.add(appIdBytes);
    builder.addByte(appVersionBytes.length);
    builder.add(appVersionBytes);
    builder.addByte(supportedButtons.length);
    builder.add(supportedButtons.map((e) => e.identifier!).toList());

    return builder.toBytes();
  }

  static AppInfo parseAppInfo(Uint8List data) {
    if (data.isEmpty || data[0] != MSG_TYPE_APP_INFO) {
      throw ProtocolParseException('Invalid message type', data);
    }

    var idx = 1;
    if (data.length < idx + 3) {
      throw ProtocolParseException('App info message too short', data);
    }

    final version = data[idx];
    idx += 1;
    if (version != 0x01) {
      throw ProtocolParseException('Unsupported app info version: $version', data);
    }

    if (idx >= data.length) throw ProtocolParseException('Missing app ID length', data);
    final appIdLen = data[idx];
    idx += 1;
    if (idx + appIdLen > data.length) throw ProtocolParseException('App ID length exceeds buffer', data);
    final appId = utf8.decode(data.sublist(idx, idx + appIdLen));
    idx += appIdLen;

    if (idx >= data.length) throw ProtocolParseException('Missing app version length', data);
    final appVersionLen = data[idx];
    idx += 1;
    if (idx + appVersionLen > data.length) throw ProtocolParseException('App version length exceeds buffer', data);
    final appVersion = utf8.decode(data.sublist(idx, idx + appVersionLen));
    idx += appVersionLen;

    if (idx >= data.length) throw ProtocolParseException('Missing button count', data);
    final buttonCount = data[idx];
    idx += 1;
    if (idx + buttonCount > data.length) throw ProtocolParseException('Button count exceeds buffer', data);
    final buttonIds = data.sublist(idx, idx + buttonCount).toList();

    final controllerButtons = buttonIds.mapNotNull((id) => BUTTON_NAMES[id]).toList();

    return AppInfo(
      appId: appId,
      appVersion: appVersion,
      supportedButtons: controllerButtons,
      supportedActions: controllerButtons.mapNotNull((b) => b.action).toList(),
    );
  }
}

class AppInfo {
  final String appId;
  final String appVersion;
  final List<ControllerButton> supportedButtons;
  final List<InGameAction> supportedActions;

  AppInfo({
    required this.appId,
    required this.appVersion,
    required this.supportedButtons,
    required this.supportedActions,
  });

  @override
  String toString() =>
      'AppInfo(appId: $appId, appVersion: $appVersion, supportedButtons: $supportedButtons, supportedActions: $supportedActions)';
}

/// DeviceStatus message representation
class DeviceStatus {
  final int? battery; // 0-100, null if 0xFF
  final bool connected;

  DeviceStatus({required this.battery, required this.connected});

  @override
  String toString() => 'DeviceStatus(battery: ${battery ?? 'unknown'}, connected: $connected)';
}

class ButtonState {
  /// Represents a single button id/state pair.class ButtonState {
  final ControllerButton button;
  final int state; // 0=released,1=pressed,2-255=analog

  const ButtonState(this.button, this.state);

  @override
  String toString() => formatButtonState(button, state);

  String formatButtonState(ControllerButton button, int state) {
    final buttonName = button.name;

    String stateStr;
    if (state == 0) {
      stateStr = 'RELEASED';
    } else if (state == 1) {
      stateStr = 'PRESSED';
    } else {
      final percentage = ((state - 2) / (255 - 2) * 100).round();
      stateStr = 'ANALOG $percentage%';
    }

    return '$buttonName: $stateStr';
  }
}

/// Haptic feedback representation
class HapticFeedbackMessage {
  final String pattern;
  final int patternByte;
  final int duration; // in 10ms units
  final int intensity; // 0-255

  HapticFeedbackMessage({
    required this.pattern,
    required this.patternByte,
    required this.duration,
    required this.intensity,
  });

  @override
  String toString() => 'HapticFeedback(pattern: $pattern, duration: $duration, intensity: $intensity)';
}
