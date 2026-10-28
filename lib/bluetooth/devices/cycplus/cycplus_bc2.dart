import 'dart:typed_data';

import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/controller/controller_layout.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons;
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth_device.dart';

class CycplusBc2 extends BluetoothDevice {
  CycplusBc2(super.scanResult)
    : super(
        availableButtons: CycplusBc2Buttons.values,
        allowMultiple: true,
      );

  @override
  ControllerLayout get controllerLayout => ControllerLayout(
    aspectRatio: 1.25,
    shape: ContourShape.pill,
    svgAsset: 'assets/contours/cycpluc_bc2.svg',
    positions: {
      CycplusBc2Buttons.shiftUp: const Offset(0.3, 0.48),
      CycplusBc2Buttons.shiftDown: const Offset(0.7, 0.48),
    },
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

  // Each lever reports a state byte (6 = shift up, 7 = shift down) and an
  // event counter (8 = shift up, 9 = shift down). The counter increments on
  // every press and every release, so only a counter change is a new event.
  // States: 0x01 pressed, 0x04 pressed (long press), anything else released.
  static const _stateOffset = 6;
  static const _counterOffset = 8;
  static const _pressedStates = {0x01, 0x04};

  final List<int?> _lastCounters = [null, null];
  final List<bool> _held = [false, false];

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    if (characteristic.toLowerCase() == CycplusBc2Constants.TX_CHARACTERISTIC_UUID.toLowerCase()) {
      if (bytes.length > _counterOffset + 1) {
        var changed = false;
        for (var lever = 0; lever < 2; lever++) {
          final counter = bytes[_counterOffset + lever];
          if (counter == _lastCounters[lever]) {
            continue;
          }
          _lastCounters[lever] = counter;
          final held = _pressedStates.contains(bytes[_stateOffset + lever]);
          if (held != _held[lever]) {
            _held[lever] = held;
            changed = true;
          }
        }

        if (changed) {
          await handleButtonsClicked([
            for (var lever = 0; lever < 2; lever++)
              if (_held[lever]) availableButtons[lever],
          ]);
        }
      } else {
        actionStreamInternal.add(
          LogNotification(
            'CYCPLUS BC2 received unexpected packet: ${bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join()}',
          ),
        );
        _held.fillRange(0, _held.length, false);
        await handleButtonsClicked([]);
      }
    }
  }
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
    color: Colors.black,
    icon: LucideIcons.plus,
  );

  static const ControllerButton shiftDown = ControllerButton(
    'shiftDown',
    action: InGameAction.shiftDown,
    color: Colors.black,
    icon: LucideIcons.minus,
  );

  static const List<ControllerButton> values = [
    shiftUp,
    shiftDown,
  ];
}
