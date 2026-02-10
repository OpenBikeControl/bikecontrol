import 'package:bike_control/bluetooth/devices/openbikecontrol/openbikecontrol_device.dart';
import 'package:prop/emulators/dircon/dircon.dart';
import 'package:universal_ble/universal_ble.dart';

abstract class OnMessage {
  void onMessage(List<int> message);
}

class ObcDircon extends DirCon {
  final OnMessage onMessageCallback;
  ObcDircon({required super.socket, required this.onMessageCallback});

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
          [CharacteristicProperty.writeWithoutResponse, CharacteristicProperty.write],
        ),
      ];
    }
    return [];
  }

  @override
  void processWriteCallback(String characteristicUUID, List<int> characteristicData) {
    if (characteristicUUID.toLowerCase() == OpenBikeControlConstants.APPINFO_CHARACTERISTIC_UUID) {
      onMessageCallback.onMessage(characteristicData);
    }
  }

  @override
  List<String> get serviceUUIDs => [OpenBikeControlConstants.SERVICE_UUID];
}
