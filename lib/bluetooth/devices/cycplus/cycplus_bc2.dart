import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth_device.dart';

class CycplusBc2 extends BluetoothDevice {
  CycplusBc2(super.scanResult)
    : super(
        availableButtons: CycplusBc2Buttons.values,
      );

  @override
  Future<void> handleServices(List<BleService> services) async {
    final service = services.firstWhere(
      (e) => e.uuid.toLowerCase() == CycplusBc2Constants.SERVICE_UUID.toLowerCase(),
      orElse: () => throw Exception('Service not found: ${CycplusBc2Constants.SERVICE_UUID}'),
    );
    final characteristic = service.characteristics.firstWhere(
      (e) => e.uuid.toLowerCase() == CycplusBc2Constants.TX_CHARACTERISTIC_UUID.toLowerCase(),
      orElse: () => throw Exception('Characteristic not found: ${CycplusBc2Constants.TX_CHARACTERISTIC_UUID}'),
    );

    await UniversalBle.subscribeNotifications(device.deviceId, service.uuid, characteristic.uuid);
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) {
    if (characteristic.toLowerCase() == CycplusBc2Constants.TX_CHARACTERISTIC_UUID.toLowerCase()) {
      if (bytes.isNotEmpty && bytes.length == 'FEEFFFEE02060303A2625D00016D'.length / 2) {
        final event = _decodeCycplusPacket(bytes);
        if (event != null) {
          handleButtonsClicked(
            [
              if (event.logicalButton == CycplusLogicalButton.left) CycplusBc2Buttons.shiftUp,
              if (event.logicalButton == CycplusLogicalButton.right) CycplusBc2Buttons.shiftDown,
            ],
          );
        }
      } else {
        actionStreamInternal.add(
          LogNotification(
            'CYCPLUS BC2 received unexpected packet: ${bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join()}',
          ),
        );
      }
    }
    return Future.value();
  }
}

enum CycplusLogicalButton {
  left,
  right,
  special, // e.g. long-press / other state
  unknown,
}

class CycplusButtonEvent {
  final bool validHeader;
  final int cmd;
  final int subCmd;

  /// Raw “button code” byte (index 6)
  final int rawButtonCode;

  /// Raw “action/mode” byte (index 7)
  final int rawActionCode;

  /// Monotonic counter built from bytes 8–9 (big endian)
  final int counter;

  /// Status byte (index 10), usually 0x5D or 0x5E in your samples
  final int status;

  /// Reserved bytes (index 11–12), often 0x00, 0x01 in your samples
  final int reserved1;
  final int reserved2;

  /// Raw checksum byte (index 13) – format unknown
  final int checksum;

  /// Heuristic mapping from rawButtonCode to a logical button
  final CycplusLogicalButton logicalButton;

  CycplusButtonEvent({
    required this.validHeader,
    required this.cmd,
    required this.subCmd,
    required this.rawButtonCode,
    required this.rawActionCode,
    required this.counter,
    required this.status,
    required this.reserved1,
    required this.reserved2,
    required this.checksum,
    required this.logicalButton,
  });

  @override
  String toString() {
    return 'CycplusButtonEvent('
        'validHeader: $validHeader, '
        'cmd: 0x${cmd.toRadixString(16)}, '
        'subCmd: 0x${subCmd.toRadixString(16)}, '
        'rawButtonCode: 0x${rawButtonCode.toRadixString(16)}, '
        'rawActionCode: 0x${rawActionCode.toRadixString(16)}, '
        'counter: $counter, '
        'status: 0x${status.toRadixString(16)}, '
        'reserved1: 0x${reserved1.toRadixString(16)}, '
        'reserved2: 0x${reserved2.toRadixString(16)}, '
        'checksum: 0x${checksum.toRadixString(16)}, '
        'logicalButton: $logicalButton'
        ')';
  }
}

/// Decode a single CYCPLUS BC2 button packet.
///
/// Returns `null` if the packet doesn’t match the expected frame structure.
/// Otherwise returns a [CycplusButtonEvent] with decoded fields.
///
/// Expected layout (14 bytes total):
/// [0]  0xFE  -
/// [1]  0xEF  - header
/// [2]  0xFF  -
/// [3]  0xEE  -
/// [4]  cmd      (0x02 in your samples)
/// [5]  subCmd   (0x06 in your samples)
/// [6]  rawButtonCode  (01 / 03 / 02 ... -> which button/type)
/// [7]  rawActionCode  (03 / 01 / 02 ... -> mode/press-type)
/// [8]  counter high byte
/// [9]  counter low byte
/// [10] status (0x5D / 0x5E ...)
/// [11] reserved1
/// [12] reserved2
/// [13] checksum (format not yet reverse-engineered)
CycplusButtonEvent? _decodeCycplusPacket(Uint8List bytes) {
  if (bytes.length < 14) {
    return null;
  }

  final bool headerOk = bytes[0] == 0xFE && bytes[1] == 0xEF && bytes[2] == 0xFF && bytes[3] == 0xEE;

  if (!headerOk) {
    return null;
  }

  final int cmd = bytes[4];
  final int subCmd = bytes[5];

  // If you only care about the 0x02 0x06 packets, you can enforce that:
  if (cmd != 0x02 || subCmd != 0x06) {
    return null; // or keep going if you want to support more types
  }

  final int rawButtonCode = bytes[6];
  final int rawActionCode = bytes[7];

  // Counter is clearly monotonic when interpreted as big-endian 16-bit
  final int counter = (bytes[8] << 8) | bytes[9];

  final int status = bytes[10];
  final int reserved1 = bytes[11];
  final int reserved2 = bytes[12];
  final int checksum = bytes[13];

  // Heuristic mapping from the raw button code:
  // In your captures this toggles mostly between 0x01 and 0x03
  // as the user alternates the two physical buttons.
  final CycplusLogicalButton logicalButton;
  switch (rawButtonCode) {
    case 0x01:
      logicalButton = CycplusLogicalButton.left;
      break;
    case 0x03:
      logicalButton = CycplusLogicalButton.right;
      break;
    case 0x02:
      // Seen in a few frames; likely a long-press/special state.
      logicalButton = CycplusLogicalButton.special;
      break;
    default:
      logicalButton = CycplusLogicalButton.unknown;
      break;
  }

  return CycplusButtonEvent(
    validHeader: headerOk,
    cmd: cmd,
    subCmd: subCmd,
    rawButtonCode: rawButtonCode,
    rawActionCode: rawActionCode,
    counter: counter,
    status: status,
    reserved1: reserved1,
    reserved2: reserved2,
    checksum: checksum,
    logicalButton: logicalButton,
  );
}

class CycplusBc2Constants {
  // Nordic UART Service (NUS) - commonly used by CYCPLUS BC2
  static const String SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";

  // TX Characteristic - device sends data to app
  static const String TX_CHARACTERISTIC_UUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";

  // RX Characteristic - app sends data to device (not used for button reading)
  static const String RX_CHARACTERISTIC_UUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
}

class CycplusBc2Buttons {
  static const ControllerButton shiftUp = ControllerButton(
    'shiftUp',
    action: InGameAction.shiftUp,
    icon: Icons.add,
  );

  static const ControllerButton shiftDown = ControllerButton(
    'shiftDown',
    action: InGameAction.shiftDown,
    icon: Icons.remove,
  );

  static const List<ControllerButton> values = [
    shiftUp,
    shiftDown,
  ];
}
