import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/openbikecontrol/openbikecontrol_device.dart';
import 'package:prop/emulators/ble_definition.dart';
import 'package:universal_ble/universal_ble.dart';

abstract class OnMessage {
  void onMessage(List<int> message);
}

class ObcBikeDefinition extends BleDefinition {
  final OnMessage onMessageCallback;
  ObcBikeDefinition({required this.onMessageCallback});

  @override
  List<BleCharacteristic> getCharacteristics(String serviceUUID) {
    if (serviceUUID.toLowerCase() == OpenBikeControlConstants.SERVICE_UUID) {
      return [
        BleCharacteristic(
          OpenBikeControlConstants.BUTTON_STATE_CHARACTERISTIC_UUID,
          [CharacteristicProperty.notify],
        ),
        BleCharacteristic(
          OpenBikeControlConstants.APPINFO_CHARACTERISTIC_UUID,
          [CharacteristicProperty.writeWithoutResponse],
        ),
      ];
    }
    return [];
  }

  @override
  void onWriteRequest(String characteristicUUID, List<int> characteristicData) {
    if (characteristicUUID.toLowerCase() == OpenBikeControlConstants.APPINFO_CHARACTERISTIC_UUID) {
      onMessageCallback.onMessage(characteristicData);
    }
  }

  @override
  List<String> get serviceUUIDs => [OpenBikeControlConstants.SERVICE_UUID];

  @override
  List<String> get advertiseServiceUUIDs => serviceUUIDs;

  @override
  void onNotification(String characteristic, Uint8List bytes) {
    onMessageCallback.onMessage(bytes);
  }
}
