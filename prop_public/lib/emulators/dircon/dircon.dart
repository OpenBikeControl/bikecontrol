import 'dart:io';

import 'package:universal_ble/universal_ble.dart';

class DirCon {
  final Socket socket;

  DirCon({required this.socket});

  List<String> get serviceUUIDs => [];

  List<BleCharacteristic> getCharacteristics(String serviceUUID) => [];

  void processWriteCallback(String characteristicUUID, List<int> characteristicData) {}

  void handleIncomingData(List<int> data) {}

  void sendCharacteristicNotification(String uuid, List<int> responseData) {}
}
