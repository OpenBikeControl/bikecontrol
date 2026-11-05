import 'dart:typed_data';

import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/controller/controller_layout.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons;
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth_device.dart';
import 'onelap_key_packet.dart';

class OnelapKey extends BluetoothDevice {
  OnelapKey(super.scanResult)
    : super(
        availableButtons: OnelapKeyButtons.values,
        allowMultiple: true,
        isBeta: true,
      );

  bool _longPressActive = false;

  @override
  ControllerLayout get controllerLayout => ControllerLayout(
    aspectRatio: 1,
    shape: ContourShape.pill,
    positions: {
      OnelapKeyButtons.center: const Offset(0.5, 0.5),
      OnelapKeyButtons.left: const Offset(0.2, 0.5),
      OnelapKeyButtons.up: const Offset(0.5, 0.2),
      OnelapKeyButtons.right: const Offset(0.8, 0.5),
      OnelapKeyButtons.down: const Offset(0.5, 0.8),
    },
  );

  @override
  Future<void> handleServices(List<BleService> services) async {
    final service = services.firstWhere(
      (service) => service.uuid.toLowerCase() == OnelapKeyConstants.serviceUuid,
      orElse: () => throw Exception(
        'Service not found: ${OnelapKeyConstants.serviceUuid}',
      ),
    );
    final characteristic = service.characteristics.firstWhere(
      (characteristic) => characteristic.uuid.toLowerCase() == OnelapKeyConstants.characteristicUuid,
      orElse: () => throw Exception(
        'Characteristic not found: ${OnelapKeyConstants.characteristicUuid}',
      ),
    );
    await _releaseLongPress();
    await UniversalBle.subscribeNotifications(
      device.deviceId,
      service.uuid,
      characteristic.uuid,
    );
  }

  List<ControllerButton> _buttonsForMask(int mask) => [
    for (var index = 0; index < availableButtons.length; index++)
      if ((mask & (1 << index)) != 0) availableButtons[index],
  ];

  Future<void> _releaseLongPress() async {
    if (!_longPressActive) {
      return;
    }
    _longPressActive = false;
    await handleButtonsClicked([]);
  }

  @override
  Future<void> processCharacteristic(
    String characteristic,
    Uint8List bytes,
  ) async {
    if (characteristic.toLowerCase() != OnelapKeyConstants.characteristicUuid) {
      return;
    }
    final packet = OnelapKeyPacket.parse(bytes);
    if (packet == null) {
      await _releaseLongPress();
      return;
    }

    // Frames encode gestures; identical consecutive clicks must not be deduplicated.
    await _releaseLongPress();
    if (packet.clickedButtons != 0) {
      await handleButtonsClicked(_buttonsForMask(packet.clickedButtons));
      await handleButtonsClicked([]);
    }
    if (packet.longPressedButtons != 0) {
      _longPressActive = true;
      await handleButtonsClicked(
        _buttonsForMask(packet.longPressedButtons),
        longPress: true,
      );
    }
  }

  @override
  Future<void> disconnect() async {
    await _releaseLongPress();
    await super.disconnect();
  }
}

class OnelapKeyConstants {
  static const serviceUuid = '8ce5cc01-0a4d-11e9-ab14-d663bd873d93';
  static const characteristicUuid = '8ce5cc02-0a4d-11e9-ab14-d663bd873d93';

  static bool matchesName(String? name) {
    final normalized = name?.trim().toLowerCase();
    return normalized == 'onelap key' || (normalized?.startsWith('onelap key_') ?? false);
  }
}

class OnelapKeyButtons {
  static const center = ControllerButton(
    'onelapCenter',
    identifier: 1,
    action: InGameAction.select,
    color: Colors.black,
    icon: LucideIcons.circle,
  );
  static const left = ControllerButton(
    'onelapLeft',
    identifier: 2,
    action: InGameAction.navigateLeft,
    color: Colors.black,
    icon: LucideIcons.chevronLeft,
  );
  static const up = ControllerButton(
    'onelapUp',
    identifier: 3,
    action: InGameAction.shiftUp,
    color: Colors.black,
    icon: LucideIcons.plus,
  );
  static const right = ControllerButton(
    'onelapRight',
    identifier: 4,
    action: InGameAction.navigateRight,
    color: Colors.black,
    icon: LucideIcons.chevronRight,
  );
  static const down = ControllerButton(
    'onelapDown',
    identifier: 5,
    action: InGameAction.shiftDown,
    color: Colors.black,
    icon: LucideIcons.minus,
  );

  static const values = [center, left, up, right, down];
}
