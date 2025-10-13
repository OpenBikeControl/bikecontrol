import 'dart:typed_data';

import 'package:dartx/dartx.dart';
import 'package:swift_control/bluetooth/ble.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../messages/notification.dart';

class EliteSquare extends BaseDevice {
  EliteSquare(super.scanResult)
    : super(
        availableButtons: SquareConstants.BUTTON_MAPPING.values.toList(),
        isBeta: true,
      );

  String? _lastValue;

  @override
  Future<void> handleServices(List<BleService> services) async {
    final service = services.firstOrNullWhere((e) => e.uuid == SquareConstants.SERVICE_UUID);
    if (service == null) {
      throw Exception('Service not found: ${SquareConstants.SERVICE_UUID}');
    }
    final characteristic = service.characteristics.firstOrNullWhere(
      (e) => e.uuid == SquareConstants.CHARACTERISTIC_UUID,
    );
    if (characteristic == null) {
      throw Exception('Characteristic not found: ${SquareConstants.CHARACTERISTIC_UUID}');
    }

    await UniversalBle.subscribeNotifications(device.deviceId, service.uuid, characteristic.uuid);
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    if (characteristic == SquareConstants.CHARACTERISTIC_UUID) {
      final fullValue = _bytesToHex(bytes);
      final currentValue = _extractButtonCode(fullValue);

      if (_lastValue != null) {
        final currentRelevantPart = fullValue.length >= 19
            ? fullValue.substring(6, fullValue.length - 13)
            : fullValue.substring(6);
        final lastRelevantPart = _lastValue!.length >= 19
            ? _lastValue!.substring(6, _lastValue!.length - 13)
            : _lastValue!.substring(6);

        if (currentRelevantPart != lastRelevantPart) {
          final buttonClicked = SquareConstants.BUTTON_MAPPING[currentValue];
          if (buttonClicked != null) {
            actionStreamInternal.add(LogNotification('Button pressed: $buttonClicked'));
          }
          handleButtonsClicked([
            if (buttonClicked != null) buttonClicked,
          ]);
        }
      }

      _lastValue = fullValue;
    }
  }

  String _extractButtonCode(String hexValue) {
    if (hexValue.length >= 14) {
      final buttonCode = hexValue.substring(6, 14);
      if (SquareConstants.BUTTON_MAPPING.containsKey(buttonCode)) {
        return buttonCode;
      }
    }
    return hexValue;
  }

  String _bytesToHex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
