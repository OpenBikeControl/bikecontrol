import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

abstract class BleDefinition {
  //Transporter? transporter;

  List<String> get serviceUUIDs;

  List<String> get advertiseServiceUUIDs;

  List<BleCharacteristic> getCharacteristics(String serviceUUID);

  void onWriteRequest(String characteristicUUID, List<int> characteristicData);

  Future<Uint8List>? onReadRequest(String characteristicUUID) => null;

  void onNotification(String characteristic, Uint8List bytes);

  void onEnableNotificationRequest(String characteristicUUID) {}

  void sendCharacteristicNotification(
    String characteristicUUID,
    List<int> data, {
    int responseCode = 1,
  }) {}

  void dispose() {}

  void debug() {}
}
