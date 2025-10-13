import 'dart:collection';
import 'dart:typed_data';

import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:universal_ble/universal_ble.dart';

class WahooKickrBikeShift extends BaseDevice {
  WahooKickrBikeShift(super.scanResult)
    : super(
        availableButtons: WahooKickrBikeShiftConstants.prefixToButton.values.toList(),
        isBeta: true,
      );

  @override
  Future<void> handleServices(List<BleService> services) async {
    final service = services.firstWhere(
      (e) => e.uuid == WahooKickrBikeShiftConstants.SERVICE_UUID,
      orElse: () => throw Exception('Service not found: ${WahooKickrBikeShiftConstants.SERVICE_UUID}'),
    );
    final characteristic = service.characteristics.firstWhere(
      (e) => e.uuid == WahooKickrBikeShiftConstants.CHARACTERISTIC_UUID,
      orElse: () => throw Exception('Characteristic not found: ${WahooKickrBikeShiftConstants.CHARACTERISTIC_UUID}'),
    );

    await UniversalBle.subscribeNotifications(device.deviceId, service.uuid, characteristic.uuid);
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) {
    if (characteristic == WahooKickrBikeShiftConstants.CHARACTERISTIC_UUID) {
      final hex = toHex(bytes);

      // Short-frame detection (hard-coded families)
      final s = parseShortFrame(hex);
      if (s != null) {
        if (s.pressed) {
          handleButtonsClicked([s.button]);
        } else {
          handleButtonsClicked([]);
        }
        return Future.value();
      }
    }
    return Future.value();
  }

  // Deduplicate per (prefix, type) using the 7-bit rolling sequence
  final Map<String, int> lastSeqByPrefix = HashMap<String, int>();

  String toHex(Uint8List bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();

  // Parse short frames like "PPQQRR" (e.g., "0001E6", "80005E", "40008F", "010004")
  ShortFrame? parseShortFrame(String hex) {
    final re = RegExp(r'^[0-9A-F]{6}$', caseSensitive: false);
    if (!re.hasMatch(hex)) return null;

    final prefix = hex.substring(0, 4); // PPQQ
    final rrHex = hex.substring(4, 6); // RR
    if (!WahooKickrBikeShiftConstants.prefixToButton.containsKey(prefix)) return null;

    final idx = int.parse(rrHex, radix: 16);
    final type = (idx & 0x80) != 0 ? true : false; // MSB of RR
    final seq = idx & 0x7F; // rolling counter for dedupe

    return ShortFrame(
      prefix: prefix,
      rrHex: rrHex,
      idx: idx,
      pressed: type,
      seq: seq,
      button: WahooKickrBikeShiftConstants.prefixToButton[prefix]!,
    );
  }

  bool isLongFrame(String hex) {
    final re = RegExp(r'^FF0F01', caseSensitive: false);
    return re.hasMatch(hex);
  }

  // Returns true if this (prefix,type,seq) has not been handled yet
  bool shouldHandleOnce(String prefix, String type, int seq) {
    final key = '$prefix:$type';
    final last = lastSeqByPrefix[key];
    if (last == seq) return false;
    lastSeqByPrefix[key] = seq;
    return true;
  }
}

class ShortFrame {
  final String prefix; // PPQQ
  final String rrHex; // RR
  final int idx;
  final bool pressed;
  final int seq;
  final ControllerButton button;

  ShortFrame({
    required this.prefix,
    required this.rrHex,
    required this.idx,
    required this.pressed,
    required this.seq,
    required this.button,
  });
}

class WahooKickrBikeShiftConstants {
  static const String SERVICE_UUID = "a026ee0d-0a7d-4ab3-97fa-f1500f9feb8b";
  static const String CHARACTERISTIC_UUID = "a026e03c-0a7d-4ab3-97fa-f1500f9feb8b";

  // https://support.wahoofitness.com/hc/en-us/articles/22259367275410-Shifter-and-button-configuration-for-KICKR-BIKE-1-2
  static const Map<String, ControllerButton> prefixToButton = {
    '0001': ControllerButton.powerUpRight, //'Right Up',
    '8000': ControllerButton.sideButtonRight, //'Right Down',
    '0008': ControllerButton.navigationRight, //'Right Steer',
    '0200': ControllerButton.powerUpLeft, // 'Left Up',
    '0400': ControllerButton.sideButtonLeft, //'Left Down',
    '2000': ControllerButton.navigationLeft, //'Left Steer',
    '0004': ControllerButton.shiftUpRight, // 'Right Shift Up',
    '0002': ControllerButton.shiftDownRight, // 'Right Shift Down',
    '1000': ControllerButton.shiftUpLeft, //'Left Shift Up',
    '0800': ControllerButton.shiftDownLeft, //'Left Shift Down',
    '4000': ControllerButton.paddleRight, //'Right Brake',
    '0100': ControllerButton.paddleLeft, //'Left Brake',
  };
}
