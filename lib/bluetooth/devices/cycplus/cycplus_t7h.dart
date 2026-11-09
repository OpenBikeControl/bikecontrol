import 'dart:typed_data';

import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons;
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth_device.dart';
import 'cycplus_bc2.dart';

/// The two shifters of a CYCPLUS T7 smart bike, "T7H-L…" (chainring) and
/// "T7H-R…" (cassette). They only reach a phone after being unpaired from the
/// bike in the CYCPLUS app; while paired, the bike holds the connection.
///
/// Observed frames on the Nordic UART TX characteristic, 4 bytes:
///   `AA b1 buttons checksum` (checksum = sum of the first three bytes)
/// `buttons`: bit 7 set on the right shifter, bits 0–4 the held buttons, so a
/// release is 00 (left) or 80 (right). `b1` varies between sessions and is not
/// used. A frame repeats while a button is held.
class CycplusT7h extends BluetoothDevice {
  CycplusT7h(super.scanResult)
    : super(
        availableButtons: CycplusT7hButtons.values,
        allowMultiple: true,
      );

  static bool matchesName(String? name) {
    final upper = name?.toUpperCase();
    return upper != null && (upper.startsWith('T7H-L') || upper.startsWith('T7H-R'));
  }

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

  static const _rightFlag = 0x80;

  /// The last held set, to skip the repeats a held button sends.
  int? _lastButtons;

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    if (characteristic.toLowerCase() != CycplusBc2Constants.TX_CHARACTERISTIC_UUID.toLowerCase()) {
      return;
    }
    final valid = bytes.length == 4 && bytes[0] == 0xAA && ((bytes[0] + bytes[1] + bytes[2]) & 0xFF) == bytes[3];
    if (!valid) {
      actionStreamInternal.add(
        LogNotification(
          'CYCPLUS T7H received unexpected packet: ${bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join()}',
        ),
      );
      return;
    }

    final buttons = bytes[2];
    if (buttons == _lastButtons) {
      return;
    }
    _lastButtons = buttons;

    final side = buttons & _rightFlag != 0 ? CycplusT7hButtons.right : CycplusT7hButtons.left;
    final held = [
      for (final MapEntry(key: bit, value: button) in side.entries)
        if (buttons & bit != 0) button,
    ];
    final unknown = buttons & ~_rightFlag & ~side.keys.fold(0, (a, b) => a | b);
    if (unknown != 0) {
      actionStreamInternal.add(
        LogNotification('CYCPLUS T7H unknown button bits: 0x${unknown.toRadixString(16).padLeft(2, '0')}'),
      );
    }
    await handleButtonsClicked(held);
  }
}

class CycplusT7hButtons {
  // Left shifter (chainring). Its shift down sits where the right shifter's
  // shift up does, so the two levers mirror each other.
  static const ControllerButton leftShiftUp = ControllerButton(
    'leftShiftUp',
    action: InGameAction.shiftDown,
    color: Colors.black,
    icon: LucideIcons.minus,
  );
  static const ControllerButton leftShiftDown = ControllerButton(
    'leftShiftDown',
    action: InGameAction.shiftUp,
    color: Colors.black,
    icon: LucideIcons.plus,
  );
  static const ControllerButton leftRearArrow = ControllerButton(
    'leftRearArrow',
    action: InGameAction.steerLeft,
    color: Colors.black,
    icon: LucideIcons.chevronLeft,
  );
  static const ControllerButton leftFrontArrow = ControllerButton(
    'leftFrontArrow',
    action: InGameAction.steerLeft,
    color: Colors.black,
    icon: LucideIcons.chevronsLeft,
  );

  // Right shifter (cassette).
  static const ControllerButton rightShiftUp = ControllerButton(
    'rightShiftUp',
    action: InGameAction.shiftUp,
    color: Colors.black,
    icon: LucideIcons.plus,
  );
  static const ControllerButton rightShiftDown = ControllerButton(
    'rightShiftDown',
    action: InGameAction.shiftDown,
    color: Colors.black,
    icon: LucideIcons.minus,
  );
  static const ControllerButton rightRearArrow = ControllerButton(
    'rightRearArrow',
    action: InGameAction.steerRight,
    color: Colors.black,
    icon: LucideIcons.chevronRight,
  );
  static const ControllerButton rightFrontArrow = ControllerButton(
    'rightFrontArrow',
    action: InGameAction.steerRight,
    color: Colors.black,
    icon: LucideIcons.chevronsRight,
  );

  /// Button bit → button, per side.
  static const Map<int, ControllerButton> left = {
    0x01: leftShiftUp,
    0x02: leftShiftDown,
    0x08: leftRearArrow,
    0x10: leftFrontArrow,
  };
  static const Map<int, ControllerButton> right = {
    0x01: rightShiftUp,
    0x02: rightShiftDown,
    0x08: rightRearArrow,
    0x10: rightFrontArrow,
  };

  static const List<ControllerButton> values = [
    leftShiftUp,
    leftShiftDown,
    leftRearArrow,
    leftFrontArrow,
    rightShiftUp,
    rightShiftDown,
    rightRearArrow,
    rightFrontArrow,
  ];
}
